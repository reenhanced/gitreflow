require 'spec_helper'

describe 'RebaseFlatMerge' do
  let(:workflow_path) { File.join(File.expand_path("../../../../../lib/git_reflow/workflows", __FILE__), "/rebase_flat_merge.rb") }
  let(:mergable_pr) { double(good_to_merge?: true, merge!: true) }
  let(:git_server)  { double(find_open_pull_request: mergable_pr) }

  before  do
    allow(GitReflow::Config).to receive(:get).and_return('')
    allow(GitReflow::Config).to receive(:get).with("reflow.workflow").and_return(workflow_path)
    allow(GitReflow).to receive(:git_server).and_return(git_server)
    allow(GitReflow).to receive(:status)
  end

  # Makes sure we are loading the right workflow
  specify { expect( GitReflow.workflow ).to eql(GitReflow::Workflow::RebaseFlatMerge) }

  context ".deliver" do
    subject { GitReflow.deliver }

    context "with more than a single commit of changes" do
      before { allow(GitReflow).to receive(:current_branch_commit_count).with(base: 'master').and_return(2) }

      it "rebases off of the base branch if there is more than 1 commit" do
        expect { subject }.to have_said "Rebasing to cleanup your commit history for this branch.", :notice
        expect { subject }.to have_said "Once you have completed your rebase, re-run git-reflow deliver.", :notice
        expect { subject }.to have_run_commands_in_order [
          "git fetch origin master",
          "git rebase -i origin/master"
        ]
      end
    end

    context "with only a signle commit of changes" do
      before do
        allow(GitReflow).to receive(:current_branch_commit_count).with(base: 'master').and_return(1)
        allow(GitReflow::Workflows::Core).to receive(:status)
      end

      it "Merges the PR" do
        expect(mergable_pr).to receive(:merge!)
        expect { subject }.to_not have_said "Rebasing to cleanup your commit history for this branch.", :notice
        expect { subject }.to_not have_said "Once you have completed your rebase, re-run git-reflow deliver.", :notice
        subject
      end
    end
  end

end
