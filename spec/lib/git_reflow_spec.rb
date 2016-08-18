require 'spec_helper'

describe GitReflow do

  describe ".default_editor" do
    subject { GitReflow.default_editor }

    context "when the environment has EDITOR set" do
      before  { allow(ENV).to receive(:[]).with('EDITOR').and_return('emacs') }
      specify { expect( subject ).to eql('emacs') }
    end

    context "when the environment has no EDITOR set" do
      before  { allow(ENV).to receive(:[]).with('EDITOR').and_return(nil) }
      specify { expect( subject ).to eql('vi') }
    end
  end

  describe ".git_server" do
    subject { GitReflow.git_server }

    before do
      allow(GitReflow::Config).to receive(:get).with('reflow.git-server').and_return('GitHub ')
    end

    it "attempts to connect to the provider" do
      expect(GitReflow::GitServer).to receive(:connect).with(provider: 'GitHub', silent: true)
      subject
    end
  end

  context "aliases workflow commands" do
    %w{deliver refresh review setup stage start status}.each do |command|
      it "aliases the command to the workflow" do
        expect( subject.respond_to?(command.to_sym) ).to be_truthy
      end
    end
  end
end
