# frozen_string_literal: true

module GitReflow
  # This is a utility module for getting and setting git-config variables.
  module Config
    CONFIG_FILE_PATH = "#{ENV['HOME']}/.gitconfig.reflow"

    module_function

    # Gets the reqested git configuration variable.
    #
    # @param [String] key The key to get the value(s) for
    # @option options [Boolean] :reload (false) whether to reload the value or use a cached value if available
    # @option options [Boolean] :all (false) whether to return all keys for a multi-valued key
    # @option options [Boolean] :local (false) whether to get the value specific to the current project
    # @return the value of the git configuration
    def get(key, reload: false, all: false, local: false, **_other_options)
      return cached_git_config_value(key) unless reload || cached_git_config_value(key).empty?

      local = local ? '--local ' : ''
      if all
        new_value = GitReflow::Sandbox.run("git config #{local}--get-all #{key}", loud: false, blocking: false)
      else
        new_value = GitReflow::Sandbox.run("git config #{local}--get #{key}", loud: false, blocking: false)
      end
      cache_git_config_key(key, new_value)
    end

    # Sets the reqested git configuration variable.
    #
    # @param [String] key The key to set the value for
    # @param [String] value The value to set it to
    # @option options [Boolean] :local (false) whether to set the value specific to the current project
    # @return the value of the git configuration
    def set(key, value, local: false, **_other_options)
      value = value.to_s.strip
      if local
        GitReflow::Sandbox.run "git config --replace-all #{key} \"#{value}\"", loud: false, blocking: false
      else
        GitReflow::Sandbox.run "git config -f #{CONFIG_FILE_PATH} --replace-all #{key} \"#{value}\"", loud: false, blocking: false
      end
    end

    # Remove values of the reqested git configuration variable.
    #
    # @param [String] key The key to remove
    # @option options [Boolean] :value (nil) The value of the key to remove
    # @option options [Boolean] :local (false) whether to remove the value specific to the current project
    # @return the result of running the git command
    def unset(key, value: nil, local: false, **_other_options)
      value = value.nil? ? '' : "\"#{value}\""
      if local
        GitReflow::Sandbox.run "git config --unset-all #{key} #{value}", loud: false, blocking: false
      else
        GitReflow::Sandbox.run "git config -f #{CONFIG_FILE_PATH} --unset-all #{key} #{value}", loud: false, blocking: false
      end
    end

    # Adds a new git configuration variable.
    #
    # @param [String] key The new key to set the value for
    # @param [String] value The value to set it to
    # @option options [Boolean] :local (false) whether to set the value specific to the current project
    # @option options [Boolean] :global (false) whether to set the value globaly. if neither local or global is set gitreflow will default to using a configuration file
    # @return the result of running the git command
    def add(key, value, local: false, global: false, **_other_options)
      if global
        GitReflow::Sandbox.run "git config --global --add #{key} \"#{value}\"", loud: false, blocking: false
      elsif local
        GitReflow::Sandbox.run "git config --add #{key} \"#{value}\"", loud: false, blocking: false
      else
        GitReflow::Sandbox.run "git config -f #{CONFIG_FILE_PATH} --add #{key} \"#{value}\"", loud: false, blocking: false
      end
    end

    def cached_git_config_value(key)
      instance_variable_get(:"@#{key.tr('.-', '_')}").to_s
    end

    def cache_git_config_key(key, value)
      instance_variable_set(:"@#{key.tr('.-', '_')}", value.to_s.strip)
    end
  end
end
