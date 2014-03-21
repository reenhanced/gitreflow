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
  config.color_enabled = true
  config.before(:each) do
    WebMock.reset!
  end
  config.after(:each) do
    WebMock.reset!
  end
end
