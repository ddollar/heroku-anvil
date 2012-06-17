require "distributor"
require "distributor/connector"
require "distributor/multiplexer"
require "distributor/okjson"
require "pty"
require "socket"

class Distributor::Server

  def initialize(input, output=input)
    @connector   = Distributor::Connector.new
    @multiplexer = Distributor::Multiplexer.new(output)
    @on_command  = Proc.new {}

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
        when "tunnel" then
          port = (data["port"] || ENV["PORT"] || 5000).to_i
          ch = tunnel(port)
          @multiplexer.output 0, Distributor::OkJson.encode({ "id" => data["id"], "command" => "ack", "ch" => ch, "port" => port })
        when "close" then
          @multiplexer.close data["ch"]
        when "run" then
          ch = run(data["args"])
          @multiplexer.output 0, Distributor::OkJson.encode({ "id" => data["id"], "command" => "ack", "ch" => ch })
        else
          @on_command.call command, data
        end
      end
    end
  end

  def run(command)
    ch = @multiplexer.reserve

    rd, wr, pid = PTY.spawn(command)

    # handle data incoming from process
    @connector.handle(rd) do |io|
      begin
        @multiplexer.output(ch, io.readpartial(4096))
      rescue EOFError
        @multiplexer.close(ch)
        @connector.close(io)
      end
    end

    # handle data incoming on the multiplexer
    @connector.handle(@multiplexer.reader(ch)) do |input_io|
      data = input_io.readpartial(4096)
      wr.write data
    end

    ch
  end

  def tunnel(port)
    ch = @multiplexer.reserve

    tcp = TCPSocket.new("localhost", port)

    # handle data incoming from process
    @connector.handle(tcp) do |io|
      begin
        @multiplexer.output(ch, io.readpartial(4096))
      rescue EOFError
        @multiplexer.close(ch)
        @connector.close(io)
      end
    end

    # handle data incoming on the multiplexer
    @connector.handle(@multiplexer.reader(ch)) do |input_io|
      data = input_io.readpartial(4096)
      tcp.write data
    end

    ch
  end

  def command(command, data={})
    data["id"] ||= @multiplexer.generate_id
    data["command"] = command
    @multiplexer.output 0, Distributor::OkJson.encode(data)
    data["id"]
  end

  def on_command(&blk)
    @on_command = blk
  end

  def start
    @multiplexer.output 0, Distributor::OkJson.encode({ "command" => "hello" })
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
