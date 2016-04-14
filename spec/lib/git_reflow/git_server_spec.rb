require 'spec_helper'

describe GitReflow::GitServer do
  let(:connection_options) { nil }

  subject { GitReflow::GitServer.connect connection_options }

  before do
    allow(GitReflow::GitServer::GitHub).to receive(:new)

    module GitReflow::GitServer
      class DummyHub < Base
        def initialize(options)
          "Initialized with #{options}"
        end

        def authenticate(options={})
        end

        def connection
          'Connected!'
        end
      end
    end
  end

  describe '.connect(options)' do
    it 'initializes a new GitHub server provider by default' do
      stubbed_github = Class.new
      allow(stubbed_github).to receive(:authenticate)
      expect(GitReflow::GitServer::GitHub).to receive(:new).and_return(stubbed_github)
      subject
    end

    context 'provider is specified' do
      let(:connection_options) { {provider: 'DummyHub'}.merge(expected_server_options) }
      let(:expected_server_options) {{ basic_auth: 'user:pass', end_point: 'https://api.example.com' }}

      it 'initializes any server provider that has been implemented' do
        dummy_hub = GitReflow::GitServer::DummyHub.new({})
        expect(GitReflow::GitServer::DummyHub).to receive(:new).with(expected_server_options).and_return(dummy_hub)
        expect(subject).to eq(dummy_hub)
        expect($output).not_to include 'GitServer not setup for: DummyHub'
      end
    end

    context 'provider not yet implemented' do
      let(:connection_options) {{ provider: 'GitLab' }}
      it { expect{ subject }.to have_output "Error connecting to GitLab: GitServer not setup for \"GitLab\"" }
    end
  end

  describe '.current_provider' do
    subject { GitReflow::GitServer.current_provider }

    before { allow(GitReflow::Config).to receive(:get).with('reflow.git-server', local: true).and_return(nil) }

    context 'Reflow setup to use GitHub' do
      before { allow(GitReflow::Config).to receive(:get).with('reflow.git-server').and_return('GitHub') }
      it     { is_expected.to eq(GitReflow::GitServer::GitHub) }
    end

    context 'Reflow has not yet been setup' do
      before { allow(GitReflow::Config).to receive(:get).with('reflow.git-server').and_return('') }
      it     { is_expected.to be_nil }
      it     { expect{ subject }.to have_output "[notice] Reflow hasn't been setup yet.  Run 'git reflow setup' to continue" }
    end

    context 'an unknown server provider is stored in the git config' do
      before { allow(GitReflow::Config).to receive(:get).with('reflow.git-server').and_return('GittyUp') }

      it { is_expected.to be_nil }
      it { expect{ subject }.to have_output "GitServer not setup for \"GittyUp\"" }
    end
  end

  describe '.connection' do
    subject { GitReflow::GitServer.connection }

    before do
      allow(GitReflow::Config).to receive(:get).with('reflow.git-server', local: true).and_return(nil)
      allow(GitReflow::Config).to receive(:get).with('reflow.git-server').and_return(nil)
    end

    it { is_expected.to be_nil }

    context "with a valid provider" do
      before { allow(GitReflow::Config).to receive(:get).with('reflow.git-server').and_return('GitHub') }
      it 'calls connection on the provider' do
        expect(GitReflow::GitServer::GitHub).to receive(:connection)
        subject
      end
    end

    context "with an invalid provider" do
      before { allow(GitReflow::Config).to receive(:get).with('reflow.git-server').and_return('GittyUp') }
      it     { is_expected.to be_nil }
      it     { expect{ subject }.to have_output "GitServer not setup for \"GittyUp\"" }
    end
  end
end
