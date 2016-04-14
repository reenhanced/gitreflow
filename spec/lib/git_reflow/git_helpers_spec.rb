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

  describe ".git_root_dir" do
    subject { Gitacular.git_root_dir }
    it      { expect{ subject }.to have_run_command_silently "git rev-parse --show-toplevel" }
  end

  describe ".remote_user" do
    subject { Gitacular.remote_user }

    it { is_expected.to eq('reenhanced.spectacular') }

    context "remote origin url isn't set" do
      let(:origin_url) { nil }
      it { is_expected.to eq('') }
    end

    context "remote origin uses HTTP" do
      let(:origin_url) { 'https://github.com/reenhanced.spectacular/this-is-the.shit.git' }
      it               { is_expected.to eq('reenhanced.spectacular') }
    end
  end

  describe ".remote_repo_name" do
    subject { Gitacular.remote_repo_name }

    it { is_expected.to eq('this-is-the.shit') }

    context "remote origin url isn't set" do
      let(:origin_url) { nil }
      it { is_expected.to eq('') }
    end

    context "remote origin uses HTTP" do
      let(:origin_url) { 'https://github.com/reenhanced.spectacular/this-is-the.shit.git' }
      it               { is_expected.to eq('this-is-the.shit') }
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
    before  { allow(Gitacular).to receive(:current_branch).and_return('bingo') }
    it      { expect{ subject }.to have_run_command "git push origin bingo" }
  end

  describe ".fetch_destination(destination_branch)" do
    subject { Gitacular.fetch_destination('new-feature') }
    it      { expect{ subject }.to have_run_command "git fetch origin new-feature" }
  end

  describe ".update_destination(destination_branch)" do
    let(:current_branch)     { 'bananas' }
    let(:destination_branch) { 'monkey-business' }

    before  { allow(Gitacular).to receive(:current_branch).and_return(current_branch) }
    subject { Gitacular.update_destination(destination_branch) }

    it "updates the destination branch with the latest code from the remote repo" do
      expect { subject }.to have_run_commands_in_order [
        "git checkout #{destination_branch}",
        "git pull origin #{destination_branch}",
        "git checkout #{current_branch}"
      ]
    end
  end

  describe ".update_current_branch" do
    subject { Gitacular.update_current_branch }
    before  { allow(Gitacular).to receive(:current_branch).and_return('new-feature') }

    it "updates the remote changes and pushes any local changes" do
      expect { subject }.to have_run_commands_in_order [
        "git pull origin new-feature",
        "git push origin new-feature"
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
      it "appends the message to the squashed commit message" do
        expect(Gitacular).to receive(:append_to_squashed_commit_message).with("don't throw doo doo")
        subject
      end

      context 'and a pull reuqest number' do
        before { merge_options.merge!(pull_request_number: 3) }
        it "appends the message to the squashed commit message" do
          expect(Gitacular).to receive(:append_to_squashed_commit_message).with("don't throw doo doo\nCloses #3\n")
          subject
        end
      end
    end

    context "with a pull request number" do
      let(:merge_options) {{ pull_request_number: 3 }}
      it "appends the message to the squashed commit message" do
        expect(Gitacular).to receive(:append_to_squashed_commit_message).with("\nCloses #3\n")
        subject
      end
    end

    context "with one LGTM author" do
      let(:merge_options) {{ lgtm_authors: 'codenamev' }}
      it "appends the message to the squashed commit message" do
        expect(Gitacular).to receive(:append_to_squashed_commit_message).with("\nLGTM given by: @#{merge_options[:lgtm_authors]}\n")
        subject
      end
    end

    context "with LGTM authors" do
      let(:merge_options) {{ lgtm_authors: ['codenamev', 'nhance'] }}
      it "appends the message to the squashed commit message" do
        expect(Gitacular).to receive(:append_to_squashed_commit_message).with("\nLGTM given by: @#{merge_options[:lgtm_authors].join(', @')}\n")
        subject
      end
    end
  end

  describe ".append_to_squashed_commit_message(message)" do
    let(:original_squash_message) { "Oooooo, SQUASH IT" }
    let(:message)                 { "do do the voodoo that you do" }
    let(:root_dir)                { '/home/gitreflow' }
    let(:squash_path)             { "#{root_dir}/.git/SQUASH_MSG" }
    let(:tmp_squash_path)         { "#{root_dir}/.git/tmp_squash_msg" }
    before                        { allow(Gitacular).to receive(:git_root_dir).and_return(root_dir) }
    subject                       { Gitacular.append_to_squashed_commit_message(message) }

    it "appends the message to git's SQUASH_MSG temp file" do
      tmp_file = double('file')
      allow(File).to receive(:open).with(tmp_squash_path, "w").and_yield(tmp_file)
      allow(File).to receive(:exists?).with(squash_path).and_return(true)
      allow(File).to receive(:foreach).with(squash_path).and_yield(original_squash_message)
      expect(tmp_file).to receive(:puts).with(message)
      expect(tmp_file).to receive(:puts).with(original_squash_message)

      expect { subject }.to have_run_commands_in_order [
        "mv #{tmp_squash_path} #{squash_path}"
      ]
    end
  end
end
