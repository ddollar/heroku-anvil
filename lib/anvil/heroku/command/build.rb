require "anvil/builder"
require "anvil/manifest"
require "cgi"
require "digest/sha2"
require "heroku/command/base"
require "net/https"
require "pathname"
require "progress"
require "tmpdir"
require "uri"

# deploy code
#
class Heroku::Command::Build < Heroku::Command::Base

  # build [SOURCE]
  #
  # build software on an anvil build server
  #
  # if SOURCE is a local directory, the contents of the directory will be built
  # if SOURCE is a git URL, the contents of the repo will be built
  # if SOURCE is a tarball URL, the contents of the tarball will be built
  #
  # SOURCE will default to "."
  #
  # -b, --buildpack URL  # use a custom buildpack
  # -p, --pipeline       # pipe compile output to stderr and only put the slug url on stdout
  # -r, --release [APP]  # release the slug to an app (defaults to current app detected from git)
  #
  def index
    # let app name be specified with -r, and trigger app name warning
    # if no app specified
    @app = options[:release] if options[:release]
    app_to_build = app if options.has_key?(:release)

    if options[:pipeline]
      old_stdout = $stdout.dup
      $stdout = $stderr
    end

    source = shift_argument || "."
    validate_arguments!

    build_options = {
      :buildpack => prepare_buildpack(options[:buildpack].to_s)
    }

    builder = if is_url?(source)
      Anvil::Builder.new(source)
    else
      manifest = Anvil::Manifest.new(File.expand_path(source))
      print "Checking for files to sync... "
      missing = manifest.missing
      puts "done, #{missing.length} files needed"

      if missing.length > 0
        Progress.start("Uploading", missing.map { |hash, file| file["size"].to_i }.inject(&:+))
        manifest.upload(missing.keys) do |file|
          Progress.step file["size"].to_i
        end
        puts "Uploading, done                                    "
      end

      manifest
    end

    slug_url = builder.build(build_options) do |chunk|
      print chunk
    end

    old_stdout.puts slug_url if options[:pipeline]

    if options.has_key?(:release)
      action("Releasing to #{app}") do
        begin
          release = heroku.release(app, "Anvil deploy", :slug_url => slug_url, :cloud => heroku.host)
          status release["release"]
        rescue RestClient::Forbidden => ex
          error ex.http_body
        end
      end
    end
  rescue Anvil::Builder::BuildError => ex
    puts "ERROR: Build failed, #{ex.message}"
    exit 1
  end

private

  def is_url?(string)
    URI.parse(string).scheme rescue nil
  end

  def prepare_buildpack(buildpack)
    if buildpack == ""
      buildpack
    elsif is_url?(buildpack)
      buildpack
    elsif buildpack =~ /\A\w+\/\w+\Z/
      "http://buildkits-dev.s3.amazonaws.com/buildpacks/#{buildpack}.tgz"
    elsif File.exists?(buildpack) && File.directory?(buildpack)
      print "Uploading buildpack... "
      manifest = Anvil::Manifest.new(buildpack)
      manifest.upload
      manifest.save
      puts "done"
    else
      error "unrecognized buildpack specification: #{buildpack}"
    end
  end

end
