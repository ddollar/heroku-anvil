require "distributor"

class Distributor::Connector

  attr_reader :connections

  def initialize
    @connections = {}
  end

  def handle(from, &handler)
    @connections[from] = handler
  end

  def listen
    rs, ws = IO.select(@connections.keys)
    rs.each { |from| self.connections[from].call(from) }
  end

end
