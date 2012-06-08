require "distributor/client"

# manage development dynos
#
class Heroku::Command::Develop < Heroku::Command::Base

  PROTOCOL_COMMAND_HEADER = "\000\042\000"
  PROTOCOL_COMMAND_EXIT   = 1

  # develop [DIR]
  #
  # start a development dyno
  #
  # -b, --buildpack    # use a custom buildpack
  # -e, --runtime-env  # use the runtime env
  #
  def index
    dir = shift_argument || "."
    validate_arguments!

    app_manifest  = upload_manifest("application", dir)
    dist_manifest = upload_manifest("distributor", distributor_path)
    p [:dm, dist_manifest]

    build_options = {
      :buildpack => prepare_buildpack(options[:buildpack]),
      :env       => options[:runtime_env] ? heroku.config_vars(app) : {}
    }

    build_url = app_manifest.build(build_options) do |chunk|
      print process_commands(chunk)
    end

    development_app = action("Creating development app") do
      name = "heroku-develop-#{rand(1000000000).to_s(16)}"
      info = api.post_app({ "name" => name, "stack" => "cedar" }).body
      status name
      name
    end

    action("Releasing to #{development_app}") do
      heroku.release(development_app, "Deployed initial state", :build_url => build_url)
    end

    rendezvous_url = action("Starting development dyno") do
      run_attached(development_app, "bash")
    end

    rendezvous = action("Connecting to development dyno") do
      begin
        set_buffer(false)
        $stdin.sync = $stdout.sync = true
        Heroku::Client::Rendezvous.new(
          :rendezvous_url => rendezvous_url,
          :connect_timeout => 120,
          :activity_timeout => nil,
          :input => $stdin,
          :output => $stdout
        )
      rescue Timeout::Error
        error "\nTimeout awaiting process"
      rescue Errno::ECONNREFUSED, Errno::ECONNRESET, OpenSSL::SSL::SSLError
        error "\nError connecting to process"
      rescue Interrupt
      ensure
        set_buffer(true)
      end
    end

    rendezvous.start

    action("Deleting development app") do
      api.delete_app(development_app)
    end

    Heroku::Command.warnings.replace([])
  end

private

  def run_attached(app, command)
    process_data = api.post_ps(app, command, { :attach => true }).body
    process_data["rendezvous_url"]
  end

  def distributor_path
    File.expand_path("../../../../../vendor/distributor", __FILE__)
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
