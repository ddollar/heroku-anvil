# release slugs
#
class Heroku::Command::Release < Heroku::Command::Base

  # release SLUG_URL
  #
  # release a slug
  #
  def index
    error("Usage: heroku release SLUG_URL") unless build_url = shift_argument
    validate_arguments!

    action("Releasing to #{app}") do
      release = heroku.release(app, "Anvil deploy", :build_url => build_url)
      status release["release"]
    end
  end

private

end
