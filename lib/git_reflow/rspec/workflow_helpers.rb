module GitReflow
  module RSpec
    # @nodoc
    module WorkflowHelpers
      def suppress_loading_of_external_workflows
        allow(File).to receive(:exists?).and_call_original
        allow(File).to receive(:exists?).with("#{GitReflow.git_root_dir}/Workflow").and_return(false)
        if "#{GitReflow::Config.get('reflow.workflow')}".length > 0
          allow(File).to receive(:exists?).with(GitReflow::Config.get('reflow.workflow')).and_return(false)
        end
      end
    end
  end
end
