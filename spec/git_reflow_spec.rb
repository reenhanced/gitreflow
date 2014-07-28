require 'spec_helper'

describe GitReflow do
  let(:github)           { Github.new basic_auth: "#{user}:#{password}" }
  let(:user)             { 'reenhanced' }
  let(:password)         { 'shazam' }
  let(:oauth_token_hash) { Hashie::Mash.new({ token: 'a1b2c3d4e5f6g7h8i9j0'}) }
  let(:repo)             { 'repo' }
  let(:enterprise_site)  { 'https://github.reenhanced.com' }
  let(:enterprise_api)   { 'https://github.reenhanced.com' }
  let(:hostname)         { 'hostname.local' }

  let(:github_authorizations) { Github::Authorizations.new }

  before do
    HighLine.any_instance.stub(:ask) do |terminal, question|
      values = {
        "Please enter your GitHub username: "                                                 => user,
        "Please enter your GitHub password (we do NOT store this): "                          => password,
        "Please enter your Enterprise site URL (e.g. https://github.company.com):"            => enterprise_site,
        "Please enter your Enterprise API endpoint (e.g. https://github.company.com/api/v3):" => enterprise_api,
        "Would you like to open it in your browser?"                                          => 'n'
      }
     return_value = values[question]
     question = ""
     return_value
    end
  end

  context :setup do
    let(:setup_options) { {} }
    subject             { GitReflow.setup(setup_options) }

    before do
      github.stub(:oauth).and_return(github_authorizations)
      github.stub_chain(:oauth, :all).and_return([])
      GitReflow.stub(:run).with('hostname', loud: false).and_return(hostname)
    end

    context "with valid GitHub credentials" do
      before do
        Github.stub(:new).and_return(github)
        github_authorizations.stub(:authenticated?).and_return(true)
        github.oauth.stub(:create).with({ scopes: ['repo'], note: "git-reflow (#{hostname})" }).and_return(oauth_token_hash)
      end

      it "notifies the user of successful setup" do
        $output.should include "\nYour GitHub account was successfully setup!"
      end

      it "creates a new GitHub oauth token" do
        github.oauth.should_receive(:create).and_return(oauth_token_hash)
        subject
      end

      it "creates git config keys for github connections" do
        subject

        has_ran_commands_in_order?([
          Hashie::Mash.new(command: "git config --global --replace-all github.site #{Github::Configuration::DEFAULT_SITE}"),
          Hashie::Mash.new(command: "git config --global --replace-all github.endpoint #{Github::Configuration::DEFAULT_ENDPOINT}" ),
          Hashie::Mash.new(command: "git config --global --replace-all github.oauth-token #{oauth_token_hash[:token]}")
        ]).should  == true
      end

      context "exclusive to project" do
        let(:setup_options) {{ project_only: true }}
        it "creates _local_ git config keys for github connections" do
          subject

          has_ran_commands_in_order?([
            Hashie::Mash.new(command: "git config --replace-all github.site #{Github::Configuration::DEFAULT_SITE}"),
            Hashie::Mash.new(command: "git config --replace-all github.endpoint #{Github::Configuration::DEFAULT_ENDPOINT}" ),
            Hashie::Mash.new(command: "git config --replace-all github.oauth-token #{oauth_token_hash[:token]}")
          ]).should  == true
        end
      end

      context "use GitHub enterprise account" do
        let(:setup_options) {{ enterprise: true }}
        it "creates git config keys for github connections" do
          subject

          has_ran_commands_in_order?([
            Hashie::Mash.new(command: "git config --global --replace-all github.site #{enterprise_site}"),
            Hashie::Mash.new(command: "git config --global --replace-all github.endpoint #{enterprise_api}" ),
            Hashie::Mash.new(command: "git config --global --replace-all github.oauth-token #{oauth_token_hash[:token]}")
          ]).should  == true
        end
      end

      context "oauth token already exists" do
        before { github.stub_chain(:oauth, :all).and_return [oauth_token_hash.merge(note: "git-reflow (#{hostname})")] }
        it "uses existing authorization token" do
          github.oauth.unstub(:create)
          github.oauth.should_not_receive(:create)
          subject
          has_ran_command?(Hashie::Mash.new(command: "git config --global --replace-all github.oauth-token #{oauth_token_hash[:token]}", options: { loud: false }))
        end
      end
    end

    context "with invalid GitHub credentials" do
      let(:unauthorized_error_response) {{
        response_headers: {'content-type' => 'application/json; charset=utf-8', status: 'Unauthorized'},
        method: 'GET',
        status: '401',
        body: { error: "GET https://api.github.com/authorizations: 401 Bad credentials" }
      }}

      before do
        Github.should_receive(:new).and_raise Github::Error::Unauthorized.new(unauthorized_error_response)
      end

      it "notifies user of invalid login details" do
        subject
        $output.should include "\nInvalid username or password"
      end
    end
  end

  context :github do
    before do
      GitReflow.stub(:github_oauth_token).and_return(oauth_token_hash[:token])
    end

    it "creates a new authorization from the stored oauth token" do
      github = GitReflow.github
      github.oauth_token.should == oauth_token_hash[:token]
    end
  end

  # Github Response specs thanks to:
  # https://github.com/peter-murach/github/blob/master/spec/github/pull_requests_spec.rb
  context :review do
    let(:branch) { 'new-feature' }
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
      stub_github_with({
        :user         => user,
        :password     => password,
        :repo         => repo,
        :branch       => branch,
        :pull         => inputs
      })
    end

    subject { GitReflow.review inputs }

    it "fetches the latest changes to the destination branch" do
      GitReflow.should_receive(:fetch_destination).with(inputs['base'])
      github.pull_requests.should_receive(:create)
      subject
    end

    it "pushes the latest current branch to the origin repo" do
      GitReflow.should_receive(:push_current_branch)
      subject
    end

    context "pull request doesn't exist" do
      it "successfully creates a pull request if I do not provide one" do
        github.pull_requests.should_receive(:create).with(user, repo, inputs.except('state'))
        GitReflow.review inputs
        $output.should include "Successfully created pull request #1: #{inputs['title']}\nPull Request URL: http://github.com/#{user}/#{repo}/pulls/1\n"
      end
    end

    context "pull request exists" do
      let(:existing_pull_request) { Hashie::Mash.new({ html_url: "http://github.com/#{user}/#{repo}/pulls/1" }) }

      before do
        GitReflow.stub(:push_current_branch)
        github_error = Github::Error::UnprocessableEntity.new( eval(fixture('pull_requests/pull_request_exists_error.json').read) )
        github.pull_requests.stub(:create).with(user, repo, inputs.except('state')).and_raise(github_error)
        GitReflow.stub(:display_pull_request_summary).with(existing_pull_request)
        GitReflow.stub(:find_pull_request).with( from: branch, to: 'master').and_return(existing_pull_request)
      end

      subject { GitReflow.review inputs }

      it "displays a pull request summary for the existing pull request" do
        GitReflow.should_receive(:display_pull_request_summary).with(existing_pull_request)
        subject
      end

      it "asks to open the pull request in the browser" do
        GitReflow.should_receive(:ask_to_open_in_browser).with(existing_pull_request.html_url)
        subject
      end
    end
  end

  context :deliver do
    let(:branch)                { 'new-feature' }
    let(:inputs)                { {} }
    let(:existing_pull_request) { Hashie::Mash.new({ html_url: "http://github.com/# { user}/# { repo}/pulls/1" }) }

    before do
      stub_github_with({
        :user         => user,
        :password     => password,
        :repo         => repo,
        :branch       => branch
      })
    end

    subject { GitReflow.deliver inputs }

    it "fetches the latest changes to the destination branch" do
      GitReflow.should_receive(:fetch_destination).with('master')
      GitReflow.stub(:find_pull_request)
      subject
    end

    it "looks for a pull request matching the feature branch and destination branch" do
      GitReflow.should_receive(:find_pull_request).with(from: branch, to: 'master')
      subject
    end

    context "and pull request exists for the feature branch to the destination branch" do
      before { GitReflow.stub(:find_pull_request).and_return(fixtures('pull_requests/pull_request.json')) }

      it "successfully finds a pull request for the current feature branch" do
        GitReflow.deliver
        $output.should include "Merging pull request #1: 'new-feature', from 'reenhanced:new-feature' into 'reenhanced:master'"
      end

      it "checks out the destination branch and updates any remote changes" do
        GitReflow.should_receive(:update_destination)
        GitReflow.deliver
      end

      it "merges and squashes the feature branch into the master branch" do
        GitReflow.should_receive(:merge_feature_branch)
        GitReflow.deliver
      end
    end

    context "and no pull request exists for the feature branch to the destination branch" do
      before { GitReflow.stub(:find_pull_request).and_return(nil) }

      it "notifies the user of a missing pull request" do
        subject
        $output.should include "Error: No pull request exists for #{user}:#{branch}\nPlease submit your branch for review first with \`git reflow review\`"
      end
    end
  end
end
