require 'aruba/cucumber'
require 'ruby-debug'

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

def has_subcommand?(command)
  found = processes.reverse.find{ |name, _| name == command }
  found[-1] if found
end
