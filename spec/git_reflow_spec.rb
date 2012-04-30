require 'spec_helper'
require 'aruba/api'

describe :git_reflow do
  include Aruba::Api
  let(:github) { Github.new }
  let(:user)   { 'reenhanced' }
  let(:repo)   { 'repo' }

  before do
    Github.stub :new => github
  end

  after { reset_authentication_for github }

  context :setup do

     before do
       github.oauth.stub(:create_authorization).and_return({:token => '12345'})
       GitReflow.stub(:set_oauth_token)
     end

     it "creates a new authorization" do
       STDIN.stub(:gets).and_return("user", "password")
       Github.should_receive :new
       github.oauth.should_receive(:create_authorization).with('scopes' => ['repo'])
       GitReflow.should_receive(:set_oauth_token).with('12345')
       GitReflow.setup
     end
  end

  context :github do
    before do
      GitReflow.stub(:get_oauth_token).and_return('12345')
    end

    it "creates a new authorization from the stored oauth token" do
      Github.should_receive(:new).with({:oauth_token => '12345'})
      GitReflow.should_receive(:get_oauth_token)
      GitReflow.github
    end
  end

  # Github Response specs thanks to:
  # https://github.com/peter-murach/github/blob/master/spec/github/pull_requests_spec.rb
  context :deliver do
    let(:inputs) {
      {
       "title" => "Amazing new feature",
       "body" => "Please pull this in!",
       "head" => "reenhanced:new-feature",
       "base" => "master",
       "state" => "open"
      }
    }

    before do
      GitReflow.stub(:push_current_branch).and_return(true)
      GitReflow.stub(:github).and_return(github)
      GitReflow.stub(:current_branch).and_return('new-feature')
      GitReflow.stub(:remote_repo_name).and_return(repo)
      github.pull_requests.stub(:create_request).with(user, repo, inputs.except('state')).and_return(Hashie::Mash.new(:number => '1', :title => inputs['title'], :url => "http://github.com/#{user}/#{repo}/pulls/1"))
      stub_post("/repos/#{user}/#{repo}/pulls").
        to_return(:body => fixture('pull_requests/pull_request.json'), :status => 201, :headers => {:content_type => "application/json; charset=utf-8"})
    end

    it "successfully creates a pull request if I do not provide one" do
      github.pull_requests.should_receive(:create_request).with(user, repo, inputs.except('state'))
      STDOUT.should_receive(:puts).with("Successfully created pull request #1: #{inputs['title']}\nPull Request URL: http://github.com/#{user}/#{repo}/pulls/1\n")
      GitReflow.deliver inputs
    end

    it "reports any errors returned from github" do
      github_error = Github::Error::UnprocessableEntity.new( eval(fixture('pull_requests/pull_request_exists_error.json').read) )
      github.pull_requests.stub(:create_request).with(user, repo, inputs.except('state')).and_raise(github_error)
      stub_post("/repos/#{user}/#{repo}/pulls").
        to_return(:body => fixture('pull_requests/pull_request_exists_error.json'), :status => 422, :headers => {:content_type => "application/json; charset=utf-8"})

      STDOUT.should_receive(:puts).with("GitHub Error: A pull request already exists for reenhanced:banana.")
      GitReflow.deliver inputs
    end

    it "pushes the latest current branch to the origin repo" do
      github.pull_requests.should_receive(:create_request)
      GitReflow.should_receive(:push_current_branch)
      GitReflow.should_receive(:current_branch)
      GitReflow.deliver
    end
  end
end
