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
        GitReflow.logger.debug "Using workflow: #{workflow_file}"
        eval(File.read(workflow_file))
      else
        GitReflow.logger.debug "Using core workflow..."
        GitReflow::Workflows::Core
      end
    end

    module ClassMethods
      include GitReflow::Sandbox
      include GitReflow::GitHelpers

      def commands
        @@commands ||= {}
      end

      def command_docs
        @@command_docs ||= {}
      end

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
      #
      # Needs to support :flags, :switches, :arguments
      def command(name, **params, &block)
        params[:flags]     ||= {}
        params[:switches]  ||= {}
        params[:arguments] ||= {}
        defaults           ||= params[:arguments].merge(params[:flags]).merge(params[:switches])

        # Register the command with the workflow so that we can properly handle
        # option parsing from the command line
        self.commands[name] = params
        self.command_docs[name] = params

        self.define_singleton_method(name) do |**args|
          args_with_defaults = {}
          args.each do |name, value|
            if "#{value}".length <= 0 && !defaults[name].nil?
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

      # Creates a singleton method on the inlcuded class
      #
      # This method updates the help text associated with the provided command.
      #
      # @param name [Symbol] the name of the command to add/update help text for
      # @param defaults [Hash] keyword arguments to provide fallbacks for
      def command_help(name, summary:, arguments: {}, flags: {}, switches: {},  description: "")
        command_docs[name] = {
          summary: summary,
          description: description,
          arguments: arguments,
          flags: flags,
          switches: switches
        }
      end

      # Outputs documentation for the provided command
      #
      # @param name [Symbol] the name of the command to output help text for
      def documentation_for_command(name)
        name = name.to_sym
        docs = command_docs[name]
        if !docs.nil?
          GitReflow.say "USAGE"
          GitReflow.say "    git-reflow #{name} [command options] #{docs[:arguments].keys.map {|arg| "[#{arg}]" }.join(' ')}"
          if docs[:arguments].any?
            GitReflow.say "ARGUMENTS"
            docs[:arguments].each do |arg_name, arg_desc|
              default_text = commands[name][:arguments][arg_name].nil? ? "" : "(default: #{commands[name][:arguments][arg_name]}) "
              GitReflow.say "    #{arg_name} – #{default_text}#{arg_desc}"
            end
          end
          if docs[:flags].any? || docs[:switches].any?
            cmd = commands[name.to_sym]
            GitReflow.say "COMMAND OPTIONS"
            docs[:flags].each do |flag_name, flag_desc|
              flag_names = [flag_name.to_s[0], flag_name].map {|f| "-#{f}" }.join(', ')
              flag_default = cmd[:flags][flag_name]

              GitReflow.say "    #{flag_names} – #{!flag_default.nil? ? "(default: #{flag_default})  " : ""}#{flag_desc}"
            end
            docs[:switches].each do |switch_name, switch_desc|
              switch_names = [switch_name.to_s[0], "-#{switch_name}"].map {|s| "-#{s}" }.join(', ')
              switch_default = cmd[:switches][switch_name]

              GitReflow.say "    #{switch_names} – #{!switch_default.nil? ? "(default: #{switch_default})  " : ""}#{switch_desc}"
            end
          end
        else
          help
        end
      end

      # Outputs documentation for git-reflow
      def help
        GitReflow.say "NAME"
        GitReflow.say "    git-reflow – Git Reflow manages your git workflow."
        GitReflow.say "VERSION"
        GitReflow.say "    #{GitReflow::VERSION}"
        GitReflow.say "USAGE"
        GitReflow.say "    git-reflow command [command options] [arguments...]"
        GitReflow.say "COMMANDS"
        command_docs.each do |command_name, command_doc|
          GitReflow.say "    #{command_name}\t– #{command_doc[:summary]}"
        end
      end

      def parse_command_options!(name)
        name = name.to_sym
        options = {}
        docs = command_docs[name]
        OptionParser.new do |opts|
          opts.banner = "USAGE:\n  git-reflow #{name} [command options] #{docs[:arguments].keys.map {|arg| "[#{arg}]" }.join(' ')}"
          opts.separator  ""
          opts.separator  "COMMAND OPTIONS:" if docs[:flags].any? || docs[:switches].any?

          self.commands[name][:flags].each do |flag_name, flag_default|
            opts.on("-#{flag_name[0]}", "--#{flag_name} #{flag_name.upcase}", command_docs[name][:flags][flag_name]) do |f|
              options[flag_name] = f || flag_default
            end
          end

          self.commands[name][:switches].each do |switch_name, switch_default|
            opts.on("-#{switch_name[0]}", "--[no-]#{switch_name}", command_docs[name][:switches][switch_name]) do |s|
              options[switch_name] = s || switch_default
            end
          end
        end.parse!

        # Add arguments to optiosn to pass to defined commands
        commands[name][:arguments].each do |arg_name, arg_default|
          options[arg_name] = ARGV.shift || arg_default
        end
        options
      rescue OptionParser::InvalidOption
        documentation_for_command(name)
        exit 1
      end

    end
  end
end

extend GitReflow::Workflow
