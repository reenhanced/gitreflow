require 'spec_helper'

describe 'FlatMerge' do
  let(:workflow_path) { File.join(File.expand_path("../../../../../lib/git_reflow/workflows", __FILE__), "/flat_merge.rb") }
  let(:mergable_pr) { double(good_to_merge?: true, merge!: true) }
  let(:git_server)  { double(find_open_pull_request: mergable_pr) }

  before  do
    allow(GitReflow::Config).to receive(:get).and_call_original
    allow(GitReflow::Config).to receive(:get).with("reflow.workflow").and_return(workflow_path)
    allow(GitReflow).to receive(:git_server).and_return(git_server)
    allow(GitReflow).to receive(:status)
  end

  # Makes sure we are loading the right workflow
  specify { expect( GitReflow.workflow ).to eql(GitReflow::Workflow::FlatMerge) }

  context ".deliver" do
    subject { GitReflow.deliver }

    context "with Github" do
      let(:github_pr)   { Fixture.new('pull_requests/external_pull_request.json').to_json_hashie }
      let(:pr)          { GitReflow::GitServer::GitHub::PullRequest.new(github_pr) }
      let(:github)      { stub_github_with }
      let!(:github_api) { github.connection }

      before do
        allow_any_instance_of(GitReflow::GitServer::PullRequest).to receive(:deliver?).and_return(false)
        allow(GitReflow::Workflows::Core).to receive(:status)
        allow(GitReflow.git_server).to receive(:get_build_status).and_return(Struct.new(:state, :description, :url, :target_url).new)
        allow(GitReflow::GitServer::GitHub::PullRequest).to receive(:find_open).and_return(pr)
        allow(pr).to receive(:good_to_merge?).and_return(true)
      end

      it "overrides squash merge in favor of flat merge" do
        expect(pr).to receive(:merge!).with(base: 'master', squash: false, force: false, :"skip-lgtm" => false)
        subject
      end
    end

    context "when force-merging or with bitbucket" do
      let(:pr_response) { Fixture.new('pull_requests/external_pull_request.json').to_json_hashie }
      let(:pr)          { MockPullRequest.new(pr_response) }

      subject { GitReflow.deliver force: true}

      before do
        allow(GitReflow.git_server).to receive(:find_open_pull_request).and_return(pr)
        allow(pr).to receive(:good_to_merge?).and_return(true)
        allow(GitReflow::Workflows::Core).to receive(:status)
      end

      it "doesn't squash merge" do
        expect(pr).to receive(:merge!).with(base: 'master', squash: false, force: true, :"skip-lgtm" => false)
        subject
      end
    end
  end

end
