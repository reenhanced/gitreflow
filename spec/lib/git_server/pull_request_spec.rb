require 'spec_helper'

describe GitReflow::GitServer::GitHub::PullRequest do
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
      allow(subject).to receive(:build_status).and_return(nil)
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
      allow(subject).to receive(:build_status).and_return(nil)
      GitReflow.git_server.stub(:find_open_pull_request).with({from: 'new-external-feature', to: 'master'}).and_return(pull_request)
    end

    it "displays relavent information about the pull request" do
      subject
      $output.should include("branches: new-external-feature -> master")
      $output.should include("number: #{pull_request.number}")
      $output.should include("url: #{pull_request.html_url}")
      $output.should include("reviewed by: tito, ringo")
      $output.should include("Last comment: \":+1:\"")
    end
  end
end
