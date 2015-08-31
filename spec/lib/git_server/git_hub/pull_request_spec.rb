require 'spec_helper'

describe GitReflow::GitServer::GitHub do
  let(:user)                    { 'reenhanced' }
  let(:password)                { 'shazam' }
  let(:repo)                    { 'repo' }
  let(:oauth_token_hash)        { Hashie::Mash.new({ token: 'a1b2c3d4e5f6g7h8i9j0'}) }
  let(:hostname)                { 'hostname.local' }
  let(:github_site)             { 'https://github.com' }
  let(:github_api_endpoint)     { 'https://api.github.com' }
  let(:enterprise_site)         { 'https://github.gittyup.com' }
  let(:enterprise_api)          { 'https://github.gittyup.com/api/v3' }
  let(:github)                  { stub_github_with }
  let!(:github_api)             { github.connection }
  let(:existing_pull_request)   { Fixture.new('pull_requests/external_pull_request.json').to_json_hashie }
  let(:existing_pull_requests)  { Fixture.new('pull_requests/pull_requests.json').to_json_hashie }
  let(:existing_pull_commits)   { Fixture.new('pull_requests/commits.json').to_json_hashie }
  let(:existing_pull_comments)  { Fixture.new('pull_requests/comments.json.erb', repo_owner: user, repo_name: repo, comment_author: 'octocat', pull_request_number: existing_pull_request.number).to_json_hashie }
  let(:existing_issue_comments) { Fixture.new('issues/comments.json.erb', repo_owner: user, repo_name: repo, comment_author: 'octocat').to_json_hashie }

  subject { GitReflow::GitServer::GitHub::PullRequest.new(existing_pull_request) }


  before do
    stub_command_line_inputs({
      "Please enter your GitHub username: "                                                 => user,
      "Please enter your GitHub password (we do NOT store this): "                          => password,
      "Please enter your Enterprise site URL (e.g. https://github.company.com):"            => enterprise_site,
      "Please enter your Enterprise API endpoint (e.g. https://github.company.com/api/v3):" => enterprise_api
    })

    github.class.stub(:remote_user).and_return(user)
    github.class.stub(:remote_repo_name).and_return(repo)
  end

  describe '#initialize(options)' do
    specify { expect(subject.number).to eql(existing_pull_request.number) }
    specify { expect(subject.description).to eql(existing_pull_request.body) }
    specify { expect(subject.html_url).to eql(existing_pull_request.html_url) }
    specify { expect(subject.feature_branch_name).to eql(existing_pull_request.head.label) }
    specify { expect(subject.base_branch_name).to eql(existing_pull_request.base.label) }
    specify { expect(subject.build_status).to eql(existing_pull_request.head.sha) }
    specify { expect(subject.source_object).to eql(existing_pull_request) }
  end

  describe '#commit_author' do
    specify { expect(subject.commit_author).to eql("#{existing_pull_commits.first.commit.author.name} <#{existing_pull_commits.first.commit.author.email}>") }
  end

  describe '#comments' do
    before do
      # Stubbing issue comments
      stub_get("/repos/#{user}/#{repo}/issues/#{existing_pull_request.number}/comments?").with(:query => {'access_token' => 'a1b2c3d4e5f6g7h8i9j0'}).
        to_return(:body => Fixture.new('issues/comments.json.erb', repo_owner: user, repo_name: repo, comment_author: user, pull_request_number: existing_pull_request.number).to_json.to_s, :status => 201, :headers => {:content_type => "application/json; charset=utf-8"})
      # Stubbing pull request commits
      stub_get("/repos/#{user}/#{repo}/pulls/#{existing_pull_request.number}/commits").with(query: {"access_token" => "a1b2c3d4e5f6g7h8i9j0"}).
        to_return(:body => Fixture.new("pull_requests/commits.json").to_s, status: 201, headers: {content_type: "application/json; charset=utf-8"})
    end

    specify { binding.pry;expect(subject.comments).to eql(existing_issue_comments.to_a + existing_pull_comments.to_a) }
  end

  describe '#reviewers' do
  end

  describe '#approvals' do
  end

  describe '#last_comment_for_pull_request' do
  end

  describe '#comments(pull_request)' do
  end

end
