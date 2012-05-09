require 'aruba/cucumber'
require 'ruby-debug'
require 'webmock/cucumber'
require 'cucumber/rspec/doubles'

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

WebMock.disable_net_connect!

def has_subcommand?(command)
  # In order to see if a subcommand is run
  # we have to look it up in Aruba's process list
  # Aruba has a get_process helper, but it errors if none is found
  # See: https://github.com/cucumber/aruba/blob/master/lib/aruba/api.rb#L239
  found = processes.reverse.find{ |name, _| name == command }
  found[-1] if found
end
