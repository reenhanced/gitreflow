require 'spec_helper'

describe GitReflow::GitServer::BitBucket do
  let(:user)         { 'reenhanced' }
  let(:password)     { 'shazam' }
  let(:repo)         { 'repo' }
  let(:api_key)      { 'a1b2c3d4e5f6g7h8i9j0' }
  let(:hostname)     { 'hostname.local' }
  let(:api_endpoint) { 'https://bitbucket.org/api/1.0' }
  let(:site)         { 'https://bitbucket.org' }
  let(:remote_url)   { "git@bitbucket.org:#{user}/#{repo}.git" }

  before do
    allow_any_instance_of(HighLine).to receive(:ask) do |terminal, question|
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
      expect(GitReflow::Config).to receive(:set).once.with('reflow.git-server', 'BitBucket', local: false)
      subject
    end

    context 'storing git config settings only for this project' do
      subject { GitReflow::GitServer::BitBucket.new(project_only: true) }

      it 'sets the enterprise site and api as the site and api endpoints for the BitBucket provider in the git config' do
        expect(GitReflow::Config).to receive(:set).once.with('reflow.git-server', 'BitBucket', local: true)
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
        allow(GitReflow::Config).to receive(:set).with('reflow.git-server', 'BitBucket', local: false)
        allow(GitReflow::Config).to receive(:get).with('remote.origin.url').and_return(remote_url)
        allow(GitReflow::Config).to receive(:get).with('bitbucket.user', local: false).and_return(user)
        allow(GitReflow::Config).to receive(:get).with('bitbucket.api-key', reload: true, local: false).and_return(api_key)
        allow(GitReflow::Config).to receive(:get).with('reflow.local-projects', all: true).and_return('')
        expect { subject }.to have_output "\nYour BitBucket account was already setup with:"
        expect { subject }.to have_output "\tUser Name: #{user}"
      end
    end

    context 'not yet authenticated' do
      context 'with valid BitBucket credentials' do
        before do
          allow(GitReflow::Config).to receive(:get).and_return('')
          allow(GitReflow::Config).to receive(:set)
          allow(GitReflow::Config).to receive(:set).with('bitbucket.api-key', reload: true).and_return(api_key)
          allow(GitReflow::Config).to receive(:get).with('bitbucket.api-key', reload: true).and_return('')
          allow(GitReflow::Config).to receive(:get).with('remote.origin.url').and_return(remote_url)
          allow(GitReflow::Config).to receive(:get).with('reflow.local-projects').and_return('')
          allow(bitbucket).to receive(:connection).and_return double(repos: double(all: []))
        end

        it "prompts me to setup an API key" do
          expect { subject }.to have_output "\nIn order to connect your BitBucket account,"
          expect { subject }.to have_output "you'll need to generate an API key for your team"
          expect { subject }.to have_output "Visit https://bitbucket.org/account/user/reenhanced/api-key/, to generate it\n"
        end
      end
    end
  end

end
