require 'git_reflow/sandbox'
require 'git_reflow/git_helpers'

module GitReflow
  module Workflow
    def self.included base
      base.extend ClassMethods
    end

    # @nodoc
    def self.current
      workflow_file = GitReflow::Config.get('reflow.workflow')
      if workflow_file.length > 0 and File.exists?(workflow_file)
        eval(File.read(workflow_file))
      else
        GitReflow::Workflows::Core
      end
    end

    module ClassMethods
      include GitReflow::GitHelpers
    end
  end
end

extend GitReflow::Workflow
