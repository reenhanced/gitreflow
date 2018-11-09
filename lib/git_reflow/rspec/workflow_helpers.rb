module GitReflow
  module RSpec
    # @nodoc
    module WorkflowHelpers
      def use_workflow(path)
        allow(GitReflow::Workflows::Core).to receive(:load_workflow).and_return(
          GitReflow::Workflows::Core.load_raw_workflow(File.read(path))
        )
      end

      def suppress_loading_of_external_workflows
        allow(File).to receive(:exists?).and_call_original
        allow(File).to receive(:exists?).with("#{GitReflow.git_root_dir}/Workflow").and_return(false)
        return if GitReflow::Config.get('reflow.workflow').to_s.empty?
        allow(File).to receive(:exists?).with(GitReflow::Config.get('reflow.workflow')).and_return(false)
      end
    end
  end
end
