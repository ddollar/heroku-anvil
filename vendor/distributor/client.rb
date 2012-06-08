#!/usr/bin/env ruby

$:.unshift File.expand_path("../lib", __FILE__)

require "distributor/client"
require "distributor/server"

if ARGV.first == "server"

  server = Distributor::Server.new($stdin.dup, $stdout.dup)
  $stdout = $stderr
  server.start

else

  api = Heroku::API.new(:api_key => "01a9a253fd3caf89e1115234965682df9c7cf1cc")

  client = Distributor::Client.new(IO.popen("ruby client.rb server", "w+"))

  client.run("bash 2>&1") do |ch|
    client.hookup ch, $stdin, $stdout
  end

  client.start

end
