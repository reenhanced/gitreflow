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

  describe '.git_editor_command' do
    subject { Gitacular.git_editor_command }
    before { ENV['EDITOR'] = 'vim' }

    it 'defaults to GitReflow config' do
      allow(GitReflow::Config).to receive(:get).with('core.editor').and_return 'nano'

      expect(subject).to eq 'nano'
    end

    it 'falls back to the environment variable $EDITOR' do
      allow(GitReflow::Config).to receive(:get).with('core.editor').and_return ''

      expect(subject).to eq 'vim'
    end
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

  describe ".pull_request_template" do
    subject { Gitacular.pull_request_template }

    context "template file exists" do
      let(:root_dir) { "/some_repo" }
      let(:template_content) { "Template content" }

      before do
        allow(Gitacular).to receive(:git_root_dir).and_return(root_dir)
        allow(File).to receive(:exist?).with("#{root_dir}/.github/PULL_REQUEST_TEMPLATE.md").and_return(true)
        allow(File).to receive(:read).with("#{root_dir}/.github/PULL_REQUEST_TEMPLATE.md").and_return(template_content)
      end
      it { is_expected.to eq template_content }
    end

    context "template file does not exist" do
      before do
        allow(File).to receive(:exist?).and_return(false)
      end

      it { is_expected.to be_nil }
    end
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

  describe ".update_feature_branch" do
    options = {base: "base", remote: "remote"}
    subject { Gitacular.update_feature_branch(options) }
    before  { allow(Gitacular).to receive(:current_branch).and_return('feature') }

    it "calls the correct methods" do
      expect { subject }.to have_run_commands_in_order [
        "git checkout base",
        "git pull remote base",
        "git checkout feature",
        "git pull origin feature",
        "git merge base"
      ]
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
