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
      include GitReflow::Sandbox
      include GitReflow::GitHelpers

      # Creates a singleton method on the inlcuded class
      #
      # This method will take any number of keyword parameters. If @defaults keyword is provided, and the given
      # key(s) in the defaults are not provided as keyword parameters, then it will use the value given in the
      # defaults for that parameter.
      #
      # @param name [Symbol] the name of the method to create
      # @param defaults [Hash] keyword arguments to provide fallbacks for
      #
      # @yield [a:, b:, c:, ...] Invokes the block with an arbitrary number of keyword arguments
      def command(name, **params, &block)
        defaults = params[:defaults] || {}
        self.define_singleton_method(name) do |**args|
          args_with_defaults = {}
          args.each do |name, value|
            if "#{value}".length <= 0
              args_with_defaults[name] = defaults[name]
            else
              args_with_defaults[name] = value
            end
          end

          defaults.each do |name, value|
            if "#{args_with_defaults[name]}".length <= 0
              args_with_defaults[name] = value
            end
          end

          block.call(**args_with_defaults)
        end
      end
    end
  end
end

extend GitReflow::Workflow
