require 'spec_helper'

describe GitReflow::Workflow do

  class DummyWorkflow
    include GitReflow::Workflow
  end

  class DummyBundler
    def gemfile(&block)
      instance_eval &block
    end

    def source(name); end
    def gem(name, *args); end
  end

  class DummyGemifiedWorkflow
    include GitReflow::Workflow

    command :whirl do
      puts "whirl"
    end
  end

  let(:workflow) { DummyWorkflow }
  let(:loader)   { double() }

  describe ".current" do
    subject { GitReflow::Workflow.current }

    before do
      allow(GitReflow::Workflows::Core).to receive(:load_raw_workflow)
    end

    context "when no workflow is set" do
      before  { allow(GitReflow::Config).to receive(:get).with("reflow.workflow").and_return('') }
      specify { expect( subject ).to eql(GitReflow::Workflows::Core) }
    end

    context "when a global workflow is set" do
      let(:workflow_path) { File.join(File.expand_path("../../../fixtures", __FILE__), "/awesome_workflow.rb") }

      before  { allow(GitReflow::Config).to receive(:get).with("reflow.workflow").and_return(workflow_path) }
      specify { expect( subject ).to eql(GitReflow::Workflows::Core) }
    end

    context "when a local workflow is set" do
      let(:workflow_content) do
        <<~WORKFLOW_CONTENT
          command :dummy do
            GitReflow.say "derp"
          end
        WORKFLOW_CONTENT
      end

      before do
        allow(File).to receive(:exists?).with("#{GitReflow.git_root_dir}/Workflow").and_return(true)
        allow(File).to receive(:read).with("#{GitReflow.git_root_dir}/Workflow").and_return(workflow_content)
        expect(GitReflow::Workflows::Core).to receive(:load_raw_workflow).with(workflow_content).and_call_original
      end

      specify { expect( subject ).to respond_to(:dummy) }
      specify { expect( subject ).to eql(GitReflow::Workflows::Core) }
    end

    context "when both a local and a global workflow are set" do
      let(:workflow_path) { File.join(File.expand_path("../../../fixtures", __FILE__), "/awesome_workflow.rb") }
      let(:workflow_content) do
        <<~WORKFLOW_CONTENT
          command :dummy do
            GitReflow.say "derp"
          end
        WORKFLOW_CONTENT
      end

      before  do
        allow(File).to receive(:exists?).with("#{GitReflow.git_root_dir}/Workflow").and_return(true)
        allow(File).to receive(:read).with("#{GitReflow.git_root_dir}/Workflow").and_return(workflow_content)
        allow(GitReflow::Config).to receive(:get).with("reflow.workflow").and_return(workflow_path)
        allow(GitReflow::Workflows::Core).to receive(:load_raw_workflow).and_call_original
      end

      specify { expect(subject).to respond_to(:dummy) }
      specify { expect(subject).to eql(GitReflow::Workflows::Core) }
    end
  end

  describe ".before" do
    it "executes the block before the command" do
      GitReflow::Workflows::Core.load_raw_workflow <<~WORKFLOW_CONTENT
        command :yips do
          puts "Yips."
        end

        before :yips do
          puts "Would you like a donut?"
        end
      WORKFLOW_CONTENT

      allow(GitReflow::Workflows::Core).to receive(:load_workflow).and_return(true)

      expect { GitReflow.workflow.yips }.to have_output "Would you like a donut?\nYips."
    end

    it "executes blocks sequentially by order of appearance" do
      GitReflow::Workflows::Core.load_raw_workflow <<~WORKFLOW_CONTENT
        command :yips do
          puts "Yips."
        end

        before :yips do
          puts "Cupcake?"
        end

        before :yips do
          puts "Would you like a donut?"
        end
      WORKFLOW_CONTENT

      allow(GitReflow::Workflows::Core).to receive(:load_workflow).and_return(true)

      expect { GitReflow.workflow.yips }.to have_output "Cupcake?\nWould you like a donut?\nYips."
    end

    it "proxies any arguments returned to the command" do
      GitReflow::Workflows::Core.load_raw_workflow <<~WORKFLOW_CONTENT
        command :yips, arguments: { spiced: false } do |**params|
          puts params[:spiced] ? "Too spicy." : "Yips."
        end

        before :yips do
          puts "Wasabe?"
          { spiced: true }
        end
      WORKFLOW_CONTENT

      allow(GitReflow::Workflows::Core).to receive(:load_workflow).and_return(true)

      expect { GitReflow.workflow.yips }.to have_output "Wasabe?\nToo spicy."
    end
  end

  describe ".after" do
    it "executes the block after the command" do
      GitReflow::Workflows::Core.load_raw_workflow <<~WORKFLOW_CONTENT
        command :vroom do
          puts "Vroom"
        end

        after :vroom do
          puts "VROOOOM"
        end
      WORKFLOW_CONTENT

      allow(GitReflow::Workflows::Core).to receive(:load_workflow).and_return(true)

      expect { GitReflow.workflow.vroom }.to have_output "Vroom\nVROOOOM"
    end

    it "executes blocks sequentially by order of appearance" do
      GitReflow::Workflows::Core.load_raw_workflow <<~WORKFLOW_CONTENT
        command :vroom do
          puts "Vroom"
        end

        after :vroom do
          puts "Vrooom"
        end

        after :vroom do
          puts "VROOOOM"
        end
      WORKFLOW_CONTENT

      allow(GitReflow::Workflows::Core).to receive(:load_workflow).and_return(true)

      expect { GitReflow.workflow.vroom }.to have_output "Vroom\nVrooom\nVROOOOM"
    end
  end

  describe ".command" do
    it "creates a class method for a bogus command" do
      workflow.command :bogus do
        GitReflow.say "Woohoo"
      end

      expect { DummyWorkflow.bogus }.to have_said("Woohoo")
    end

    it "creates a method for a bogus command with arguments" do
      workflow.command :bogus, arguments: { feature_branch: nil } do |**params|
        GitReflow.say "Woohoo #{params[:feature_branch]}!"
      end

      expect { DummyWorkflow.bogus(feature_branch: "arguments") }.to have_said("Woohoo arguments!")
    end

    it "creates a class method for a bogus command with default arguments" do
      workflow.command :bogus, arguments: { feature_branch: nil, decoration: "sprinkles" } do |**params|
        donut_excitement = "Woohoo #{params[:feature_branch]}"
        donut_excitement += " with #{params[:decoration]}" if params[:decoration]
        GitReflow.say "#{donut_excitement}!"
      end

      expect { DummyWorkflow.bogus(feature_branch: "donuts") }.to have_said("Woohoo donuts with sprinkles!")
    end

    it "creates a class method for a bogus command with flags" do
      workflow.command :bogus, flags: { feature_branch: nil } do |**params|
        GitReflow.say "Woohoo #{params[:feature_branch]}!"
      end

      expect { DummyWorkflow.bogus(feature_branch: "flags") }.to have_said("Woohoo flags!")
    end

    it "creates a class method for a bogus command with default flags" do
      workflow.command :bogus, flags: { feature_branch: "donuts" } do |**params|
        GitReflow.say "Woohoo #{params[:feature_branch]}!"
      end

      expect { DummyWorkflow.bogus }.to have_said("Woohoo donuts!")
    end

    it "creates a class method for a bogus command with switches" do
      workflow.command :bogus, switches: { feature_branch: nil } do |**params|
        GitReflow.say "Woohoo #{params[:feature_branch]}!"
      end

      expect { DummyWorkflow.bogus(feature_branch: "switches") }.to have_said("Woohoo switches!")
    end

    it "creates a class method for a bogus command with default switches" do
      workflow.command :bogus, switches: { feature_branch: "donuts" } do |**params|
        GitReflow.say "Woohoo #{params[:feature_branch]}!"
      end

      expect { DummyWorkflow.bogus }.to have_said("Woohoo donuts!")
    end
  end

  describe ".use(workflow_name)" do
    it "Uses a pre-existing workflow as a basis" do
      allow(GitReflow::Workflows::Core).to receive(:load_workflow)
      expect(GitReflow::Workflows::Core).to receive(:load_workflow)
        .with(workflow.workflows["FlatMergeWorkflow"])
        .and_return(true)
      workflow.use "FlatMergeWorkflow"
    end
  end

  describe ".use_gem(name, *ags)" do
    let(:mock_bundler) { DummyBundler.new }

    before do
      allow(DummyGemifiedWorkflow).to receive(:gemfile) do |&block|
        mock_bundler.gemfile(&block)
      end
      stub_run_for(DummyGemifiedWorkflow)
    end

    it "Installs a gem using Bundler's inline gemfile" do
      stub_command(command: "gem list -ie whirly", options: { loud: false, raise: true }, return_value: "false")
      expect(mock_bundler).to receive(:source).with("https://rubygems.org")
      expect(mock_bundler).to receive(:gem).with("whirly", "0.2.6")

      DummyGemifiedWorkflow.class_eval do
        use_gem "whirly", "0.2.6"
      end
    end

    it "Uses an existing gem if it's already installed" do
      stub_command(command: "gem list -ie whirly", options: { loud: false, raise: false }, return_value: "true")
      expect(DummyGemifiedWorkflow).to_not receive(:gemfile)

      DummyGemifiedWorkflow.class_eval do
        use_gem "whirly", "0.2.6"
      end
    end
  end

  describe ".use_gemfile(&block)" do
    let(:mock_bundler) { DummyBundler.new }

    before do
      allow(DummyGemifiedWorkflow).to receive(:gemfile) do |&block|
        mock_bundler.gemfile(&block)
      end
      stub_run_for(DummyGemifiedWorkflow)
    end

    it "runs bundler's inline gemfile with the provided block" do
      expect(mock_bundler).to receive(:source).with("https://rubygems.org")
      expect(mock_bundler).to receive(:gem).with("standard")

      DummyGemifiedWorkflow.class_eval do
        use_gemfile do
          source "https://rubygems.org"
          gem "standard"
        end
      end
    end
  end
end
