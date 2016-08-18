require 'spec_helper'

describe GitReflow::Workflow do

  class DummyWorkflow
    include GitReflow::Workflow
  end

  let(:workflow) { DummyWorkflow }
  let(:loader)   { double() }

  describe ".current" do
    subject { GitReflow::Workflow.current }

    before do
      allow(GitReflow::Workflow).to receive(:load).and_return(loader)
    end

    context "when no workflow has been set" do
      before  { allow(GitReflow::Config).to receive(:get).with("reflow.workflow").and_return('') }
      specify { expect( subject ).to eql(GitReflow::Workflows::Core) }
    end
  end

  describe ".command" do
    it "creates a class method for a bogus command" do
      class DummyWorkflow
        include GitReflow::Workflow
      end
      workflow.command :bogus do
        "Woohoo"
      end

      expect(DummyWorkflow.bogus).to eql("Woohoo")
    end

    it "creates a method for a bogus command with arguments" do
      workflow.command :bogus, arguments: [:feature_branch] do |**params|
        "Woohoo #{params[:feature_branch]}!"
      end

      expect(DummyWorkflow.bogus(feature_branch: "donuts")).to eql("Woohoo donuts!")
    end

    it "creates a class method for a bogus command with default options" do
      workflow.command :bogus, arguments: [:feature_branch], defaults: {decoration: 'sprinkles'} do |**params|
        donut_excitement = "Woohoo #{params[:feature_branch]}"
        donut_excitement += " with #{params[:decoration]}" if params[:decoration]
        "#{donut_excitement}!"
      end

      expect(DummyWorkflow.bogus(feature_branch: "donuts")).to eql("Woohoo donuts with sprinkles!")
    end
  end

end
