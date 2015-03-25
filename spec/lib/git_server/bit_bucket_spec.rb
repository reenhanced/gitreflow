require 'spec_helper'

describe GitReflow::GitServer::BitBucket do
  let(:user)         { 'reenhanced' }
  let(:password)     { 'shazam' }
  let(:repo)         { 'repo' }
  let(:api_key)      { 'a1b2c3d4e5f6g7h8i9j0' }
  let(:hostname)     { 'hostname.local' }
  let(:api_endpoint) { 'https://bitbucket.org/api/1.0' }
  let(:site)         { 'https://bitbucket.org' }

  before do
    HighLine.any_instance.stub(:ask) do |terminal, question|
      values = {
        "Please enter your BitBucket username: " => user
      }
     return_value = values[question]
     question = ""
     return_value
    end
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
        GitReflow::Config.should_receive(:set).once.with('reflow.git-server', 'BitBucket', local: true)
        subject
      end
    end

  end

  describe '#authenticate' do
    let(:bitbucket)      { GitReflow::GitServer::BitBucket.new( { }) }
    let!(:bitbucket_api) { BitBucket.new }
    subject              { bitbucket.authenticate }

    context 'already authenticated' do
      it "notifies the user of successful setup" do
        GitReflow::Config.should_receive(:set).twice.with('reflow.git-server', 'BitBucket')
        GitReflow::Config.stub(:get).with('bitbucket.api-key').and_return(api_key)
        GitReflow::Config.should_receive(:get).twice.with('remote.origin.url').and_return(user)
        GitReflow::Config.should_receive(:get).once.with('bitbucket.user').and_return(user)
        expect { subject }.to have_output "\nYour BitBucket account was already setup with:"
        expect { subject }.to have_output "\tUser Name: #{user}"
      end
    end

    context 'not yet authenticated' do
      context 'with valid BitBucket credentials' do

        it "prompts me to setup an API key" do
          GitReflow::Config.should_receive(:set).once.with('reflow.git-server', 'BitBucket')
          GitReflow::Config.should_receive(:set).once.with('bitbucket.user', 'reenhanced', local: false)
          GitReflow::Config.should_receive(:get).once.with('bitbucket.api-key').and_return('')
          GitReflow::Config.should_receive(:get).once.with('bitbucket.site').and_return('')
          GitReflow::Config.should_receive(:get).twice.with('remote.origin.url').and_return("git@bitbucket.org:#{user}/#{repo}.git")
          expect { subject }.to have_output "\nIn order to connect your BitBucket account,"
          expect { subject }.to have_output "you'll need to generate an API key for your team"
          expect { subject }.to have_output "\nVisit https://bitbucket.org/account/user/reenhanced/api-key, and reference our README"
        end

        it "creates git config keys for bitbucket connections" do
          expect{ subject }.to have_run_command_silently "git config --global --replace-all bitbucket.user \"#{user}\""
          expect{ subject }.to have_run_command_silently "git config --global --replace-all reflow.git-server \"BitBucket\""
        end

        context "exclusive to project" do
          let(:bitbucket) { GitReflow::GitServer::BitBucket.new(project_only: true) }

          it "creates _local_ git config keys for bitbucket connections" do
            expect{ subject }.to_not have_run_command_silently "git config --global --replace-all reflow.git-server \"BitBucket\""
            expect{ subject }.to_not have_run_command_silently "git config --global --replace-all bitbucket.user \"#{user}\""

            expect{ subject }.to have_run_command_silently "git config --replace-all reflow.git-server \"BitBucket\""
            expect{ subject }.to have_run_command_silently "git config --replace-all bitbucket.user \"#{user}\""
          end
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
