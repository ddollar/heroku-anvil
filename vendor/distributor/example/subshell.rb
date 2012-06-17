#!/usr/bin/env ruby

$:.unshift File.expand_path("../../lib", __FILE__)

require "distributor/client"
require "distributor/server"

def set_buffer(enable)
  return unless $stdin.isatty
  enable ? `stty icanon echo` : `stty -icanon -echo`
end

if ARGV.first == "server"

  begin
    server = Distributor::Server.new($stdin.dup, $stdout.dup)
    $stdout = $stderr

    server.on_command do |command, data|
      server.command command, data.merge("ack" => Time.now.to_i)
    end

    server.start
  rescue Interrupt
  end

else

  begin
    client = Distributor::Client.new(IO.popen("ruby subshell.rb server", "w+"))

    client.run("ls -la") do |ch|
      client.hookup ch, nil, File.open("test.log", "a+")
    end

    client.run("bash 2>&1") do |ch|
      client.hookup ch, $stdin.dup, $stdout.dup
      client.on_close(ch) do
        exit 0
      end
    end

    client.on_command do |command, data|
      p [:received, command, data]
    end

    client.command "foo", "bar" => "baz"

    tcp = TCPServer.new(8000)

    Thread.new do
      loop do
        Thread.start(tcp.accept) do |tcp_client|
          client.tunnel(nil) do |ch|
            client.hookup ch, tcp_client
          end
        end
      end
    end

    set_buffer false
    client.start
  ensure
    set_buffer true
  end

end
