#!/usr/bin/env ruby

require "logger"

input  = $stdin
output = $stdout
debug  = $stderr

log = Logger.new("test.log")

PROTOCOL_STATE_HEADER  = 1
PROTOCOL_STATE_VERSION = 2
PROTOCOL_STATE_CHANNEL = 3
PROTOCOL_STATE_DATA    = 4

state = PROTOCOL_STATE_HEADER

loop do
  debug.puts "loop state=#{state}"
  case state
  when PROTOCOL_STATE_HEADER
    header = input.read(4)
    debug.puts "loop state=header header=#{header}"
    state = PROTOCOL_STATE_VERSION if header == "DIST"
  when PROTOCOL_STATE_VERSION
    version = input.read(4).unpack("N").first
    debug.puts "loop state=version version=#{version}"
    state = PROTOCOL_STATE_CHANNEL
  when PROTOCOL_STATE_CHANNEL
    channel = input.read(4).unpack("N").first
    debug.puts "loop state=channel channel=#{channel}"
    state = PROTOCOL_STATE_DATA
    puts "foo"
  when PROTOCOL_STATE_DATA
    length = input.read(4).unpack("N").first
    data   = ""
    puts "neh?"
    while data.length < length
      chunk = input.readpartial(4096)
      data += chunk
      debug.puts "loop state=data current=#{data.length} length=#{length}"
      puts "eh?"
    end
    state = PROTOCOL_STATE_HEADER
    output.puts "do it again"
  end
end
