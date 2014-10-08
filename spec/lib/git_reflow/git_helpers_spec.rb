require 'spec_helper'

describe GitReflow::GitHelpers do
  let(:origin_url) { 'git@github.com:reenhanced.spectacular/this-is-the.shit.git' }

  before do
    stub_with_fallback(GitReflow::Config, :get).with('remote.origin.url').and_return(origin_url)

    module Gitacular
      include GitReflow::GitHelpers
      extend self
    end

    stub_run_for Gitacular
  end

  describe ".remote_user" do
    subject { Gitacular.remote_user }

    it { should == 'reenhanced.spectacular' }

    context "remote origin url isn't set" do
      let(:origin_url) { nil }
      it { should == '' }
    end
  end

  describe ".remote_repo_name" do
    subject { Gitacular.remote_repo_name }

    it { should == 'this-is-the.shit' }

    context "remote origin url isn't set" do
      let(:origin_url) { nil }
      it { should == '' }
    end
  end

  describe ".current_branch" do
    subject { Gitacular.current_branch }
    it      { expect{ subject }.to have_run_command_silently "git branch --no-color | grep '^\* ' | grep -v 'no branch' | sed 's/^* //g'" }
  end

  describe ".get_first_commit_message" do
    subject { Gitacular.get_first_commit_message }
    it      { expect{ subject }.to have_run_command_silently 'git log --pretty=format:"%s" --no-merges -n 1' }
  end

  describe ".push_current_branch" do
    subject { Gitacular.push_current_branch }
    before  { Gitacular.stub(:current_branch).and_return('bingo') }
    it      { expect{ subject }.to have_run_command "git push origin bingo" }
  end

  describe ".fetch_destination(destination_branch)" do
    subject { Gitacular.fetch_destination('new-feature') }
    it      { expect{ subject }.to have_run_command "git fetch origin new-feature" }
  end

  describe ".update_destination(destination_branch)" do
    let(:current_branch)     { 'bananas' }
    let(:destination_branch) { 'monkey-business' }

    before  { Gitacular.stub(:current_branch).and_return(current_branch) }
    subject { Gitacular.update_destination(destination_branch) }

    it "updates the destination branch with the latest code from the remote repo" do
      expect { subject }.to have_run_commands_in_order [
        "git checkout #{destination_branch}",
        "git pull origin #{destination_branch}",
        "git checkout #{current_branch}"
      ]
    end
  end

  describe ".merge_feature_branch(options)" do
    let(:destination_branch) { 'monkey-business' }
    let(:feature_branch)     { 'bananas' }
    let(:merge_options)      { {} }

    subject { Gitacular.merge_feature_branch(feature_branch, merge_options) }

    it 'checks out master as the default destination branch and squash merges the feature branch' do
      expect { subject }.to have_run_commands_in_order [
        'git checkout master',
        "git merge --squash #{feature_branch}"
      ]
    end

    context "providing a destination branch" do
      let(:merge_options) {{ destination_branch: destination_branch }}
      it { expect{ subject }.to have_run_command "git checkout #{destination_branch}" }
    end

    context "with a message" do
      let(:merge_options) {{ message: "don't throw doo doo" }}
      it "appends the message to the suqashed commit message" do
        Gitacular.should_receive(:append_to_squashed_commit_message).with("don't throw doo doo")
        subject
      end

      context 'and a pull reuqest number' do
        before { merge_options.merge!(pull_request_number: 3) }
        it "appends the message to the suqashed commit message" do
          Gitacular.should_receive(:append_to_squashed_commit_message).with("don't throw doo doo\nCloses #3\n")
          subject
        end
      end
    end

    context "with a pull request number" do
      let(:merge_options) {{ pull_request_number: 3 }}
      it "appends the message to the suqashed commit message" do
        Gitacular.should_receive(:append_to_squashed_commit_message).with("\nCloses #3\n")
        subject
      end
    end

    context "with one LGTM author" do
      let(:merge_options) {{ lgtm_authors: 'codenamev' }}
      it "appends the message to the suqashed commit message" do
        Gitacular.should_receive(:append_to_squashed_commit_message).with("\nLGTM given by: @#{merge_options[:lgtm_authors]}\n")
        subject
      end
    end

    context "with LGTM authors" do
      let(:merge_options) {{ lgtm_authors: ['codenamev', 'nhance'] }}
      it "appends the message to the suqashed commit message" do
        Gitacular.should_receive(:append_to_squashed_commit_message).with("\nLGTM given by: @#{merge_options[:lgtm_authors].join(', @')}\n")
        subject
      end
    end
  end

  describe ".append_to_squashed_commit_message(message)" do
    let(:message) { "do do the voodoo that you do" }
    subject { Gitacular.append_to_squashed_commit_message(message) }
    it "appends the message to git's SQUASH_MSG temp file" do
      expect{ subject }.to have_run_commands_in_order [
        "echo \"#{message}\" | cat - .git/SQUASH_MSG > ./tmp_squash_msg",
        'mv ./tmp_squash_msg .git/SQUASH_MSG'
      ]
    end
  end
end
