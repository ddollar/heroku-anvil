def base_files
  Dir[File.expand_path("../{bin,data,lib}/**/*", __FILE__)].select do |file|
    File.file?(file)
  end
end

def pkg(filename)
  FileUtils.mkdir_p("pkg")
  File.expand_path("../pkg/#{filename}", __FILE__)
end

def version
  require "anvil/version"
  Anvil::VERSION
end

file pkg("anvil-cli-#{version}.gem") => base_files do |t|
  sh "gem build anvil-cli.gemspec"
  sh "mv anvil-cli-#{version}.gem #{t.name}"
end

task "gem:build" => pkg("anvil-cli-#{version}.gem")

task "gem:clean" do
  clean pkg("anvil-cli-#{version}.gem")
end

task "gem:release" => "gem:build" do |t|
 sh "gem push #{pkg("anvil-cli-#{version}.gem")}"
 sh "git tag v#{version}"
 sh "git push origin master --tags"
end
