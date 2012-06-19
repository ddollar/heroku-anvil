#!/usr/bin/env ruby

$:.unshift File.expand_path("../../lib", __FILE__)

require "distributor/client"
require "distributor/server"

def set_buffer(enable)
  return unless $stdin.isatty
  enable ? `stty icanon echo` : `stty -icanon -echo`
end

### SERVER

if ARGV.first == "server"

  # create a server that uses stdin/stdout for communication
  server = Distributor::Server.new($stdin.dup, $stdout.dup)
  $stdout.reopen $stderr

  # echo commands back with an ack parameter
  server.on_command do |command, data|
    server.command command, data.merge("ack" => Time.now.to_i)
  end

  server.start

### CLIENT

else

  begin

    # create a client that talks to a server created over a subprocess
    client = Distributor::Client.new(IO.popen("ruby local.rb server", "w+"))

    # output the results of ls -la to test.log, with no input channel
    client.run("ls -la") do |ch|
      client.hookup ch, nil, File.open("test.log", "a+")
    end

    # run a subshell and hook it up to stdin/stdout
    client.run("bash 2>&1") do |ch|
      client.hookup ch, $stdin.dup, $stdout.dup
      client.on_close(ch) do
        exit 0
      end
    end

    # echo commands to stdout
    client.on_command do |command, data|
      $stdout.puts "received: #{command} #{data.inspect}"
    end

    # send a command to the server
    client.command "test", "foo" => "bar"

    # create a proxy on localhost:8000 to be the local endpoint for a tunnel
    tcp = TCPServer.new(8000)

    Thread.new do
      loop do

        # every time a connection comes to localhost:8000 on the client
        Thread.start(tcp.accept) do |tcp_client|

          # create a tunnel to localhost:5000 on the server
          client.tunnel(5000) do |ch|
            client.hookup ch, tcp_client
          end

        end
      end
    end

    # turn off terminal specials
    set_buffer false

    client.start

  ensure

    # restore terminal
    set_buffer true

  end

end
