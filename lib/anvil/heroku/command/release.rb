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
      release = JSON.parse(releaser["/apps/#{app}/release"].post({
        :build_url   => build_url,
        :description => "Deployed from anvil"
      }).body)
      status release["release"]
    end
  end

private

  def auth
    Heroku::Auth
  end

  def release_host
    ENV["RELEASE_HOST"] || "https://releases-test.herokuapp.com"
  end

  def releaser
    RestClient::Resource.new(release_host, auth.user, auth.password)
  end

end
