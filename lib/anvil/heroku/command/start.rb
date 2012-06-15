require "distributor/client"

# run your local code on heroku
#
class Heroku::Command::Start < Heroku::Command::Base

  PROTOCOL_COMMAND_HEADER = "\000\042\000"
  PROTOCOL_COMMAND_EXIT   = 1

  # start [DIR]
  #
  # start a development dyno on development app APP
  #
  # -b, --buildpack    # use a custom buildpack
  # -e, --runtime-env  # use the runtime env
  #
  def index
    dir = shift_argument || "."
    app = options[:app] || error("Must specify a development app with -a")
    validate_arguments!

    route = action("Creating endpoint") do
      heroku.routes_create(app) if heroku.routes(app).length.zero?
      route = heroku.routes(app).first
      heroku.route_detach(app, route["url"], route["ps"]) unless route["ps"].empty?
      route
    end

    app_manifest = upload_manifest("application", dir)
    manifest_url = app_manifest.save

    build_options = {
      :buildpack => prepare_buildpack(options[:buildpack]),
      :env       => options[:runtime_env] ? heroku.config_vars(app) : {}
    }

    action("Preparing development dyno on #{app}") do
      heroku.release(app, "Deployed base components", :build_url => anvil_slug_url)
    end

    build_env = {
      "ANVIL_HOST"    => "https://anvil.herokuapp.com",
      "BUILDPACK_URL" => prepare_buildpack(options[:buildpack]),
      "NODE_PATH"     => "lib",
      "PATH"          => "/app/work/bin:/app/work/node_modules/.bin:/app/vendor/bundle/ruby/1.9.1/bin:/app/bin:/app/node_modules/.bin:/usr/local/bin:/usr/bin:/bin"
    }

    develop_options = build_env.inject({}) do |ax, (key, val)|
      ax.update("ps_env[#{key}]" => val)
    end

    process = action("Starting development dyno") do
      status route["url"].gsub("tcp", "http")
      run_attached(app, <<-EOF, develop_options)
        bin/develop #{manifest_url} 2>&1
      EOF
    end
    @status=nil

    heroku.route_attach(app, route["url"], process["process"])

    client_to_dyno = pipe
    dyno_to_client = pipe

    FileUtils.mkdir_p "#{dir}/log"
    development_log = File.open("#{dir}/log/heroku-development.log", "a+")

    client = Distributor::Client.new(dyno_to_client.first, client_to_dyno.last)

    client.on_hello do
      client.run("bash") do |ch|
        client.hookup ch, $stdin.dup, $stdout.dup
        client.on_close(ch) { shutdown(app, process["process"]) }
      end

      client.run("foreman start") do |ch|
        client.hookup ch, nil, development_log
      end
    end

    rendezvous = Heroku::Client::Rendezvous.new(
      :rendezvous_url => process["rendezvous_url"],
      :connect_timeout => 120,
      :activity_timeout => nil,
      :input => client_to_dyno.first,
      :output => dyno_to_client.last
    )

    rendezvous.on_connect do
      Thread.new { client.start }
    end

    Signal.trap("INT") do
      shutdown(app, process["process"])
    end

    begin
      $stdin.sync = $stdout.sync = true
      set_buffer false
      rendezvous.start
    rescue Timeout::Error
      error "\nTimeout awaiting process"
    rescue Errno::ECONNREFUSED, Errno::ECONNRESET, OpenSSL::SSL::SSLError
      error "\nError connecting to process"
    rescue Interrupt
    ensure
      set_buffer true
    end
  end

private

  def anvil_slug_url
    ENV["ANVIL_SLUG_URL"] || "http://anvil-datastore.s3.amazonaws.com/software/production/anvil.img"
  end

  def run_attached(app, command, options={})
    process_data = api.post_ps(app, command, { :attach => true }.merge(options)).body
    process_data
  end

  def upload_manifest(name, dir)
    manifest = Heroku::Manifest.new(dir)

    action("Synchronizing local files") do
      count = manifest.upload
    end

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

  def pipe
    IO.method(:pipe).arity.zero? ? IO.pipe : IO.pipe("BINARY")
  end

  def shutdown(app, process)
    api.post_ps_stop app, :ps => process
    exit 0
  end

end

class Heroku::Client::Rendezvous
  def fixup(data)
    data
  end
end
