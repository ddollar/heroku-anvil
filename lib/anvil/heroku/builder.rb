require "heroku"

class Heroku::Builder

  class BuildError < StandardError; end

  def build(source, options={})
    uri  = URI.parse("#{anvil_host}/build")
    http = Net::HTTP.new(uri.host, uri.port)

    if uri.scheme == "https"
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    req = Net::HTTP::Post.new uri.request_uri

    req.set_form_data({
      "buildpack" => options[:buildpack],
      "cache"     => options[:cache],
      "env"       => options[:env] || {},
      "source"    => source
    })

    slug_url = nil

    http.request(req) do |res|
      slug_url = res["x-slug-url"]

      begin
        res.read_body do |chunk|
          yield chunk
        end
      rescue EOFError
        puts
        raise BuildError, "terminated unexpectedly"
      end

      code = if res["x-exit-code"].nil?
        manifest_id = res["x-manifest-id"].first
        Integer(String.new(anvil["/exit/#{manifest_id}"].get.to_s))
      else
        res["x-exit-code"].first.to_i
      end

      raise BuildError, "exited #{code}" unless code.zero?
    end

    slug_url
  end

private

  def anvil
    @anvil ||= RestClient::Resource.new(anvil_host)
  end

  def anvil_host
    ENV["ANVIL_HOST"] || "https://api.anvilworks.org"
  end

end
