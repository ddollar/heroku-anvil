require "distributor"
require "distributor/okjson"
require "distributor/packet"
require "thread"

class Distributor::Multiplexer

  def initialize(output)
    @output  = output
    @readers = Hash.new { |hash,key| hash[key] = StringIO.new }
    @writers = Hash.new { |hash,key| hash[key] = StringIO.new }
    @write_lock = Mutex.new

    @output.sync = true
  end

  def reserve(ch=nil)
    ch ||= @readers.keys.length
    raise "channel already taken: #{ch}" if @readers.has_key?(ch)
    @readers[ch], @writers[ch] = IO.pipe
    ch
  end

  def reader(ch)
    @readers[ch]
  end

  def writer(ch)
    @writers[ch]
  end

  def input(io)
    ch, data = Distributor::Packet.parse(io)
    return if ch.nil?
    writer(ch).write data
  rescue IOError
    output 0, Distributor::OkJson.encode({ "command" => "close", "ch" => ch })
  end

  def output(ch, data)
    @write_lock.synchronize do
      Distributor::Packet.write(@output, ch, data)
    end
  rescue Errno::EPIPE
  end

  def close(ch)
    output 0, Distributor::OkJson.encode({ "command" => "close", "ch" => ch })
  rescue IOError
  end

  def generate_id
    id = "#{Time.now.to_f}-#{rand(10000)}"
  end

end
