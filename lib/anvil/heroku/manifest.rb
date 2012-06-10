require "heroku"
require "net/http"
require "net/https"
require "json"

class Heroku::Manifest

  PUSH_THREAD_COUNT = 40

  attr_reader :dir

  def initialize(dir)
    @dir = dir
    @manifest = directory_manifest(@dir)
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
      "env"       => options[:env],
      "manifest"  => self.to_json,
      "buildpack" => options[:buildpack]
    })

    slug_url = nil

    http.request(req) do |res|
      slug_url = res["x-slug-url"]
      res.read_body do |chunk|
        yield chunk
      end
    end

    slug_url
  end

  def save
    id = JSON.load(anvil["/manifest"].post(:manifest => self.to_json).to_s)["id"]
    "#{anvil_host}/manifest/#{id}.json"
  end

  def upload
    missing = JSON.load(anvil["/manifest/diff"].post(:manifest => self.to_json).to_s)
    upload_hashes missing
    missing.length
  end

  def to_json
    JSON.dump(@manifest)
  end

private

  def auth
    Heroku::Auth
  end

  def anvil
    @anvil ||= RestClient::Resource.new(anvil_host, auth.user, auth.password)
  end

  def anvil_host
    ENV["ANVIL_HOST"] || "http://anvil.herokuapp.com"
  end

  def directory_manifest(dir)
    root = Pathname.new(dir)

    Dir[File.join(dir, "**", "*")].inject({}) do |hash, file|
      next(hash) if File.directory?(file)
      next(hash) if file =~ /\.git/
      hash[Pathname.new(file).relative_path_from(root).to_s] = file_manifest(file)
      hash
    end
  end

  def file_manifest(file)
    stat = File.stat(file)
    {
      "ctime" => stat.ctime.to_i,
      "mtime" => stat.mtime.to_i,
      "mode"  => "%o" % stat.mode,
      "hash"  => Digest::SHA2.hexdigest(File.open(file, "rb").read)
    }
  end

  def upload_file(hash, filename)
    anvil["/file/#{hash}"].post :data => File.new(filename, "rb")
  end

  def upload_hashes(hashes)
    filenames_by_hash = @manifest.inject({}) do |ax, (name, file_manifest)|
      ax.update file_manifest["hash"] => File.join(@dir, name)
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
          upload_file hash, filenames_by_hash[hash]
        end
      end
    end
    threads.each(&:join)
  end

end
