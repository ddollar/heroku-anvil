class Heroku::Client

  # valid options:
  #
  # slug_url: url to a slug
  #
  def release(app_name, description, options={})
    release_options = { :description => description }.merge(options)
    json_decode(releaser["/apps/#{app_name}/release"].post(release_options))
  end

private

  def release_host
    ENV["RELEASE_HOST"] || "https://releases-test.herokuapp.com"
  end

  def releaser
    RestClient::Resource.new(release_host, Heroku::Auth.user, Heroku::Auth.password)
  end

end
