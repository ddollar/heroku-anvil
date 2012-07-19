require "anvil/heroku/builder"
require "heroku"
require "heroku/helpers"
require "net/http"
require "net/https"
require "rest_client"

class Heroku::Manifest

  include Heroku::Helpers

  PUSH_THREAD_COUNT = 40

  attr_reader :cache_url
  attr_reader :dir
  attr_reader :manifest

  def initialize(dir=nil, cache_url=nil)
    @dir = dir
    @manifest = @dir ? directory_manifest(@dir) : {}
    @cache_url = cache_url
  end

  def build(options={})
    uri  = URI.parse("#{anvil_host}/manifest/build")
    http = Net::HTTP.new(uri.host, uri.port)

    if uri.scheme == "https"
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    req = Net::HTTP::Post.new uri.request_uri

    env = options[:env] || {}

    req.set_form_data({
      "buildpack" => options[:buildpack],
      "cache"     => @cache_url,
      "env"       => options[:env],
      "manifest"  => self.to_json
    })

    slug_url = nil

    http.request(req) do |res|
      slug_url = res["x-slug-url"]
      @cache_url = res["x-cache-url"]

      begin
        res.read_body do |chunk|
          yield chunk
        end
      rescue EOFError
        puts
        raise BuildError, "terminated unexpectedly"
      end

      code = (res["x-exit-code"] || 512).first.to_i
      raise Heroku::Builder::BuildError, "exited #{code}" unless code.zero?
    end

    slug_url
  end

  def save
    res = anvil["/manifest"].post(:manifest => self.to_json)
    res.headers[:location]
  end

  def upload
    missing = json_decode(anvil["/manifest/diff"].post(:manifest => self.to_json).to_s)
    upload_hashes missing
    missing.length
  end

  def to_json
    json_encode(@manifest)
  end

  def add(filename)
    @manifest[filename] = file_manifest(filename)
  end

private

  def auth
    Heroku::Auth
  end

  def anvil
    @anvil ||= RestClient::Resource.new(anvil_host)
  end

  def anvil_host
    ENV["ANVIL_HOST"] || "https://api.anvilworks.org"
  end

  def directory_manifest(dir)
    root = Pathname.new(dir)

    ignore = process_slugignore(File.join(dir, ".slugignore"))

    Dir.glob(File.join(dir, "**", "*"), File::FNM_DOTMATCH).inject({}) do |hash, file|
      next(hash) if %w( . .. ).include?(File.basename(file))
      next(hash) if ignore.include?(file)
      next(hash) if File.directory?(file)
      next(hash) if File.pipe?(file)
      next(hash) if file =~ /\.git/
      next(hash) if file =~ /\.swp$/
      hash[Pathname.new(file).relative_path_from(root).to_s] = file_manifest(file)
      hash
    end
  end

  def file_manifest(file)
    stat = File.stat(file)
    manifest = {
      "mtime" => stat.mtime.to_i,
      "mode"  => "%o" % stat.mode,
    }
    if File.symlink?(file)
      manifest["link"] = File.readlink(file)
    else
      manifest["hash"] = calculate_hash(file)
    end
    manifest
  end

  def process_slugignore(filename)
    return [] unless File.exists?(filename)
    root = File.dirname(filename)
    File.read(filename).split("\n").map do |entry|
      Dir.glob(File.join(root, entry, "**", "*"), File::FNM_DOTMATCH)
    end.flatten.compact
  end

  def calculate_hash(filename)
    Digest::SHA2.hexdigest(File.open(filename, "rb").read)
  end

  def upload_file(filename, hash=nil)
    hash ||= calculate_hash(filename)
    anvil["/file/#{hash}"].post :data => File.new(filename, "rb")
    hash
  rescue RestClient::Forbidden => ex
    error "error uploading #{filename}: #{ex.http_body}"
  end

  def upload_hashes(hashes)
    filenames_by_hash = @manifest.inject({}) do |ax, (name, file_manifest)|
      ax.update file_manifest["hash"] => File.join(@dir.to_s, name)
    end
    bucket_hashes = hashes.inject({}) do |ax, hash|
      index = hash.hash % PUSH_THREAD_COUNT
      ax[index] ||= []
      ax[index]  << hash
      ax
    end
    threads = bucket_hashes.values.map do |hashes|
      Thread.new do
        hashes.each do |hash|
          upload_file filenames_by_hash[hash], hash
        end
      end
    end
    threads.each(&:join)
  end

end
