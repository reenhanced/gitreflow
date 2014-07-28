require 'rubygems'
require 'rspec'
require 'multi_json'
require 'webmock/rspec'

$LOAD_PATH << 'lib'
require 'git_reflow'

Dir[File.expand_path('../support/**/*.rb', __FILE__)].each {|f| require f}

RSpec.configure do |config|
  #config.include GithubHelpers
  config.include WebMock::API
  config.include CommandLineHelpers
  config.include GithubHelpers

  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end

  config.mock_with :rspec do |c|
    c.syntax = [:should, :expect]
  end

  config.before(:each) do
    WebMock.reset!
    stub_command_line
  end

  config.after(:each) do
    WebMock.reset!
    reset_stubbed_command_line
  end
end
