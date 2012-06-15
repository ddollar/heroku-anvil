require "distributor"

class Distributor::Connector

  attr_reader :connections

  def initialize
    @connections = {}
    @on_close = Hash.new { |hash,key| hash[key] = Array.new }
  end

  def handle(from, &handler)
    return unless from
    @connections[from] = handler
  end

  def on_close(from, &handler)
    @on_close[from] << handler
  end

  def listen
    rs, ws = IO.select(@connections.keys, [], [], 1)
    (rs || []).each do |from|
      begin
        @on_close[from].each { |c| c.call(from) } if from.eof?
        @connections[from].call(from)
      rescue Errno::EIO
      end
    end
  end

  def close(io)
    @connections.delete(io)
    @on_close[io].each { |c| c.call(io) }
  end

end
