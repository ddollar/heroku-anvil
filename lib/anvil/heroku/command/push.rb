require "cgi"
require "digest/sha2"
require "heroku/command/base"
require "net/https"
require "pathname"

# deploy code
#
class Heroku::Command::Push < Heroku::Command::Base

  PUSH_THREAD_COUNT = 40

  # push
  #
  # deploy code
  #
  #
  def index
    manifest = action("Generating application manifest") do
      directory_manifest(".")
    end
    missing_hashes = action("Computing diff for upload") do
      json_decode(anvil["/manifest/diff"].post(:manifest => json_encode(manifest)).to_s)
    end
    action("Uploading new files") do
      upload_missing_files(manifest, missing_hashes)
    end

    puts "Compiling..."
    uri = URI.parse("#{anvil_host}/manifest/build")

    http = Net::HTTP.new(uri.host, uri.port)

    if uri.scheme == "https"
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    req = Net::HTTP::Post.new uri.request_uri
    req.set_form_data "manifest" => json_encode(manifest)

    http.request(req) do |res|
      res.read_body do |chunk|
        print chunk
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

  def directory_manifest(dir)
    root = Pathname.new(dir)

    Dir[File.join(dir, "**", "*")].inject({}) do |hash, file|
      hash[Pathname.new(file).relative_path_from(root).to_s] = file_manifest(file) unless File.directory?(file)
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

  def manifest_names_by_hash(manifest)
    manifest.inject({}) do |ax, (name, file_manifest)|
      ax.update file_manifest["hash"] => name
    end
  end

  def streamer
    lambda do |chunk, remaining, total|
      p [:chunk, chunk]
      p [:rem, remaining]
      p [:tot, total]
    end
  end

  def upload_file(hash, name)
    anvil["/file/#{hash}"].post :data => File.new(name, "rb")
  end

  def upload_missing_files(manifest, missing_hashes)
    names_by_hash = manifest_names_by_hash(manifest)
    bucket_missing_hashes = missing_hashes.inject({}) do |ax, hash|
      index = hash.hash % PUSH_THREAD_COUNT
      ax[index] ||= []
      ax[index]  << hash
      ax
    end
    threads = bucket_missing_hashes.values.map do |hashes|
      Thread.new do
        hashes.each do |hash|
          upload_file hash, names_by_hash[hash]
        end
      end
    end
    threads.each(&:join)
  end

end
