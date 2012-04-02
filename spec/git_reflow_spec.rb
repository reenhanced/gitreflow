require 'spec_helper'
require 'aruba/api'

describe :git_reflow do
  include Aruba::Api

  context :setup do
     let(:github) { Github.new :basic_auth => "user:pass" }

     before do
       Github.stub :new => github
       github.oauth.stub :create_authorization => true
     end

     it "creates a new authorization" do
       STDIN.stub(:gets).and_return("user", "password")
       Github.should_receive :new
       github.oauth.should_receive :create_authorization
       assert_matching_output 'New', all_stderr
       run_interactive '../../bin/git-reflow setup'
     end
  end

  context :start do

  end

  context :deliver do

  end
end
