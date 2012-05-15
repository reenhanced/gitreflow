require 'rubygems'
require 'rspec'
require 'json'
require 'webmock/rspec'
require 'ruby-debug'

$LOAD_PATH << 'lib'
require 'git_reflow'
require 'github_api'

Dir[File.expand_path('../support/**/*.rb', __FILE__)].each {|f| require f}

RSpec.configure do |config|
  config.include GithubHelpers
  config.include WebMock::API
  config.color_enabled = true
  config.before(:each) do
    WebMock.reset!
  end
end

OAUTH_TOKEN = 'bafec72922f31fe86aacc8aca4261117f3bd62cf'

def reset_authentication_for(object)
  [ 'user', 'repo', 'basic_auth', 'oauth_token', 'login', 'password' ].each do |item|
    object.send("#{item}=", nil)
  end
end
