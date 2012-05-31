# release slugs
#
class Heroku::Command::Release < Heroku::Command::Base

  # release SLUG_URL
  #
  # release a slug
  #
  def index
    error("Usage: heroku release SLUG_URL") unless slug_url = shift_argument
    validate_arguments!

    Dir.mktmpdir do |dir|
      action("Downloading slug") do
        File.open("#{dir}/slug.img", "wb") do |file|
          file.print RestClient.get(slug_url).body
        end
      end
      release = heroku.releases_new(app)
      action("Releasing to #{app}") do
        release = heroku.release(app, "#{dir}/slug.img", "Anvil deploy", {
          "process_types" => parse_procfile("./Procfile")
        })
        @status = release["release"]
      end
    end
  end

private

  def parse_procfile(filename)
    return {} unless File.exists?(filename)
    File.read(filename).split("\n").inject({}) do |ax, line|
      if line =~ /^([A-Za-z0-9_]+):\s*(.+)$/
        ax[$1] = $2
      end
      ax
    end
  end

end
