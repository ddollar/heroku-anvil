require "distributor"
require "distributor/packet"

class Distributor::Multiplexer

  def initialize(output)
    @output  = output
    @readers = {}
    @writers = {}

    @output.sync = true
  end

  def reserve(ch=nil)
    ch ||= @readers.keys.length
    raise "channel already taken: #{ch}" if @readers.has_key?(ch)
    @readers[ch], @writers[ch] = IO.pipe
    ch
  end

  def reader(ch)
    @readers[ch] || raise("no such channel: #{ch}")
  end

  def writer(ch)
    @writers[ch] || raise("no such channel: #{ch}")
  end

  def input(io)
    ch, data = Distributor::Packet.parse(io)
    return if ch.nil?
    writer(ch).write data
  rescue IOError
    output 0, JSON.dump({ "command" => "close", "ch" => ch })
  end

  def output(ch, data)
    Distributor::Packet.write(@output, ch, data)
  rescue Errno::EPIPE
  end

  def close(ch)
    output 0, JSON.dump({ "command" => "close", "ch" => ch })
  rescue IOError
  end

end
