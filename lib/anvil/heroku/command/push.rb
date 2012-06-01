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

  PUSH_THREAD_COUNT = 40

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

    uri  = URI.parse("#{anvil_host}/manifest/build")
    http = Net::HTTP.new(uri.host, uri.port)

    if uri.scheme == "https"
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    req = Net::HTTP::Post.new uri.request_uri

    env = options[:runtime_env] ? heroku.config_vars(app) : {}

    req.set_form_data({
      "env"       => env,
      "manifest"  => manifest.to_json,
      "buildpack" => prepare_buildpack(options[:buildpack])
    })

    slug_url = nil

    http.request(req) do |res|
      slug_url = res["x-slug-url"]
      res.read_body do |chunk|
        print chunk
      end
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

  def anvil_host
    ENV["ANVIL_HOST"] || "http://anvil.herokuapp.com"
  end

  def anvil
    RestClient::Resource.new(anvil_host, auth.user, auth.password)
  end

  def auth
    Heroku::Auth
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
    return buildpack_url unless File.exists?(buildpack_url) && File.directory?(buildpack_url)

    manifest = sync_dir(buildpack_url, "buildpack")

    new_buildpack_url = action("Saving buildpack manifest") do
      json_decode(anvil["/manifest/create"].post(:manifest => manifest.to_json).to_s)["url"]
    end
  end

  def sync_dir(dir, name)
    manifest = action ("Generating #{name} manifest") do
      Heroku::Manifest.new(dir)
    end

    missing_hashes = action("Computing diff for #{name} upload") do
      missing = json_decode(anvil["/manifest/diff"].post(:manifest => manifest.to_json).to_s)
      @status = "#{missing.length} files needed"
      missing
    end
    @status = nil

    action("Uploading new #{name} files") do
      upload_missing_files(manifest, missing_hashes)
    end

    manifest
  end

  def upload_file(hash, name)
    anvil["/file/#{hash}"].post :data => File.new(name, "rb")
  end

  def upload_missing_files(manifest, missing_hashes)
    bucket_missing_hashes = missing_hashes.inject({}) do |ax, hash|
      index = hash.hash % PUSH_THREAD_COUNT
      ax[index] ||= []
      ax[index]  << hash
      ax
    end
    threads = bucket_missing_hashes.values.map do |hashes|
      Thread.new do
        hashes.each do |hash|
          upload_file hash, manifest.filename_for_hash(hash)
        end
      end
    end
    threads.each(&:join)
  end

end
