require "anvil"
require "anvil/builder"
require "anvil/manifest"
require "anvil/version"
require "thor"
require "uri"

class Anvil::CLI < Thor

  map ["-v", "--version"] => :version

  desc "build [SOURCE]", "Build an application"

  method_option :buildpack, :type => :string,  :aliases => "-b", :desc => "Use a specific buildpack"
  method_option :pipeline,  :type => :boolean, :aliases => "-p", :desc => "Pipe compile output to stderr and put the slug url on stdout"

  def build(source=nil)
    if options[:pipeline]
      old_stdout = $stdout.dup
      $stdout = $stderr
    end

    source ||= "."

    build_options = {
      :buildpack => prepare_buildpack(options[:buildpack].to_s)
    }

    builder = if is_url?(source)
      Anvil::Builder.new(source)
    else
      manifest = Anvil::Manifest.new(File.expand_path(source))
      print "Uploading app... "
      count = manifest.upload
      puts "done, #{count} files uploaded"
      manifest
    end

    slug_url = builder.build(build_options) do |chunk|
      print chunk
    end

    old_stdout.puts slug_url if options[:pipeline]
  end

  desc "version", "Display Anvil version"

  def version
    puts Anvil::VERSION
  end

private

  def is_url?(string)
    URI.parse(string).scheme rescue nil
  end

  def prepare_buildpack(buildpack)
    if buildpack == ""
      buildpack
    elsif is_url?(buildpack)
      buildpack
    elsif buildpack =~ /\A\w+\/\w+\Z/
      "http://buildkits-dev.s3.amazonaws.com/buildpacks/#{buildpack}.tgz"
    elsif File.exists?(buildpack) && File.directory?(buildpack)
      print "Uploading buildpack... "
      manifest = Anvil::Manifest.new(buildpack)
      manifest.upload
      manifest.save
      puts "done"
    else
      error "unrecognized buildpack specification: #{buildpack}"
    end
  end

end
