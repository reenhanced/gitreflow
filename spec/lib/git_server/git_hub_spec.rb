require 'spec_helper'

describe GitReflow::GitServer::GitHub do
  let(:github_site) { 'https://github.com' }
  let(:github_api)  { 'https://api.github.com' }

  describe '#initialize(options)' do
    subject { GitReflow::GitServer::GitHub.new({}) }

    before { GitReflow::GitServer::GitHub.any_instance.stub(:authenticate) }

    it 'authenticates with GitHub' do
      GitReflow::GitServer::GitHub.any_instance.should_receive(:authenticate)
      subject
    end

    it 'sets the reflow git server provider to GitHub in the git config' do
      GitReflow::Config.should_receive(:set).once.with('github.site', github_site, local: false)
      GitReflow::Config.should_receive(:set).once.with('github.endpoint', github_api, local: false)
      GitReflow::Config.should_receive(:set).once.with('reflow.git-server', 'GitHub')
      subject
    end

    context 'using enterprise' do
      let(:enterprise_site) { 'https://github.gittyup.com' }
      let(:enterprise_api)  { 'https://github.gittyup.com/api/v3' }

      subject { GitReflow::GitServer::GitHub.new(enterprise: true) }

      before do
        HighLine.any_instance.stub(:ask) do |terminal, question|
          values = {
            "Please enter your Enterprise site URL (e.g. https://github.company.com):"            => enterprise_site,
            "Please enter your Enterprise API endpoint (e.g. https://github.company.com/api/v3):" => enterprise_api
          }
         return_value = values[question]
         question = ""
         return_value
        end
      end

      it 'sets the enterprise site and api as the site and api endpoints for the GitHub provider in the git config' do
        GitReflow::Config.should_receive(:set).once.with('github.site', enterprise_site, local: false)
        GitReflow::Config.should_receive(:set).once.with('github.endpoint', enterprise_api, local: false)
        GitReflow::Config.should_receive(:set).once.with('reflow.git-server', 'GitHub')
        subject
      end

    end

    context 'storing git config settings only for this project' do
      subject { GitReflow::GitServer::GitHub.new(project_only: true) }

      it 'sets the enterprise site and api as the site and api endpoints for the GitHub provider in the git config' do
        GitReflow::Config.should_receive(:set).once.with('github.site', github_site, local: true).and_call_original
        GitReflow::Config.should_receive(:set).once.with('github.endpoint', github_api, local: true)
        GitReflow::Config.should_receive(:set).once.with('reflow.git-server', 'GitHub', local: true)
        subject
      end
    end

  end

  describe '#authenticate' do
    let(:github) { GitReflow::GitServer::GitHub.new({}) }
    subject { github.authenticate }

    before  do
      GitReflow::GitServer::GitHub.stub(:user).and_return('reenhanced')
    end

    context 'already authenticated' do
      before { github.connection = true }
      it { expect{ subject }.to have_output "Your GitHub account was already setup with: " }
      it { expect{ subject }.to have_output "\tUser Name: reenhanced" }
      it { expect{ subject }.to have_output "\tEndpoint: #{github_api}" }
    end
  end
end
