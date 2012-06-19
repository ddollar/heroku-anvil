require "anvil/heroku/helpers/anvil"
require "anvil/heroku/manifest"
require "distributor/client"
require "listen"
require "pathname"

# run your local code on heroku
#
class Heroku::Command::Start < Heroku::Command::Base

  include Heroku::Helpers::Anvil

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
    dir = Pathname.new(File.expand_path(shift_argument || ".")).realpath
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
      run_attached app, "bin/develop #{manifest_url}", develop_options
    end
    @status=nil

    heroku.route_attach(app, route["url"], process["process"])

    client_to_dyno = pipe
    dyno_to_client = pipe

    FileUtils.mkdir_p "#{dir}/log"
    @@development_log = File.open("#{dir}/log/heroku-development.log", "a+")
    @@development_log.sync = true

    client = Distributor::Client.new(dyno_to_client.first, client_to_dyno.last)

    client.on_hello do
      client.run("cd /app/work; foreman start -c") do |ch|
        client.hookup ch, $stdin.dup, $stdout.dup
        client.on_close(ch) { shutdown(app, process["process"]) }
      end

      start_file_watcher   client, dir
      start_console_server client, dir
    end

    client.on_command do |command, data|
      case command
      when /file.*/
        #@@development_log.puts "Sync complete: #{data["name"]}"
      end
    end

    Thread.abort_on_exception = true

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

  # start:console
  #
  # get a console into your development dyno
  #
  def console
    connector = Distributor::Connector.new
    console   = TCPSocket.new("localhost", read_anvil_metadata(".", "console.port").to_i)

    set_buffer false

    connector.handle(console) do |io|
      $stdout.write io.readpartial(4096)
      $stdout.flush
    end

    connector.handle($stdin.dup) do |io|
      console.write io.readpartial(4096)
      console.flush
    end

    connector.on_close(console) do
      exit 0
    end

    connector.on_close($stdin.dup) do |io|
      exit 0
    end

    loop { connector.listen }
  rescue Errno::ECONNREFUSED
    error "Unable to connect to development dyno"
  ensure
    set_buffer true
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
    return "https://buildkit.herokuapp.com/buildkit/default.tgz" unless buildpack_url
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
    # api.post_ps_stop app, :ps => process
    exit 0
  end

  def upload_file(dir, file, client)
    return if ignore_file?(File.join(dir, file))
    manifest = Heroku::Manifest.new
    full_filename = File.join(dir, file)
    manifest.add full_filename
    #@@development_log.puts "File changed: #{file}"
    manifest.upload
    hash = manifest.manifest[full_filename]["hash"]
    client.command "file.download", "name" => file, "hash" => hash
  end

  def remove_file(dir, file, client)
    return if ignore_file?(File.join(dir, file))
    #@@development_log.puts "File removed: #{file}"
    client.command "file.delete", "name" => file
  end

  def ignore_file?(file)
    return true if File.stat(file).pipe?
    return true if file[-4..-1] == ".swp"
    return true if file[0..5] == ".anvil"
    false
  end

  def start_file_watcher(client, dir)
    Thread.new do
      listener = Listen.to(dir)
      listener.change do |modified, added, removed|
        modified.concat(added).each do |file|
          relative = file[dir.length+1..-1]
          upload_file dir, relative, client
        end
        removed.each do |file|
          relative = file[dir.length+1..-1]
          remove_file dir, relative, client
        end
      end
      listener.latency(0.2)
      listener.polling_fallback_message("")
      listener.force_polling(true)
      listener.start
    end
  end

  def start_console_server(client, dir)
    Thread.new do
      console_server = TCPServer.new(0)
      write_anvil_metadata dir, "console.port", console_server.addr[1]
      loop do
        Thread.start(console_server.accept) do |console_client|
          client.run("cd /app/work; env TERM=xterm HOME=/app/work bash") do |ch|
            client.hookup ch, console_client
            client.on_close(ch) { console_client.close }
          end
        end
      end
    end
  end

end

class Heroku::Client::Rendezvous
  def fixup(data)
    data
  end
end
