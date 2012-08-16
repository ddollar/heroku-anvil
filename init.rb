Dir[File.join(File.expand_path("../vendor", __FILE__), "*")].each do |vendor|
  $:.unshift File.join(vendor, "lib")
end

require "anvil/heroku/client"
require "anvil/heroku/command/build"
require "anvil/heroku/command/cloud"
require "anvil/heroku/command/release"
require "anvil/heroku/command/start"
