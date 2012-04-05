require 'spec_helper'
require 'aruba/api'

describe :git_reflow do
  include Aruba::Api

  context :setup do
     let(:github) { Github.new :basic_auth => "user:pass" }

     before do
       Github.stub :new => github
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
   let(:github) { Github.new :basic_auth => "user:pass" }

    before do
      Github.stub :new => github
      GitReflow.stub(:get_oauth_token).and_return('12345')
    end

    it "creates a new authorization from the stored oauth token" do
      Github.should_receive(:new).with({:oauth_token => '12345'})
      GitReflow.should_receive(:get_oauth_token).and_return('12345')
      GitReflow.github
    end
  end

  context :deliver do

  end
end
