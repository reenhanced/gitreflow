require 'spec_helper'
require 'aruba/api'

describe :git_reflow do
  include Aruba::Api
  let(:github) { Github.new :basic_auth => "user:pass" }

  before do
    Github.stub :new => github
  end

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

  context :remote_user do
    before do
      GitReflow.stub(:get_origin_repo_user).and_return('reenhanced')
    end

    it "returns the github user associated with the origin remote repo" do
      GitReflow.should_receive(:get_origin_repo_user).and_return('reenhanced')
      GitReflow.repo_user
    end
  end

  context :remote_repo_name do
    before do
      GitReflow.stub(:get_origin_repo_name).and_return('gitreflow')
    end

    it "returns the name of the origin remote repo on GitHub" do
      GitReflow.should_receive(:get_origin_repo_name).and_return('gitreflow')
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

  context :deliver do
    before do
      github.pull_requests.stub(:create_request).and_return(true)
      GitReflow.stub(:get_oauth_token).and_return('12345')
    end

    it "creates a pull request if I do not provide one" do
      Github.should_receive(:create_request).with('reenhanced', 'repo',
                                                  'title' => 'Title',
                                                  'body' => 'Body',
                                                  'head' => 'reenhanced:banana')
      GitReflow.deliver
    end
  end
end
