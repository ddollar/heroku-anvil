class Heroku::Client
  def releases_new(app_name)
    json_decode(get("/apps/#{app_name}/releases/new").to_s)
  end

  def releases_create(app_name, payload)
    json_decode(post("/apps/#{app_name}/releases", json_encode(payload)))
  end

  def release(app_name, slug, description, options={})
    release = releases_new(app_name)
    RestClient.put(release["slug_put_url"], File.open(slug, "rb"), :content_type => nil)
    payload = release.merge({
      "slug_version" => 2,
      "run_deploy_hooks" => true,
      "user" => user,
      "release_descr" => description,
      "head" => Digest::SHA1.hexdigest(Time.now.to_f.to_s)
    }) { |k, v1, v2| v1 || v2 }.merge(options)
    releases_create(app_name, payload)
  end
end
