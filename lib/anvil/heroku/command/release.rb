# release slugs
#
class Heroku::Command::Release < Heroku::Command::Base

  # release SLUG_URL
  #
  # release a slug
  #
  # -p, --procfile PROCFILE  # use an alternate Procfile to define process types
  #
  def index
    error("Usage: heroku release SLUG_URL") unless build_url = shift_argument
    validate_arguments!

    action("Releasing to #{app}.#{heroku.host}") do
      release_options = {
        :build_url => build_url,
        :cloud     => heroku.host
      }

      if options[:procfile] then
        release_options[:processes] = File.read(options[:procfile]).split("\n").inject({}) do |ax, line|
          if line =~ /^([A-Za-z0-9_]+):\s*(.+)$/
            ax[$1] = $2
          end
          ax
        end
      end

      release = heroku.release(app, "Anvil deploy", release_options)
      status release["release"]
    end
  end

private

end
