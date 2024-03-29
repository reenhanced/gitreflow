require 'spec_helper'

describe GitReflow do
  describe ".logger" do
    # Ignore memoization for tests
    before { GitReflow.instance_variable_set("@logger", nil) }

    it "initializes a new logger" do
      expect(GitReflow::Logger).to receive(:new)
      described_class.logger
    end

    it "allows for custom loggers" do
      logger = described_class.logger("kenny-loggins.log")
      expect(logger.instance_variable_get("@logdev").dev.path).to eq "kenny-loggins.log"
    end
  end

  describe ".git_server" do
    subject { GitReflow.git_server }

    before do
      allow(GitReflow::Config).to receive(:get)
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

    context "when a workflow is set" do
      it "calls the defined workflow methods instead of the default core" do
        workflow_path = File.join(File.expand_path("../../fixtures", __FILE__), "/awesome_workflow.rb")
        allow(GitReflow::Config).to receive(:get).with("reflow.workflow").and_return(workflow_path)
        allow(GitReflow::Workflows::Core).to receive(:load_raw_workflow)
        expect(GitReflow::Workflows::Core).to receive(:load_raw_workflow).with(File.read(workflow_path)).and_call_original

        expect{ subject.start }.to have_said "Awesome."
      end
    end

  end
end
