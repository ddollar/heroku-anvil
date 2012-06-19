require "distributor"
require "stringio"
require "thread"

class Distributor::Packet

  PROTOCOL_VERSION = 1

  def self.write(io, channel, data)
    @@output ||= Mutex.new
    @@output.synchronize do
      buffer = StringIO.new
      buffer.write "DIST"
      buffer.write pack(PROTOCOL_VERSION)
      buffer.write pack(channel)
      buffer.write pack(data.length)
      buffer.write data
      io.write buffer.string
    end
  end

  def self.parse(io)
    @@input ||= Mutex.new
    @@input.synchronize do
      header = io.read(4)
      return if header.nil?
      raise "invalid header" unless header == "DIST"
      version = unpack(io.read(4))
      channel = unpack(io.read(4))
      length  = unpack(io.read(4))
      data    = io.read(length)
      return [ channel, data ]
    end
  end

  def self.pack(num)
    [num].pack("N")
  end

  def self.unpack(string)
    string.unpack("N").first
  end

end
