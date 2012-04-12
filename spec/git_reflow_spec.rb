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

  context :current_branch do
    before do
      GitReflow.stub(:current_branch).and_return('banana')
    end

    it "returns the current working branch name" do
      GitReflow.should_receive(:current_branch).and_return('banana')
      GitReflow.current_branch
    end
  end

  context :remote_user do
    before do
      GitReflow.stub(:remote_user).and_return('reenhanced')
    end

    it "returns the github user associated with the origin remote repo" do
      GitReflow.should_receive(:remote_user).and_return('reenhanced')
      GitReflow.remote_user
    end
  end

  context :remote_repo_name do
    before do
      GitReflow.stub(:remote_repo_name).and_return('gitreflow')
    end

    it "returns the name of the origin remote repo on GitHub" do
      GitReflow.should_receive(:remote_repo_name).and_return('gitreflow')
      GitReflow.remote_repo_name
    end
  end

  context :github do
    before do
      GitReflow.stub(:get_oauth_token).and_return('12345')
    end

    it "creates a new authorization from the stored oauth token" do
      Github.should_receive(:new).with({:oauth_token => '12345'})
      GitReflow.should_receive(:get_oauth_token).and_return('12345')
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
  end
end
