require "anvil/heroku/manifest"
require "cgi"
require "digest/sha2"
require "heroku/command/base"
require "net/https"
require "pathname"
require "tmpdir"

# deploy code
#
class Heroku::Command::Build < Heroku::Command::Base

  PROTOCOL_COMMAND_HEADER = "\000\042\000"
  PROTOCOL_COMMAND_EXIT   = 1

  # build [DIR]
  #
  # deploy code
  #
  # -b, --buildpack URL  # use a custom buildpack
  # -e, --runtime-env    # use runtime environment during build
  # -p, --pipeline       # pipe compile output to stderr and only put the slug url on stdout
  # -r, --release        # release the slug to an app
  #
  def index
    if options[:pipeline]
      old_stdout = $stdout.dup
      $stdout = $stderr
    end

    dir = shift_argument || "."
    validate_arguments!

    manifest = sync_dir(dir, "app")

    build_options = {
      :buildpack => prepare_buildpack(options[:buildpack]),
      :env       => options[:runtime_env] ? heroku.config_vars(app) : {}
    }

    build_url = manifest.build(build_options) do |chunk|
      print process_commands(chunk)
    end

    File.open("#{dir}/.anvil-cache", "w") { |f| f.puts manifest.cache_url }

    old_stdout.puts build_url if options[:pipeline]

    if options[:release]
      action("Releasing to #{app}") do
        release = heroku.release(app, "Anvil deploy", :build_url => build_url)
        status release["release"]
      end
    end
  end


private

  def auth
    Heroku::Auth
  end

  def releaser
    RestClient::Resource.new("releases-test.herokuapp.com", auth.user, auth.password)
  end

  def process_commands(chunk)
    if location = chunk.index(PROTOCOL_COMMAND_HEADER)
      buffer = StringIO.new(chunk[location..-1])
      header = buffer.read(3)
      case command = buffer.read(1).ord
      when PROTOCOL_COMMAND_EXIT then
        code = buffer.read(1).ord
        unless code.zero?
          puts "ERROR: Build exited with code: #{code}"
          exit code
        end
      else
        puts "unknown[#{command}]"
      end
      chunk = chunk[0,location] + buffer.read
    end
    chunk
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
    manifest.save
  end

  def sync_dir(dir, name)
    manifest = action("Generating #{name} manifest") do
      cache = File.read("#{dir}/.anvil-cache").chomp rescue nil
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
