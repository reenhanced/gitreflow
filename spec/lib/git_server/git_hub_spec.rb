require 'spec_helper'

describe GitReflow::GitServer::GitHub do
  let(:user)                   { 'reenhanced' }
  let(:password)               { 'shazam' }
  let(:repo)                   { 'repo' }
  let(:oauth_token_hash)       { Hashie::Mash.new({ token: 'a1b2c3d4e5f6g7h8i9j0'}) }
  let(:hostname)               { 'hostname.local' }
  let(:github_site)            { 'https://github.com' }
  let(:github_api_endpoint)    { 'https://api.github.com' }
  let(:enterprise_site)        { 'https://github.gittyup.com' }
  let(:enterprise_api)         { 'https://github.gittyup.com/api/v3' }
  let(:github)                 { stub_github_with(pull: existing_pull_request) }
  let!(:github_api)            { github.connection }
  let(:existing_pull_request)  { Fixture.new('pull_requests/pull_request.json').to_json_hashie }
  let(:existing_pull_requests) { Fixture.new('pull_requests/pull_requests.json').to_json_hashie }

  before do
    HighLine.any_instance.stub(:ask) do |terminal, question|
      values = {
        "Please enter your GitHub username: "                                                 => user,
        "Please enter your GitHub password (we do NOT store this): "                          => password,
        "Please enter your Enterprise site URL (e.g. https://github.company.com):"            => enterprise_site,
        "Please enter your Enterprise API endpoint (e.g. https://github.company.com/api/v3):" => enterprise_api
      }
     return_value = values[question]
     question = ""
     return_value
    end

    github.class.stub(:remote_user).and_return(user)
    github.class.stub(:remote_repo_name).and_return(repo)
  end

  describe '#initialize(options)' do
    subject { GitReflow::GitServer::GitHub.new({}) }

    it 'sets the reflow git server provider to GitHub in the git config' do
      GitReflow::Config.should_receive(:set).once.with('github.site', github_site, local: false)
      GitReflow::Config.should_receive(:set).once.with('github.endpoint', github_api_endpoint, local: false)
      GitReflow::Config.should_receive(:set).once.with('reflow.git-server', 'GitHub', local: false)
      subject
    end

    context 'using enterprise' do
      subject { GitReflow::GitServer::GitHub.new(enterprise: true) }

      it 'sets the enterprise site and api as the site and api endpoints for the GitHub provider in the git config' do
        GitReflow::Config.should_receive(:set).once.with('github.site', enterprise_site, local: false)
        GitReflow::Config.should_receive(:set).once.with('github.endpoint', enterprise_api, local: false)
        GitReflow::Config.should_receive(:set).once.with('reflow.git-server', 'GitHub', local: false)
        subject
      end

    end

    context 'storing git config settings only for this project' do
      subject { GitReflow::GitServer::GitHub.new(project_only: true) }

      before do
        GitReflow::Config.should_receive(:get).twice.with('reflow.local-projects', all: true).and_return("#{user}/#{repo}")
      end

      it 'sets the enterprise site and api as the site and api endpoints for the GitHub provider in the git config' do
        GitReflow::Config.should_receive(:set).once.with('github.site', github_site, local: true).and_call_original
        GitReflow::Config.should_receive(:set).once.with('github.endpoint', github_api_endpoint, local: true)
        GitReflow::Config.should_receive(:set).once.with('reflow.git-server', 'GitHub', local: true)
        subject
      end
    end

  end

  describe '#authenticate' do
    let(:github)                { GitReflow::GitServer::GitHub.new({}) }
    let!(:github_api)           { Github.new }
    let(:github_authorizations) { Github::Client::Authorizations.new }
    subject                     { github.authenticate }

    before  do
      GitReflow::GitServer::GitHub.stub(:user).and_return('reenhanced')
      github_api.stub(:oauth).and_return(github_authorizations)
      github_api.stub_chain(:oauth, :all).and_return([])
      github.stub(:run).with('hostname', loud: false).and_return(hostname)
    end

    context 'not yet authenticated' do
      context 'with valid GitHub credentials' do

        before do
          Github.stub(:new).and_return(github_api)
          github_authorizations.stub(:authenticated?).and_return(true)
          github_api.oauth.stub(:create).with({ scopes: ['repo'], note: "git-reflow (#{hostname})" }).and_return(oauth_token_hash)
        end

        it "notifies the user of successful setup" do
          expect { subject }.to have_output "\nYour GitHub account was successfully setup!"
        end

        it "creates a new GitHub oauth token" do
          github_api.oauth.should_receive(:create).and_return(oauth_token_hash)
          subject
        end

        it "creates git config keys for github connections" do
          expect{ subject }.to have_run_command_silently "git config --global --replace-all github.site \"#{GitReflow::GitServer::GitHub.site_url}\""
          expect{ subject }.to have_run_command_silently "git config --global --replace-all github.endpoint \"#{GitReflow::GitServer::GitHub.api_endpoint}\""
          expect{ subject }.to have_run_command_silently "git config --global --replace-all github.oauth-token \"#{oauth_token_hash[:token]}\""
          expect{ subject }.to have_run_command_silently "git config --global --replace-all reflow.git-server \"GitHub\""
        end

        context "exclusive to project" do
          let(:github) do
            allow(GitReflow::GitServer::GitHub).to receive(:project_only?).and_return(true)
            allow(GitReflow::GitServer::GitHub).to receive(:remote_user).and_return(user)
            allow(GitReflow::GitServer::GitHub).to receive(:remote_repo_name).and_return(repo)
            GitReflow::GitServer::GitHub.new(project_only: true)
          end

          it "creates _local_ git config keys for github connections" do
            expect{ subject }.to_not have_run_command_silently "git config --global --replace-all github.site \"#{GitReflow::GitServer::GitHub.site_url}\""
            expect{ subject }.to_not have_run_command_silently "git config --global --replace-all github.endpoint \"#{GitReflow::GitServer::GitHub.api_endpoint}\""
            expect{ subject }.to_not have_run_command_silently "git config --global --replace-all github.oauth-token \"#{oauth_token_hash[:token]}\""
            expect{ subject }.to_not have_run_command_silently "git config --global --replace-all reflow.git-server \"GitHub\""

            expect{ subject }.to have_run_command_silently "git config --replace-all github.site \"#{GitReflow::GitServer::GitHub.site_url}\""
            expect{ subject }.to have_run_command_silently "git config --replace-all github.endpoint \"#{GitReflow::GitServer::GitHub.api_endpoint}\""
            expect{ subject }.to have_run_command_silently "git config --replace-all github.oauth-token \"#{oauth_token_hash[:token]}\""
            expect{ subject }.to have_run_command_silently "git config --replace-all reflow.git-server \"GitHub\""
            expect{ subject }.to have_run_command_silently "git config --global --add reflow.local-projects \"#{user}/#{repo}\""
          end
        end

        context "use GitHub enterprise account" do
          let(:github) { GitReflow::GitServer::GitHub.new(enterprise: true) }
          before { GitReflow::GitServer::GitHub.stub(:@using_enterprise).and_return(true) }
          it "creates git config keys for github connections" do
            expect{ subject }.to have_run_command_silently "git config --global --replace-all github.site \"#{enterprise_site}\""
            expect{ subject }.to have_run_command_silently "git config --global --replace-all github.endpoint \"#{enterprise_api}\""
            expect{ subject }.to have_run_command_silently "git config --global --replace-all github.oauth-token \"#{oauth_token_hash[:token]}\""
            expect{ subject }.to have_run_command_silently "git config --global --replace-all reflow.git-server \"GitHub\""
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
          expect { subject }.to have_output "\nGithub Authentication Error: #{Github::Error::Unauthorized.new(unauthorized_error_response).inspect}"
        end
      end
    end
  end

  describe '#create_pull_request(options)' do
    let(:title)          { 'Fresh title' }
    let(:body)           { 'Funky body' }
    let(:current_branch) { 'new-feature' }

    subject { github.create_pull_request({ title: title, body: body, base: 'master' }) }

    before do
      github.class.stub(:current_branch).and_return(current_branch)
      allow(GitReflow).to receive(:git_server).and_return(github)
      stub_request(:post, %r{/repos/#{user}/#{repo}/pulls}).
        to_return(body: Fixture.new('pull_requests/pull_request.json').to_s, status: 201, headers: {content_type: "application/json; charset=utf-8"})
    end

    specify { expect(subject.class.to_s).to eq('GitReflow::GitServer::GitHub::PullRequest') }

    it 'creates a pull request using the remote user and repo' do
      github_api.stub(:pull_requests)
      expect(github_api.pull_requests).to receive(:create).with(user, repo, title: title, body: body, head: "#{user}:#{current_branch}", base: 'master').and_return(existing_pull_request)
      subject
    end
  end

  describe '#find_open_pull_request(from, to)' do
    subject { github.find_open_pull_request({ from: 'new-feature', to: 'master'}) }

    it 'looks for an open pull request matching the remote user/repo' do
      subject.number.should == existing_pull_requests.first.number
    end

    context 'no pull request exists' do
      before do
        github_api.stub(:pull_requests)
        github_api.pull_requests.should_receive(:all).and_return([])
      end
      it     { should == nil }
    end
  end

  describe '#get_build_status(sha)' do
    let(:sha) { '6dcb09b5b57875f334f61aebed695e2e4193db5e' }
    subject   { github.get_build_status(sha) }
    before    { github_api.stub_chain(:repos, :statuses) }

    it 'gets the latest build status for the given commit hash' do
      github_api.repos.statuses.should_receive(:all).with(user, repo, sha).and_return([{ state: 'success'}])
      subject
    end
  end

  describe '#comment_authors_for_pull_request(pull_request, options = {})' do
  end

  describe '#get_committed_time(commit_sha)' do
  end

end
