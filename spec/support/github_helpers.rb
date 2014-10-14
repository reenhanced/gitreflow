$LOAD_PATH << 'lib'
require 'git_reflow'
require 'github_api'
require File.expand_path('../web_mocks', __FILE__)
require File.expand_path('../fixtures', __FILE__)

module GithubHelpers
  def stub_github_with(options = {})

    api_endpoint     = options[:api_endpoint] || "https://api.github.com"
    site_url         = options[:site_url] || "http://github.com"
    user             = options[:user] || 'reenhanced'
    password         = options[:passwordl] || 'shazam'
    oauth_token_hash = Hashie::Mash.new({ token: 'a1b2c3d4e5f6g7h8i9j0'})
    repo             = options[:repo] || 'repo'
    branch           = options[:branch] || 'new-feature'
    pull             = options[:pull]

    github_server = GitReflow::GitServer::GitHub.new

    github = Github.new do |config|
      config.basic_auth = "#{user}:#{password}"
      config.endpoint    = api_endpoint
      config.site        = site_url
      config.adapter     = :net_http
      config.ssl         = {:verify => false}
    end

    puts "Stubbing: https://#{user}:#{password}@#{api_endpoint.gsub('https://','')}/authorizations"
    stub_request(:get, "https://#{user}:#{password}@#{api_endpoint.gsub('https://','')}/authorizations").to_return(:body => oauth_token_hash.to_json, status: 200, headers: {})
    Github.stub(:new).and_return(github)
    GitReflow.stub(:git_server).and_return(github_server)
    GitReflow.stub(:push_current_branch).and_return(true)
    GitReflow.stub(:github).and_return(github)
    GitReflow.stub(:current_branch).and_return(branch)
    GitReflow.stub(:remote_repo_name).and_return(repo)
    GitReflow.stub(:remote_user).and_return(user)
    GitReflow.stub(:fetch_destination).and_return(true)
    GitReflow.stub(:update_destination).and_return(true)

    if pull
      # Stubbing review
      github.pull_requests.stub(:create).with(user, repo, pull.except('state')).and_return(Hashie::Mash.new(:number => '1', :title => pull['title'], :html_url => "http://github.com/#{user}/#{repo}/pulls/1"))
      stub_post("/repos/#{user}/#{repo}/pulls").
        to_return(:body => fixture('pull_requests/pull_request.json'), :status => 201, :headers => {:content_type => "application/json\; charset=utf-8"})

      # Stubbing pull request finder
      stub_get("/repos/#{user}/#{repo}/pulls").with(:query => {'base' => 'master', 'head' => 'new-feature', 'state' => 'open'}).
        to_return(:body => fixture('pull_requests/pull_requests.json'), :status => 201, :headers => {:content_type => "application/json; charset=utf-8"})
    end

    github_server
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
