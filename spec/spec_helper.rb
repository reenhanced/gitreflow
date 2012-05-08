require 'rubygems'
require 'rspec'
require 'json'
require 'webmock/rspec'
require 'ruby-debug'

$LOAD_PATH << 'lib'
require 'git_reflow'
require 'github_api'

RSpec.configure do |config|
  config.include WebMock::API
  config.color_enabled = true
  config.before(:each) do
    WebMock.reset!
  end
end

def stub_get(path, endpoint = Github.endpoint.to_s)
  stub_request(:get, endpoint + path)
end

def stub_post(path, endpoint = Github.endpoint.to_s)
  stub_request(:post, endpoint + path)
end

def stub_patch(path, endpoint = Github.endpoint.to_s)
  stub_request(:patch, endpoint + path)
end

def stub_put(path, endpoint = Github.endpoint.to_s)
  stub_request(:put, endpoint + path)
end

def stub_delete(path, endpoint = Github.endpoint.to_s)
  stub_request(:delete, endpoint + path)
end

def a_get(path, endpoint = Github.endpoint.to_s)
  a_request(:get, endpoint + path)
end

def a_post(path, endpoint = Github.endpoint.to_s)
  a_request(:post, endpoint + path)
end

def a_patch(path, endpoint = Github.endpoint.to_s)
  a_request(:patch, endpoint + path)
end

def a_put(path, endpoint = Github.endpoint)
  a_request(:put, endpoint + path)
end

def a_delete(path, endpoint = Github.endpoint)
  a_request(:delete, endpoint + path)
end

def fixture_path
  File.expand_path("../fixtures", __FILE__)
end

def fixture(file)
  File.new(File.join(fixture_path, '/', file))
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
