require 'aruba/cucumber'

Before('@gem') do
  CukeGem.setup('./git_reflow.gemspec')
end

After('@gem') do
  CukeGem.teardown
end

Before do
  @dirs = [Dir.tmpdir, "aruba"]
  FileUtils.rm_rf @dirs
end

