require 'rubygems'
require 'rspec'
require 'json'
require 'webmock/rspec'
require 'ruby-debug'

$LOAD_PATH << 'lib'
require 'git_reflow'
require 'github_api'

require 'support/github_helpers'

RSpec.configure do |config|
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

# the github_api gem does some overrides to Hash so we have to make sure
# this still works here...
class Hash
  def except(*keys)
    cpy = self.dup
    keys.each { |key| cpy.delete(key) }
    cpy
  end
end
