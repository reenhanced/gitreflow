require 'spec_helper'

describe GitReflow::GitServer::GitHub::PullRequest do
  let(:github)      { stub_github_with }
  let!(:github_api) { github.connection }

  describe "#good_to_merge?(options)" do
    let(:pull_request) { Fixture.new('pull_requests/external_pull_request.json').to_json_hashie }
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
      allow(GitReflow.git_server).to receive(:get_build_status).and_return(nil)
    end

    specify { expect(subject.good_to_merge?).to eq(true) }

    context "with build status" do
      context "of 'success'" do
        before { allow(GitReflow.git_server).to receive(:get_build_status).and_return('success') }
        specify { expect(subject.good_to_merge?).to eq(true) }
      end

      context "NOT of 'success'" do
        before { allow(GitReflow.git_server).to receive(:get_build_status).and_return('failure') }
        specify { expect(subject.good_to_merge?).to eq(false) }
      end
    end

    context "with no comments" do
      before { allow(pull_request).to receive(:has_comments?).and_return(false) }
      specify { expect(subject.good_to_merge?(force: true)).to eq(false) }
    end

    context "with comments but no approvals" do
      before { allow(pull_request).to receive(:approvals).and_return([]) }
      specify { expect(subject.good_to_merge?(force: true)).to eq(false) }
    end

    context "force merge?" do
      context "with pending comments" do
        before { allow(pull_request).to receive(:approvals).and_return([]) }
        specify { expect(subject.good_to_merge?(force: true)).to eq(true) }
      end

      context "with build failure" do
        before { allow(GitReflow.git_server).to receive(:get_build_status).and_return('failure') }
        specify { expect(subject.good_to_merge?(force: true)).to eq(true) }
      end
    end
  end

end
