require 'spec_helper'

describe GitReflow::GitServer::BitBucket do
  let(:user)                   { 'reenhanced' }
  let(:password)               { 'shazam' }
  let(:repo)                   { 'repo' }
  let(:access_token)           { 'a1b2c3d4e5f6g7h8i9j0' }
  let(:hostname)               { 'hostname.local' }

  before do
  end

  describe '#initialize(options)' do
    subject { GitReflow::GitServer::BitBucket.new({}) }

    it 'sets the reflow git server provider to BitBucket in the git config' do
      GitReflow::Config.should_receive(:set).once.with('reflow.git-server', 'BitBucket')
      subject
    end

    context 'storing git config settings only for this project' do
      subject { GitReflow::GitServer::BitBucket.new(project_only: true) }

      it 'sets the enterprise site and api as the site and api endpoints for the BitBucket provider in the git config' do
        GitReflow::Config.should_receive(:set).once.with('bitbucket.site', bitbucket_site, local: true).and_call_original
        GitReflow::Config.should_receive(:set).once.with('bitbucket.endpoint', bitbucket_api_endpoint, local: true)
        GitReflow::Config.should_receive(:set).once.with('reflow.git-server', 'BitBucket', local: true)
        subject
      end
    end

  end

  describe '#authenticate' do
    let(:bitbucket)                { GitReflow::GitServer::BitBucket.new({}) }
    let!(:bitbucket_api)           { BitBucket.new }
    subject                     { butbucket.authenticate }

    before  do
      GitReflow::GitServer::BitBucket.stub(:user).and_return('reenhanced')
    end

    context 'not yet authenticated' do
      context 'with valid BitBucket credentials' do

        it "notifies the user of successful setup" do
          expect { subject }.to have_output "\nYour BitBucket account was successfully setup!"
        end

        it "creates a new BitBucket oauth token" do
          bitbucket_api.oauth.should_receive(:create).and_return(oauth_token_hash)
          subject
        end

        it "creates git config keys for bitbucket connections" do
          expect{ subject }.to have_run_command_silently "git config --global --replace-all bitbucket.user \"#{oauth_token_hash[:token]}\""
          expect{ subject }.to have_run_command_silently "git config --global --replace-all bitbucket.api-token \"#{oauth_token_hash[:token]}\""
          expect{ subject }.to have_run_command_silently "git config --global --replace-all reflow.git-server \"BitBucket\""
        end

        context "exclusive to project" do
          let(:bitbucket) { GitReflow::GitServer::BitBucket.new(project_only: true) }
          before       { GitReflow::GitServer::BitBucket.stub(:@project_only).and_return(true) }

          it "creates _local_ git config keys for bitbucket connections" do
            expect{ subject }.to_not have_run_command_silently "git config --global --replace-all bitbucket.api-token \"#{api_token}\""
            expect{ subject }.to_not have_run_command_silently "git config --global --replace-all reflow.git-server \"BitBucket\""

            expect{ subject }.to have_run_command_silently "git config --replace-all bitbucket.site \"#{GitReflow::GitServer::BitBucket.site_url}\""
            expect{ subject }.to have_run_command_silently "git config --replace-all bitbucket.endpoint \"#{GitReflow::GitServer::BitBucket.api_endpoint}\""
            expect{ subject }.to have_run_command_silently "git config --replace-all bitbucket.oauth-token \"#{oauth_token_hash[:token]}\""
            expect{ subject }.to have_run_command_silently "git config --replace-all reflow.git-server \"BitBucket\""
          end
        end
      end

      context "with invalid BitBucket credentials" do
        let(:unauthorized_error_response) {{
          response_headers: {'content-type' => 'application/json; charset=utf-8', status: 'Unauthorized'},
          method: 'GET',
          status: '401',
          body: { error: "GET https://api.bitbucket.com/authorizations: 401 Bad credentials" }
        }}

        before do
          bitbucket.should_receive(:new).and_raise BitBucket::Error::Unauthorized.new(unauthorized_error_response)
        end

        it "notifies user of invalid login details" do
          expect { subject }.to have_output "\nInvalid username or password: #{BitBucket::Error::Unauthorized.new(unauthorized_error_response).inspect}"
        end
      end
    end
  end

  xdescribe '#create_pull_request(options)' do
    let(:title)          { 'Fresh title' }
    let(:body)           { 'Funky body' }
    let(:current_branch) { 'new-feature' }

    it 'creates a pull request using the remote user and repo' do
    end
  end

  xdescribe '#find_pull_request(from, to)' do
  end

  xdescribe '#pull_request_comments(pull_request)' do
  end

  xdescribe '#has_pull_request_comments?(pull_request)' do
  end

  xdescribe '#get_build_status(sha)' do
  end

  xdescribe '#find_authors_of_open_pull_request_comments(pull_request)' do
  end

  xdescribe '#comment_authors_for_pull_request(pull_request, options = {})' do
  end

  xdescribe '#get_commited_time(commit_sha)' do
  end

end
