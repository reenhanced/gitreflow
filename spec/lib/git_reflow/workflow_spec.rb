require 'spec_helper'

describe GitReflow::Workflow do

  class DummyWorkflow
    include GitReflow::Workflow
  end

  let(:workflow) { DummyWorkflow }
  let(:loader)   { double() }

  describe ".current" do
    subject { GitReflow::Workflow.current }

    context "when no workflow is set" do
      before  { allow(GitReflow::Config).to receive(:get).with("reflow.workflow").and_return('') }
      specify { expect( subject ).to eql(GitReflow::Workflows::Core) }
    end

    context "when a workflow is set" do
      let(:workflow_path) { File.join(File.expand_path("../../../fixtures", __FILE__), "/awesome_workflow.rb") }

      before  { allow(GitReflow::Config).to receive(:get).with("reflow.workflow").and_return(workflow_path) }
      specify { expect( subject ).to eql(GitReflow::Workflow::AwesomeWorkflow) }
    end
  end

end
