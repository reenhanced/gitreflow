require 'aruba/cucumber'

Before('@gem') do
  CukeGem.setup('../../git_reflow.gemspec')
end

After('@gem') do
  CukeGem.teardown
end

Before do
  @real_home = ENV['HOME']
  fake_home = File.join('/tmp', 'fake_home')
  FileUtils.rm_rf fake_home, :secure => true
  ENV['HOME'] = fake_home
end

After do
  ENV['HOME'] = @real_home
end
