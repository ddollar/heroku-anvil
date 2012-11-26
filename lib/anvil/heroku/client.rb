class Heroku::Client

  # valid options:
  #
  # slug_url: url to a slug
  #
  def release(app_name, description, options={}, interval = 2)
    release_options = json_encode({ "description" => description }.merge(Hash[options.map{|k,v| [k.to_s, v]}]))
    headers = {:content_type => :json, :accept => :json}
    response = RestClient.post "#{releases_host}/v1/apps/#{app_name}/release", release_options, headers

    # poll until it's not a 202 Accepted http status
    while response.code == 202
      response = RestClient.get releases_host + response.headers[:location], options
      sleep(interval)
      yield
    end

    json_decode(response)
  end

  def routes(app_name)
    Heroku::OkJson.decode(get("/apps/#{app_name}/routes").to_s)
  end

  def routes_create(app_name, proto=nil)
    query = (proto.nil? ? "" : "?proto=#{proto}")
    Heroku::OkJson.decode(post("/apps/#{app_name}/routes#{query}").to_s)
  end

  def route_attach(app_name, url, ps)
    put("/apps/#{app_name}/routes/attach", {"url" => URI.escape(url), "ps" => URI.escape(ps)})
  end

  def route_detach(app_name, url, ps)
    put("/apps/#{app_name}/routes/detach", {"url" => URI.escape(url), "ps" => URI.escape(ps)})
  end

  def route_destroy(app_name, url)
    delete("/apps/#{app_name}/routes?url=#{URI.escape(url)}", {})
  end

private

  def releases_host
    ENV["RELEASES_HOST"] || "https://:#{Heroku::Auth.password}@cisaurus.heroku.com"
  end

  def releases_api
    RestClient::Resource.new(releases_host, Heroku::Auth.user, Heroku::Auth.password)
  end

end
