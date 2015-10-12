require 'spec_helper'
require 'securerandom'

describe GitReflow::GitServer::BitBucket::PullRequest do
  let(:user)                  { 'reenhanced' }
  let(:password)              { 'shazam' }
  let(:repo)                  { 'repo' }
  let(:hostname)              { 'hostname.local' }
  let(:bitbucket)             { GitReflow::GitServer::BitBucket.new }
  let!(:bitbucket_api)        { bitbucket.connection }
  let(:site_url)              { 'https://bitbucket.org' }
  let(:api_endpoint)          { BitBucket::Configuration::DEFAULT_ENDPOINT }
  let(:existing_pull_request) { }

  subject { GitReflow::GitServer::BitBucket::PullRequest.new(existing_pull_request) }

  before do
    allow(BitBucket).to receive(:new).and_return(bitbucket)
    allow(GitReflow).to receive(:push_current_branch).and_return(true)
    allow(GitReflow).to receive(:current_branch).and_return(branch)
    allow(GitReflow).to receive(:remote_repo_name).and_return(repo)
    allow(GitReflow).to receive(:remote_user).and_return(user)
    allow(GitReflow).to receive(:fetch_destination).and_return(true)
    allow(GitReflow).to receive(:update_destination).and_return(true)

    allow_any_instance_of(GitReflow::GitServer::BitBucket).to receive(:run).with('hostname', loud: false).and_return(hostname)

    allow(bitbucket.class).to receive(:user).and_return(user)
    allow(bitbucket.class).to receive(:api_key).and_return(SecureRandom.hex)
    allow(bitbucket.class).to receive(:site_url).and_return(site_url)
    allow(bitbucket.class).to receive(:api_endpoint).and_return(api_endpoint)
    allow(bitbucket.class).to receive(:remote_user).and_return(user)
    allow(bitbucket.class).to receive(:remote_repo).and_return(repo)
    allow(bitbucket.class).to receive(:oauth_token).and_return(oauth_token_hash.token)
    allow(bitbucket.class).to receive(:get_committed_time).and_return(Time.now)

    allow(GitReflow).to receive(:git_server).and_return(bitbucket)
  end

  xdescribe '.create(options)' do
  end

  xdescribe '.find_open(options)' do
  end

  xdescribe '#initialize(options)' do
  end

  xdescribe '#commit_author' do
  end

  xdescribe '#comments' do
  end

  xdescribe '#reviewers' do
  end

  xdescribe '#approvals' do
  end

  xdescribe '#last_comment' do
  end

end
