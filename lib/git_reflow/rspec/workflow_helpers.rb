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
        allow(GitReflow::Workflows::Core).to receive(:load__workflow).with("#{GitReflow.git_root_dir}/Workflow").and_return(false)
        return if GitReflow::Config.get('reflow.workflow').to_s.empty?
        allow(GitReflow::Workflows::Core).to receive(:load_workflow).with(GitReflow::Config.get('reflow.workflow')).and_return(false)
      end
    end
  end
end
