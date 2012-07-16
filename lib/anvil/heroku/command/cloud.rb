require "heroku/auth"
require "heroku/command/base"

class Heroku::Auth
  class << self
    @api = nil

    def host
      ENV["HEROKU_HOST"] || read_heroku_host || "heroku.com"
    end

    def heroku_host_file
      "#{home_directory}/.heroku/host"
    end

    def read_heroku_host
      File.read(heroku_host_file).chomp rescue nil
    end

    def write_heroku_host(host)
      if host == "heroku.com"
        FileUtils.rm_f heroku_host_file
      else
        File.open(heroku_host_file, "w") { |file| file.puts host }
      end
    end
  end
end

class Heroku::Command::Cloud < Heroku::Command::Base

  include Heroku::Helpers

  # cloud CLOUD
  #
  # switch clouds
  #
  # valid clouds:
  #   standard
  #   shadow
  #
  def index
    cloud = shift_argument
    validate_arguments!

    if cloud
      action("Switching to #{cloud} cloud") do
        heroku_host = case cloud
          when "standard" then "heroku.com"
          when "shadow"   then "heroku-shadow.com"
          else "#{cloud}.herokudev.com"
        end
        Heroku::Auth.write_heroku_host heroku_host
      end
    else
      puts case Heroku::Auth.host
        when "heroku.com"        then "standard"
        when "heroku-shadow.com" then "shadow"
        when /^(\w+).herokudev.com/ then $1
      end
    end
  end

end
