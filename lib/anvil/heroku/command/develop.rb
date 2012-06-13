require "distributor/client"

# manage development dynos
#
class Heroku::Command::Develop < Heroku::Command::Base

  PROTOCOL_COMMAND_HEADER = "\000\042\000"
  PROTOCOL_COMMAND_EXIT   = 1

  # develop APP
  #
  # start a development dyno on development app APP
  #
  # -b, --buildpack    # use a custom buildpack
  # -e, --runtime-env  # use the runtime env
  #
  def index
    dir = "."
    app = shift_argument || error("Must specify a development app")
    validate_arguments!

    app_manifest = upload_manifest("application", dir)
    manifest_url = app_manifest.save

    build_options = {
      :buildpack => prepare_buildpack(options[:buildpack]),
      :env       => options[:runtime_env] ? heroku.config_vars(app) : {}
    }

    action("Releasing to #{app}") do
      heroku.release(app, "Deployed base components", :build_url => anvil_slug_url)
    end

    build_env = {
      "ANVIL_HOST"    => "https://anvil.herokuapp.com",
      "BUILDPACK_URL" => prepare_buildpack(options[:buildpack]),
      "NODE_PATH"     => "lib",
      "PATH"          => "/app/work/bin:/app/work/node_modules/.bin:/app/bin:/app/node_modules/.bin:/usr/local/bin:/usr/bin:/bin"
    }

    develop_options = build_env.inject({}) do |ax, (key, val)|
      ax.update("ps_env[#{key}]" => val)
    end

    rendezvous_url = action("Starting development dyno") do
      run_attached(app, <<-EOF, develop_options)
        bin/develop #{manifest_url}
        cd /app/work; bash
      EOF
    end

    rendezvous = action("Connecting to development dyno") do
      set_buffer(false)
      $stdin.sync = $stdout.sync = true
      rendezvous = Heroku::Client::Rendezvous.new(
        :rendezvous_url => rendezvous_url,
        :connect_timeout => 120,
        :activity_timeout => nil,
        :input => $stdin,
        :output => $stdout
      )
    end

    begin
      rendezvous.start
    rescue Timeout::Error
      error "\nTimeout awaiting process"
    rescue Errno::ECONNREFUSED, Errno::ECONNRESET, OpenSSL::SSL::SSLError
      error "\nError connecting to process"
    rescue Interrupt
    ensure
      set_buffer(true)
    end
  end

private

  def anvil_slug_url
    ENV["ANVIL_SLUG_URL"] || "http://anvil-datastore.s3.amazonaws.com/software/production/anvil.img"
  end

  def run_attached(app, command, options={})
    process_data = api.post_ps(app, command, { :attach => true }.merge(options)).body
    process_data["rendezvous_url"]
  end

  def upload_manifest(name, dir)
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

  def prepare_buildpack(buildpack_url)
    return nil unless buildpack_url
    return buildpack_url unless File.exists?(buildpack_url) && File.directory?(buildpack_url)
    manifest = upload_manifest("buildpack", buildpack_url)
    manifest.save
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
      chunk = chunk[0..location-1]
    end
    chunk
  end

end
