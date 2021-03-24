require 'git_reflow/sandbox'
require 'git_reflow/git_helpers'
require 'bundler/inline'

module GitReflow
  module Workflow
    def self.included base
      base.extend ClassMethods
    end

    # @nodoc
    def self.current
      return @current unless @current.nil?
      # First look for a "Workflow" file in the current directory, then check
      # for a global Workflow file stored in git-reflow git config.
      loaded_local_workflow  = GitReflow::Workflows::Core.load_workflow "#{GitReflow.git_root_dir}/Workflow"
      loaded_global_workflow = false

      unless loaded_local_workflow
        loaded_global_workflow = GitReflow::Workflows::Core.load_workflow GitReflow::Config.get('reflow.workflow')
      end

      @current = GitReflow::Workflows::Core
    end

    # @nodoc
    # This is primarily a helper method for tests.  Due to the nature of how the
    # tests load many different workflows, this helps start fresh and isolate
    # the scenario at hand.
    def self.reset!
      GitReflow.logger.debug "Resetting GitReflow workflow..."
      current.commands = {}
      current.callbacks = { before: {}, after: {}}
      @current = nil
      # We'll need to reload the core class again in order to clear previously
      # eval'd content in the context of the class
      load File.expand_path('../workflows/core.rb', __FILE__)
    end

    module ClassMethods
      include GitReflow::Sandbox
      include GitReflow::GitHelpers

      def commands
        @commands ||= {}
      end

      def commands=(command_hash)
        @commands = command_hash
      end

      def command_docs
        @command_docs ||= {}
      end

      def command_docs=(command_doc_hash)
        @command_docs = command_doc_hash
      end

      def callbacks
        @callbacks ||= {
          before: {},
          after: {}
        }
      end

      def callbacks=(callback_hash)
        @callbacks = callback_hash
      end

      # Proxy our Config class so that it's available in workflow files
      def git_config
        GitReflow::Config
      end

      def git_server
        GitReflow.git_server
      end

      def logger
        GitReflow.logger
      end

      # Checks for an installed gem, and if none is installed use bundler's
      # inline gemfile to install it.
      #
      # @param name [String] the name of the gem to require as a dependency
      def use_gem(name, *args)
        run("gem list -ie #{name}", loud: false, raise: true)
        logger.info "Using installed gem '#{name}' with options: #{args.inspect}"
      rescue ::GitReflow::Sandbox::CommandError => e
        abort e.message unless e.output =~ /\Afalse/
        logger.info "Installing gem '#{name}' with options: #{args.inspect}"
        say "Installing gem '#{name}'...", :notice
        gemfile do
          source "https://rubygems.org"
          gem name, *args
        end
      end

      # Use bundler's inline gemfile to install dependencies.
      # See: https://bundler.io/v1.16/guides/bundler_in_a_single_file_ruby_script.html
      #
      # @yield A block to be executed in the context of Bundler's `gemfile` DSL
      def use_gemfile(&block)
        logger.info "Using a custom gemfile"
        gemfile(true, &block)
      end

      # Loads a pre-defined workflow (FlatMergeWorkflow) from within another
      # Workflow file
      #
      # @param name [String] the name of the Workflow file to use as a basis
      def use(workflow_name)
        if workflows.key?(workflow_name)
          GitReflow.logger.debug "Using Workflow: #{workflow_name}"
          GitReflow::Workflows::Core.load_workflow(workflows[workflow_name])
        else
          GitReflow.logger.error "Tried to use non-existent Workflow: #{workflow_name}"
        end
      end

      # Keeps track of available workflows when using `.use(workflow_name)`
      # Workflow file
      #
      # @return [Hash, nil] A hash with [workflow_name, workflow_path] as key/value pairs
      def workflows
        return @workflows if @workflows
        workflow_paths = Dir["#{File.dirname(__FILE__)}/workflows/*Workflow"]
        @workflows = {}
        workflow_paths.each { |p| @workflows[File.basename(p)] = p }
        @workflows
      end

      # Creates a singleton method on the included class
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
        params[:flags]     ||= {}
        params[:switches]  ||= {}
        params[:arguments] ||= {}
        defaults           ||= params[:arguments].merge(params[:flags]).merge(params[:switches])

        # Ensure flags and switches use kebab-case
        kebab_case_keys!(params[:flags])
        kebab_case_keys!(params[:switches])

        # Register the command with the workflow so that we can properly handle
        # option parsing from the command line
        self.commands[name] = params
        self.command_docs[name] = params

        self.define_singleton_method(name) do |args = {}|
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

          GitReflow.logger.debug "callbacks: #{callbacks.inspect}"
          Array(callbacks[:before][name]).each do |block|
            GitReflow.logger.debug "(before) callback running for `#{name}` command..."
            argument_overrides = block.call(**args_with_defaults) || {}
            args_with_defaults.merge!(argument_overrides) if argument_overrides.is_a?(Hash)
          end

          GitReflow.logger.info "Running command `#{name}` with args: #{args_with_defaults.inspect}..."
          block.call(**args_with_defaults)

          Array(callbacks[:after][name]).each do |block|
            GitReflow.logger.debug "(after) callback running for `#{name}` command..."
            block.call(**args_with_defaults)
          end
        end
      end

      # Stores a Proc to be called once the command successfully finishes
      #
      # Procs declared with `before` are executed sequentially in the order they are defined in a custom Workflow
      # file.
      #
      # @param name [Symbol] the name of the method to create
      #
      # @yield A block to be executed before the given command.  These blocks
      # are executed in the context of `GitReflow::Workflows::Core`
      def before(name, &block)
        name = name.to_sym
        if commands[name].nil?
          GitReflow.logger.error "Attempted to register (before) callback for non-existing command: #{name}"
        else
          GitReflow.logger.debug "(before) callback registered for: #{name}"
          callbacks[:before][name] ||= []
          callbacks[:before][name] << block
        end
      end

      # Stores a Proc to be called once the command successfully finishes
      #
      # Procs declared with `after` are executed sequentially in the order they are defined in a custom Workflow
      # file.
      #
      # @param name [Symbol] the name of the method to create
      #
      # @yield A block to be executed after the given command.  These blocks
      # are executed in the context of `GitReflow::Workflows::Core`
      def after(name, &block)
        name = name.to_sym
        if commands[name].nil?
          GitReflow.logger.error "Attempted to register (after) callback for non-existing command: #{name}"
        else
          GitReflow.logger.debug "(after) callback registered for: #{name}"
          callbacks[:after][name] ||= []
          callbacks[:after][name] << block
        end
      end

      # Creates a singleton method on the included class
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
          flags: kebab_case_keys!(flags),
          switches: kebab_case_keys!(switches)
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
              flag_names = ["-#{flag_name.to_s[0]}", "--#{flag_name}"]
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

      # Parses ARGV for the provided git-reflow command name
      #
      # @param name [Symbol, String] the name of the git-reflow command to parse from ARGV
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
              options[kebab_to_underscore(flag_name)] = f || flag_default
            end
          end

          self.commands[name][:switches].each do |switch_name, switch_default|
            opts.on("-#{switch_name[0]}", "--[no-]#{switch_name}", command_docs[name][:switches][switch_name]) do |s|
              options[kebab_to_underscore(switch_name)] = s || switch_default
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

      private

      def kebab_case_keys!(hsh)
        hsh.keys.each do |key_to_update|
          hsh[underscore_to_kebab(key_to_update)] = hsh.delete(key_to_update) if key_to_update =~ /_/
        end

        hsh
      end

      def kebab_to_underscore(sym_or_string)
        sym_or_string.to_s.gsub('-', '_').to_sym
      end

      def underscore_to_kebab(sym_or_string)
        sym_or_string.to_s.gsub('_', '-').to_sym
      end
    end
  end
end

extend GitReflow::Workflow
