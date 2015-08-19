$LOAD_PATH << 'lib'
require 'git_reflow'
require 'github_api'
require File.expand_path('../web_mocks', __FILE__)
require File.expand_path('../fixtures', __FILE__)

module GithubHelpers
  def stub_github_with(options = {})

    hostname         = options[:hostname] || 'hostname.local'
    api_endpoint     = options[:api_endpoint] || "https://api.github.com"
    site_url         = options[:site_url] || "https://github.com"
    user             = options[:user] || 'reenhanced'
    password         = options[:passwordl] || 'shazam'
    oauth_token_hash = Hashie::Mash.new({ token: 'a1b2c3d4e5f6g7h8i9j0', note: 'git-reflow (hostname.local)'})
    repo             = options[:repo] || 'repo'
    branch           = options[:branch] || 'new-feature'
    pull             = options[:pull]

    HighLine.any_instance.stub(:ask) do |terminal, question|
      values = {
        "Please enter your GitHub username: "                                                 => user,
        "Please enter your GitHub password (we do NOT store this): "                          => password,
        "Please enter your Enterprise site URL (e.g. https://github.company.com):"            => enterprise_site,
        "Please enter your Enterprise API endpoint (e.g. https://github.company.com/api/v3):" => enterprise_api
      }
     return_value = values[question] || values[terminal]
     question = ""
     return_value
    end

    github = Github.new do |config|
      config.oauth_token = oauth_token_hash.token
      config.endpoint    = api_endpoint
      config.site        = site_url
      config.adapter     = :net_http
      config.ssl         = {:verify => false}
    end

    stub_request(:get, "#{api_endpoint}/authorizations?").to_return(:body => [oauth_token_hash].to_json, status: 200, headers: {})
    Github.stub(:new).and_return(github)
    GitReflow.stub(:push_current_branch).and_return(true)
    GitReflow.stub(:github).and_return(github)
    GitReflow.stub(:current_branch).and_return(branch)
    GitReflow.stub(:remote_repo_name).and_return(repo)
    GitReflow.stub(:remote_user).and_return(user)
    GitReflow.stub(:fetch_destination).and_return(true)
    GitReflow.stub(:update_destination).and_return(true)

    GitReflow::GitServer::GitHub.any_instance.stub(:run).with('hostname', loud: false).and_return(hostname)
    github_server = GitReflow::GitServer::GitHub.new
    github_server.class.stub(:user).and_return(user)
    github_server.class.stub(:oauth_token).and_return(oauth_token_hash.token)
    github_server.class.stub(:site_url).and_return(site_url)
    github_server.class.stub(:api_endpoint).and_return(api_endpoint)
    github_server.class.stub(:remote_user).and_return(user)
    github_server.class.stub(:remote_repo).and_return(repo)
    github_server.class.stub(:oauth_token).and_return(oauth_token_hash.token)
    github_server.class.stub(:get_commited_time).and_return(Time.now)

    GitReflow.stub(:git_server).and_return(github_server)

    # Stubbing statuses for a given commit
    stub_request(:get, %r{#{GitReflow.git_server.class.api_endpoint}/repos/#{user}/commits/\w+}).
      to_return(:body => Fixture.new('repositories/commit.json.erb', repo_owner: user, repo_name: repo, commit_author: user).to_json.to_s, :status => 201, :headers => {:content_type => "application/json; charset=utf-8"})
    stub_request(:get, %r{#{GitReflow.git_server.class.api_endpoint}/repos/#{user}/commits/\w+/statuses?}).
      to_return(:body => Fixture.new('pull_requests/pull_requests.json').to_json.to_s, :status => 201, :headers => {:content_type => "application/json; charset=utf-8"})

    if pull
      # Stubbing review
      stub_post("/repos/#{user}/#{repo}/pulls").
        to_return(:body => pull.to_s, :status => 201, :headers => {:content_type => "application/json\; charset=utf-8"})

      # Stubbing pull request finder
      stub_get("/repos/#{user}/#{repo}/pulls/#{pull.number}").with(:query => {'access_token' => 'a1b2c3d4e5f6g7h8i9j0'}).
        to_return(:body => Fixture.new('pull_requests/pull_request.json').to_s, :status => 201, :headers => {:content_type => "application/json; charset=utf-8"})
      stub_get("/repos/#{user}/pulls").with(:query => {'access_token' => 'a1b2c3d4e5f6g7h8i9j0', 'base' => 'master', 'head' => "#{user}:#{branch}", 'state' => 'open'}).
        to_return(:body => Fixture.new('pull_requests/pull_requests.json').to_s, :status => 201, :headers => {:content_type => "application/json; charset=utf-8"})
      stub_get("/repos/#{user}/#{repo}/pulls").with(:query => {'access_token' => 'a1b2c3d4e5f6g7h8i9j0', 'base' => 'master', 'head' => "#{user}:#{branch}", 'state' => 'open'}).
        to_return(:body => Fixture.new('pull_requests/pull_requests.json').to_s, :status => 201, :headers => {:content_type => "application/json; charset=utf-8"})
      # Stubbing pull request comments
      stub_get("/repos/#{user}/pulls/#{pull.number}/comments?").with(:query => {'access_token' => 'a1b2c3d4e5f6g7h8i9j0'}).
        to_return(:body => Fixture.new('pull_requests/comments.json').to_s, :status => 201, :headers => {:content_type => "application/json; charset=utf-8"})
      # Stubbing issue comments
      stub_get("/repos/#{user}/issues/#{pull.number}/comments?").with(:query => {'access_token' => 'a1b2c3d4e5f6g7h8i9j0'}).
        to_return(:body => Fixture.new('issues/comments.json').to_s, :status => 201, :headers => {:content_type => "application/json; charset=utf-8"})
      # Stubbing pull request commits
      stub_get("/repos/#{user}/#{repo}/pulls/#{pull.number}/commits").with(query: {"access_token" => "a1b2c3d4e5f6g7h8i9j0"}).
        to_return(:body => Fixture.new("pull_requests/commits.json").to_s, status: 201, headers: {content_type: "application/json; charset=utf-8"})
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
