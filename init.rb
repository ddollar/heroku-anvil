Dir[File.join(File.expand_path("../vendor", __FILE__), "*")].each do |vendor|
  $:.unshift File.join(vendor, "lib")
end

# fix ruby
require "net/http"
class Net::HTTPResponse
  def read_chunked(dest)
    len = nil
    total = 0
    while true
      line = @socket.readline
      hexlen = line.slice(/[0-9a-fA-F]+/) or
          raise Net::HTTPBadResponse, "wrong chunk size line: #{line}"
      len = hexlen.hex
      break if len == 0
      begin
        @socket.read len, dest
      ensure
        total += len
        @socket.read 2   # \r\n
      end
    end
    self.class.send(:each_response_header, @socket) do |k, v|
      add_field k, v
    end
  end
end

require "anvil/heroku/client"
require "anvil/heroku/command/build"
require "anvil/heroku/command/cloud"
require "anvil/heroku/command/release"
require "anvil/heroku/command/start"
