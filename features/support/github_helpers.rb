require 'spec_helper'
module GithubHelpers
  def stub_github_with(options = {})
    github = Github.new
    user = options[:user] || 'reenhanced'
    repo = options[:repo] || 'repo'
    branch = options[:branch] || 'new-feature'
    pull = options[:pull]

    Github.stub :new => github
    GitReflow.stub(:push_current_branch).and_return(true)
    GitReflow.stub(:github).and_return(github)
    GitReflow.stub(:current_branch).and_return(branch)
    GitReflow.stub(:remote_repo_name).and_return(repo)
    GitReflow.stub(:remote_user).and_return(user)
    GitReflow.stub(:fetch_destination).and_return(true)

    if pull
      # Stubbing review
      github.pull_requests.stub(:create).with(user, repo, pull.except('state')).and_return(Hashie::Mash.new(:number => '1', :title => pull['title'], :html_url => "http://github.com/#{user}/#{repo}/pulls/1"))
      stub_post("/repos/#{user}/#{repo}/pulls").
        to_return(:body => fixture('pull_requests/pull_request.json'), :status => 201, :headers => {:content_type => "application/json\; charset=utf-8"})

      #github.pull_requests.should_receive(:create).with(user, repo, pull.except('state'))

      # Stubbing pull request finder
      stub_get("/repos/#{user}/#{repo}/pulls").with(:query => {'state' => 'open'}).
        to_return(:body => fixture('pull_requests/pull_requests.json'), :status => 201, :headers => {:content_type => "application/json; charset=utf-8"})
    end
  end
end

World(GithubHelpers)
