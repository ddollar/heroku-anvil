require "distributor"
require "distributor/connector"
require "distributor/multiplexer"
require "distributor/okjson"
require "thread"

class Distributor::Client

  def initialize(input, output=input)
    @connector   = Distributor::Connector.new
    @multiplexer = Distributor::Multiplexer.new(output)
    @handlers    = {}
    @processes   = []
    @on_close    = Hash.new { |hash,key| hash[key] = Array.new }
    @on_hello    = []
    @on_command  = Proc.new {}
    @hookup_lock = Mutex.new

    # reserve a command channel
    @multiplexer.reserve(0)

    # feed data from the input channel into the multiplexer
    @connector.handle(input) do |io|
      @multiplexer.input io
    end

    @connector.on_close(input) do |io|
      exit 0
    end

    # handle the command channel of the multiplexer
    @connector.handle(@multiplexer.reader(0)) do |io|
      append_json(io.readpartial(4096))

      dequeue_json do |data|
        case command = data["command"]
        when "hello" then
          @on_hello.each { |c| c.call }
        when "close" then
          ch = data["ch"]
          @on_close[ch].each { |c| c.call(ch) }
        when "ack" then
          ch = data["ch"]
          @multiplexer.reserve ch
          @handlers[data["id"]].call(ch)
          @handlers.delete(data["id"])
          @processes << ch
        else
          @on_command.call(command, data)
        end
      end
    end
  end

  def output(ch, data)
    @multiplexer.output ch, data
  end

  def command(command, data={})
    data["id"] ||= @multiplexer.generate_id
    data["command"] = command
    @multiplexer.output 0, Distributor::OkJson.encode(data)
    data["id"]
  end

  def run(command, &handler)
    id = command("run", "args" => command)
    @handlers[id] = handler
  end

  def tunnel(port, &handler)
    id = command("tunnel", "port" => port)
    @handlers[id] = handler
  end

  def hookup(ch, input, output=input)
    @hookup_lock.synchronize do
      # handle data incoming on the multiplexer
      @connector.handle(@multiplexer.reader(ch)) do |io|
        begin
          data = io.readpartial(4096)
          # output.write "#{ch}: #{data}"
          output.write data
          output.flush
        rescue EOFError
          command "close", "ch" => ch
        end
      end
    end

    # handle data incoming from the input channel
    @connector.handle(input) do |io|
      begin
        data = io.readpartial(4096)
        @multiplexer.output ch, data
      rescue EOFError
        @on_close[ch].each { |c| p c; c.call(ch) }
        @connector.close(io)
      end
    end
  end

  def on_close(ch, &blk)
    @on_close[ch] << blk
  end

  def on_hello(&blk)
    @on_hello << blk
  end

  def on_command(&blk)
    @on_command = blk
  end

  def start
    loop { @connector.listen }
  end

private

  def append_json(data)
    @json ||= ""
    @json += data
  end

  def dequeue_json
    while idx = @json.index("}")
      yield Distributor::OkJson.decode(@json[0..idx])
      @json = @json[idx+1..-1]
    end
  end

end
