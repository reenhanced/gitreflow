require 'spec_helper'

describe GitReflow::GitServer::GitHub::PullRequest do
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
  let(:comment_author)          { 'octocat' }
  let(:existing_pull_comments)  {
    Fixture.new('pull_requests/comments.json.erb',
                repo_owner: user,
                repo_name: repo,
                comments: [{author: comment_author}],
                pull_request_number: existing_pull_request.number).to_json_hashie }
  let(:existing_issue_comments) {
    Fixture.new('issues/comments.json.erb',
                repo_owner: user,
                repo_name: repo,
                comments: [{author: comment_author}],
                pull_request_number: existing_pull_request.number).to_json_hashie }

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
    specify { expect(subject.build_status).to eql('success') }
    specify { expect(subject.source_object).to eql(existing_pull_request) }
  end

  describe '#commit_author' do
    before do
      stub_request(:get, %r{#{GitReflow.git_server.class.api_endpoint}/repos/#{user}/#{repo}/pulls/#{existing_pull_request.number}/commits}).
        with(query: {"access_token" => "a1b2c3d4e5f6g7h8i9j0"}).
        to_return(:body => Fixture.new("pull_requests/commits.json").to_s, status: 201, headers: {content_type: "application/json; charset=utf-8"})
    end
    specify { expect(subject.commit_author).to eql("#{existing_pull_commits.first.commit.author.name} <#{existing_pull_commits.first.commit.author.email}>") }
  end

  describe '#comments' do
    before do
      FakeGitHub.new(
        repo_owner: user,
        repo_name: repo,
        pull_request: {
          number: existing_pull_request.number,
          comments: [{author: comment_author}]
        },
        issue: {
          number: existing_pull_request.number,
          comments: [{author: comment_author}]
        })
    end

    specify { expect(subject.comments).to eql(existing_pull_comments.to_a + existing_issue_comments.to_a) }
  end

  describe '#reviewers' do
    before do
      allow(existing_pull_request.head.user).to receive(:login).and_return('ringo')

      FakeGitHub.new(
        repo_owner: user,
        repo_name: repo,
        pull_request: {
          number: existing_pull_request.number,
          owner: existing_pull_request.head.user.login,
          comments: [{author: 'tito'}, {author: 'bobby'}, {author: 'ringo'}]
        },
        issue: {
          number: existing_pull_request.number,
          comments: [{author: 'ringo'}, {author: 'randy'}]
        })
    end

    specify { expect(subject.reviewers).to eql(['tito', 'bobby', 'randy']) }
  end

  describe '#approvals' do
    context "no comments" do
      before do
        FakeGitHub.new(
          repo_owner: user,
          repo_name: repo,
          pull_request: {
            number: existing_pull_request.number,
            owner: existing_pull_request.head.user.login,
            comments: []
          })
      end

      specify { expect(subject.approvals).to eq([]) }
    end

    context "single reviewer without approval" do
      before do
        FakeGitHub.new(
          repo_owner: user,
          repo_name: repo,
          pull_request: {
            number: existing_pull_request.number,
            owner: existing_pull_request.head.user.login,
            comments: [{author: 'tito', body: 'This is some funky stuff'}]
          })
      end

      specify { expect(subject.approvals).to eq([]) }
    end

    context "single reviewer with approval" do
      before do
        FakeGitHub.new(
          repo_owner:   user,
          repo_name:    repo,
          pull_request: {
            number:   existing_pull_request.number,
            owner:    existing_pull_request.head.user.login,
            comments: [{author: 'tito', body: 'LGTM'}]
          })
      end

      specify { expect(subject.approvals).to eq(['tito']) }

      context "but a new commit has been introduced" do
        before do
          FakeGitHub.new(
            repo_owner:   user,
            repo_name:    repo,
            commits: [
              {
                author: user,
                pull_request_number: existing_pull_request.number,
                created_at: Chronic.parse("1 second ago")
              }
            ],
            pull_request: {
              number:   existing_pull_request.number,
              owner:    existing_pull_request.head.user.login,
              comments: [{author: 'tito', body: 'LGTM', created_at: Chronic.parse('1 minute ago')}]
            })
        end

        specify { expect(subject.approvals).to eq([]) }
      end
    end

    context "multiple reviewers with only one approval" do
      before do
        FakeGitHub.new(
          repo_owner:   user,
          repo_name:    repo,
          pull_request: {
            number:   existing_pull_request.number,
            owner:    existing_pull_request.head.user.login,
            comments: [{author: 'tito', body: 'LGTM'}, {author: 'ringo', body: 'Needs more cowbell.'}]
          })
      end

      specify { expect(subject.approvals).to eq(['tito']) }
    end

    context "multiple reviewers with all approvals" do
      before do
        FakeGitHub.new(
          repo_owner:   user,
          repo_name:    repo,
          pull_request: {
            number:   existing_pull_request.number,
            owner:    existing_pull_request.head.user.login,
            comments: [{author: 'tito', body: 'lgtm'}, {author: 'ringo', body: ':+1:'}]
          })
      end

      specify { expect(subject.approvals).to eq(['tito', 'ringo']) }

      context "but a new commit has been introduced" do
        before do
          FakeGitHub.new(
            repo_owner:   user,
            repo_name:    repo,
            commits: [
              {
                author:              user,
                pull_request_number: existing_pull_request.number,
                created_at:          Chronic.parse("1 second ago")
              }
            ],
            pull_request: {
              number:   existing_pull_request.number,
              owner:    existing_pull_request.head.user.login,
              comments: [{author: 'tito', body: 'lgtm', created_at: Chronic.parse('1 minute ago')}, {author: 'ringo', body: ':+1:', created_at: Chronic.parse('1 minute ago')}]
            })
        end

        specify { expect(subject.approvals).to eq([]) }
      end
    end

  end

  describe '#last_comment' do
      before do
        FakeGitHub.new(
          repo_owner:   user,
          repo_name:    repo,
          pull_request: {
            number:   existing_pull_request.number,
            owner:    existing_pull_request.head.user.login,
            comments: [{author: 'tito', body: 'lgtm'}, {author: 'ringo', body: 'Cha cha cha'}]
          })
      end

      specify { expect(subject.last_comment).to eq('"Cha cha cha"') }
  end

  describe '#build' do
    let(:build) { Fixture.new('repositories/statuses.json').to_json_hashie.first }

    context "with an existing build" do
      specify { expect(subject.build.state).to eq(build.state) }
      specify { expect(subject.build.description).to eq(build.description) }
      specify { expect(subject.build.url).to eq(build.target_url) }
    end

    context "no build found" do
      before  { allow(GitReflow.git_server).to receive(:get_build_status).and_return(nil) }
      specify { expect(subject.build.state).to eq(nil) }
      specify { expect(subject.build.description).to eq(nil) }
      specify { expect(subject.build.url).to eq(nil) }
    end
  end


  describe '.create(options)' do
    let(:title) { 'Bone Saw is ready!' }
    let(:body)  { 'Snap into a Slim Jim!' }
    let(:base_branch_name) { 'base-branch' }
    let(:pull_request_response) do
      Fixture.new('pull_requests/pull_request.json.erb',
                  number:      2,
                  title:       title,
                  body:        body,
                  base_branch: base_branch_name,
                  repo_owner:  user,
                  repo_name:   repo)
    end

    subject { GitReflow::GitServer::GitHub::PullRequest.create(title: title, body: body, base: base_branch_name) }

    before do
      stub_request(:post, %r{/repos/#{user}/#{repo}/pulls}).
        to_return(body: pull_request_response.to_s, status: 201, headers: {content_type: "application/json; charset=utf-8"})
    end

    specify { expect(subject.class.to_s).to eql('GitReflow::GitServer::GitHub::PullRequest') }
    specify { expect(subject.title).to eql(title) }
    specify { expect(subject.description).to eql(body) }
    specify { expect(subject.base_branch_name).to eql(base_branch_name) }
  end

  describe '.find_open(options)' do
    let(:feature_branch) { 'new-feature' }
    let(:base_branch)    { 'base-branch' }

    subject { GitReflow::GitServer::GitHub::PullRequest.find_open(from: feature_branch, to: base_branch) }

    before do
      allow(GitReflow.git_server.class).to receive(:current_branch).and_return(feature_branch)
      FakeGitHub.new(
        repo_owner:   user,
        repo_name:    repo,
        pull_request: {
          number:   existing_pull_request.number,
          owner:    existing_pull_request.head.user.login,
          base_branch: base_branch,
          feature_branch: feature_branch
        })
    end

    specify { expect(subject.class.to_s).to eql('GitReflow::GitServer::GitHub::PullRequest') }
    specify { expect(subject.number).to eql(existing_pull_request.number) }

    context "without any options" do
      let(:base_branch) { 'master' }
      subject           { GitReflow::GitServer::GitHub::PullRequest.find_open() }
      it "defaults to the current branch as the feature branch and 'master' as the base branch" do
        expect(subject.class.to_s).to eql('GitReflow::GitServer::GitHub::PullRequest')
        expect(subject.number).to eql(existing_pull_request.number)
      end
    end
  end

end
