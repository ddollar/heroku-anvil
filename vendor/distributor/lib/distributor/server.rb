require "distributor"
require "distributor/connector"
require "distributor/multiplexer"
require "pty"

class Distributor::Server

  def initialize(input, output=input)
    @connector   = Distributor::Connector.new
    @multiplexer = Distributor::Multiplexer.new(output)

    # reserve a command channel
    @multiplexer.reserve(0)

    # feed data from the input channel into the multiplexer
    @connector.handle(input) do |io|
      @multiplexer.input io
    end

    # handle the command channel of the multiplexer
    @connector.handle(@multiplexer.reader(0)) do |io|
      data = JSON.parse(io.readpartial(4096))

      case command = data["command"]
      when "run" then
        ch = run(data["args"])
        @multiplexer.output 0, JSON.dump({ "id" => data["id"], "command" => "launch", "ch" => ch })
      else
        raise "no such command: #{command}"
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
        puts "channel #{ch} exited"
      end
    end

    # handle data incoming on the multiplexer
    @connector.handle(@multiplexer.reader(ch)) do |input_io|
      data = input_io.readpartial(4096)
      wr.write data
    end

    ch
  end

  def start
    loop { @connector.listen }
  end

end
