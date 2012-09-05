require "anvil/engine"
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

    source = shift_argument || "."
    validate_arguments!

    user = api.post_login("", Heroku::Auth.password).body["email"]

    Anvil.append_agent "interface=build user=#{user} app=#{app}"

    slug_url = Anvil::Engine.build source,
      :buildpack => options[:buildpack],
      :pipeline  => options[:pipeline]

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
