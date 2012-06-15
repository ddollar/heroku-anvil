$:.unshift File.expand_path("../lib", __FILE__)
require "distributor/version"

Gem::Specification.new do |gem|
  gem.name     = "distributor"
  gem.version  = Distributor::VERSION

  gem.author   = "David Dollar"
  gem.email    = "ddollar@gmail.com"
  gem.homepage = "http://github.com/ddollar/distributor"
  gem.summary  = "TCP Multiplexer"

  gem.description = gem.summary

  gem.files = Dir["**/*"].select { |d| d =~ %r{^(README|bin/|data/|ext/|lib/|spec/|test/)} }

  gem.add_dependency 'thor', '>= 0.13.6'

  if ENV["PLATFORM"] == "java"
    gem.add_dependency "posix-spawn", "~> 0.3.6"
    gem.platform = Gem::Platform.new("java")
  end

  if ENV["PLATFORM"] == "mingw32"
    gem.add_dependency "win32console", "~> 1.3.0"
    gem.platform = Gem::Platform.new("mingw32")
  end
end
