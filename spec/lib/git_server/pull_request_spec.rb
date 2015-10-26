require 'spec_helper'

describe GitReflow::GitServer::PullRequest do
  let(:pull_request) { Fixture.new('pull_requests/external_pull_request.json').to_json_hashie }
  let(:github)      { stub_github_with({ user: 'reenhanced', repo: 'repo', pull: pull_request }) }
  let!(:github_api) { github.connection }

  describe "#good_to_merge?(options)" do
    subject            { GitReflow::GitServer::GitHub::PullRequest.new(pull_request) }

    before do
      FakeGitHub.new(
        repo_owner:   'reenhanced',
        repo_name:    'repo',
        pull_request: {
          number:   pull_request.number,
          owner:    pull_request.head.user.login,
          comments: [{author: 'tito', body: 'lgtm'}, {author: 'ringo', body: ':+1:'}]
        })
      # setup initial valid state
      allow_any_instance_of(GitReflow::GitServer::GitHub::PullRequest).to receive(:build).and_return(Struct.new(:state, :description, :url).new)
      GitReflow.git_server.stub(:find_open_pull_request).with({from: 'new-feature', to: 'master'}).and_return(pull_request)
    end

    specify { expect(subject.good_to_merge?).to eq(true) }

    context "with build status" do
      context "of 'success'" do
        before  { allow(subject).to receive(:build_status).and_return('success') }
        specify { expect(subject.good_to_merge?).to eq(true) }
      end

      context "NOT of 'success'" do
        before { allow(subject).to receive(:build_status).and_return('failure') }
        specify { expect(subject.good_to_merge?).to eq(false) }
      end
    end

    context "with no comments" do
      before { allow(subject).to receive(:has_comments?).and_return(false) }
      specify { expect(subject.good_to_merge?).to eq(true) }
      context "and no approvals" do
        before { allow(subject).to receive(:approvals?).and_return([]) }
        specify { expect(subject.good_to_merge?).to eq(true) }
      end
    end

    context "with comments" do
      before do
        allow(subject).to receive(:reviewers).and_return(['bob'])
        allow(subject).to receive(:approvals).and_return([])
      end
      specify { expect(subject.good_to_merge?).to eq(false) }
    end

    context "force merge?" do
      context "with pending comments" do
        before { allow(subject).to receive(:approvals).and_return([]) }
        specify { expect(subject.good_to_merge?(force: true)).to eq(true) }
      end

      context "with build failure" do
        before { allow(subject).to receive(:build_status).and_return('failure') }
        specify { expect(subject.good_to_merge?(force: true)).to eq(true) }
      end
    end
  end

  describe "#display_pull_request_summary" do
    subject            { GitReflow::GitServer::GitHub::PullRequest.new(pull_request).display_pull_request_summary }

    before do
      FakeGitHub.new(
        repo_owner:   'reenhanced',
        repo_name:    'repo',
        pull_request: {
          number:   pull_request.number,
          owner:    pull_request.head.user.login,
          comments: [{author: 'tito', body: 'lgtm'}, {author: 'ringo', body: ':+1:'}]
        })
      allow_any_instance_of(GitReflow::GitServer::GitHub::PullRequest).to receive(:build).and_return(Struct.new(:state, :description, :url).new)
      GitReflow.git_server.stub(:find_open_pull_request).with({from: 'new-external-feature', to: 'master'}).and_return(pull_request)
    end

    it "displays relavent information about the pull request" do
      expect{ subject }.to have_output("branches: new-external-feature -> reenhanced:master")
      expect{ subject }.to have_output("number: #{pull_request.number}")
      expect{ subject }.to have_output("url: #{pull_request.html_url}")
      expect{ subject }.to have_output("reviewed by: #{"tito".colorize(:green)}, #{"ringo".colorize(:green)}")
      expect{ subject }.to have_output("Last comment: \":+1:\"")
    end
  end
end
