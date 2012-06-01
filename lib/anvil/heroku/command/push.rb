require "anvil/heroku/manifest"
require "cgi"
require "digest/sha2"
require "heroku/command/base"
require "net/https"
require "pathname"
require "tmpdir"

# deploy code
#
class Heroku::Command::Push < Heroku::Command::Base

  # push [DIR]
  #
  # deploy code
  #
  # -b, --buildpack URL  # use a custom buildpack
  # -e, --runtime-env    # use runtime environment during build
  # -r, --release        # release the slug to an app
  #
  def index
    dir = shift_argument || "."
    validate_arguments!

    manifest = sync_dir(dir, "app")

    build_options = {
      :buildpack => prepare_buildpack(options[:buildpack]),
      :env       => options[:runtime_env] ? heroku.config_vars(app) : {}
    }

    slug_url = manifest.build(build_options) do |chunk|
      print chunk
    end

    if options[:release]
      Dir.mktmpdir do |dir|
        action("Downloading slug") do
          File.open("#{dir}/slug.img", "wb") do |file|
            file.print RestClient.get(slug_url).body
          end
        end
        release = heroku.releases_new(app)
        action("Releasing to #{app}") do
          release = heroku.release(app, "#{dir}/slug.img", "Anvil deploy", {
            "process_types" => parse_procfile("./Procfile")
          })
          @status = release["release"]
        end
      end
    end
  end


private

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
    return buildpack_url unless File.exists?(buildpack_url) && File.directory?(buildpack_url)

    manifest = sync_dir(buildpack_url, "buildpack")
    manifest.save
  end

  def sync_dir(dir, name)
    manifest = action("Generating #{name} manifest") do
      Heroku::Manifest.new(dir)
    end

    action("Uploading new files") do
      count = manifest.upload
      @status = "#{count} files needed"
    end
    @status = nil

    manifest
  end

end
