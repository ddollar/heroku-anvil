require "distributor"

class Distributor::Packet

  PROTOCOL_VERSION = 1

  def self.create(channel, data)
    packet = "DIST"
    packet += pack(PROTOCOL_VERSION)
    packet += pack(channel)
    packet += pack(data.length)
    packet += data
  end

  def self.parse(io)
    header = io.read(4)
    return if header.nil?
    raise "invalid header" unless header == "DIST"
    version = unpack(io.read(4))
    channel = unpack(io.read(4))
    length  = unpack(io.read(4))
    data    = ""
    data   += io.readpartial([4096,length-data.length].min) while data.length < length

    [ channel, data ]
  end

  def self.pack(num)
    [num.to_s(16).rjust(8,"0")].pack("H8")
  end

  def self.unpack(string)
    string.unpack("N").first
  end

end
