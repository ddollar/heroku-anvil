require "heroku"
require "json"

class Heroku::Manifest

  attr_reader :dir

  def initialize(dir)
    @dir = dir
    @manifest = directory_manifest(@dir)
    @filenames_by_hash = @manifest.inject({}) do |ax, (name, file_manifest)|
      ax.update file_manifest["hash"] => File.join(@dir, name)
    end
  end

  def filename_for_hash(hash)
    @filenames_by_hash[hash]
  end

  def to_json
    JSON.dump(@manifest)
  end

private

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


end
