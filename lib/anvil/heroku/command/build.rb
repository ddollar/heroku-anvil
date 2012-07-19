require "anvil/heroku/helpers/anvil"
require "anvil/heroku/builder"
require "anvil/heroku/manifest"
require "cgi"
require "digest/sha2"
require "heroku/command/base"
require "net/https"
require "pathname"
require "tmpdir"
require "uri"

# deploy code
#
class Heroku::Command::Build < Heroku::Command::Base

  include Heroku::Helpers::Anvil

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
  # -e, --runtime-env    # use an app's runtime environment during build
  # -p, --pipeline       # pipe compile output to stderr and only put the slug url on stdout
  # -r, --release        # release the slug to an app
  #
  def index
    if options[:pipeline]
      old_stdout = $stdout.dup
      $stdout = $stderr
    end

    source = shift_argument || "."
    validate_arguments!

    build_options = {
      :buildpack => prepare_buildpack(options[:buildpack]),
      :env       => options[:runtime_env] ? heroku.config_vars(app) : {}
    }

    if URI.parse(source).scheme
      slug_url = Heroku::Builder.new.build(source, build_options) do |chunk|
        print chunk
      end
    else
      dir      = File.expand_path(source)
      manifest = sync_dir(dir, "app")

      slug_url = manifest.build(build_options) do |chunk|
        print chunk
      end

      write_anvil_metadata dir, "cache", manifest.cache_url
    end

    old_stdout.puts slug_url if options[:pipeline]

    if options[:release]
      action("Releasing to #{app}") do
        begin
          release = heroku.release(app, "Anvil deploy", :build_url => slug_url, :cloud => heroku.host)
          status release["release"]
        rescue RestClient::Forbidden => ex
          error ex.http_body
        end
      end
    end
  rescue Heroku::Builder::BuildError => ex
    puts "ERROR: Build failed, #{ex.message}"
    exit 1
  end

private

  def auth
    Heroku::Auth
  end

  def releaser
    RestClient::Resource.new("releases-test.herokuapp.com", auth.user, auth.password)
  end

  def parse_procfile(filename)
    return {} unless File.exists?(filename)
    File.read(filename).split("\n").inject({}) do |ax, line|
      if line =~ /^([A-Za-z0-9_]+):\s*(.+)$/
        ax[$1] = $2
      end
      ax
    end
  end

  def prepare_buildpack(buildpack_url)
    return nil unless buildpack_url

    if URI.parse(buildpack_url).scheme
      return buildpack_url
    elsif buildpack_url =~ /\A\w+\Z/
      return "http://buildkits-dev.s3.amazonaws.com/buildpacks/#{buildpack_url}.tgz"
    elsif File.exists?(buildpack_url) && File.directory?(buildpack_url)
      manifest = sync_dir(buildpack_url, "buildpack")
      manifest.save
    else
      error "unknown buildpack type: #{buildpack_url}"
    end
  end

  def sync_dir(dir, name)
    manifest = action("Generating #{name} manifest") do
      cache = read_anvil_metadata(dir, "cache")
      Heroku::Manifest.new(dir, cache)
    end

    action("Uploading new files") do
      count = manifest.upload
      @status = "#{count} files needed"
    end
    @status = nil

    manifest
  end

end
