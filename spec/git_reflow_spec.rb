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

  context :start do

  end

  context :deliver do

  end
end
