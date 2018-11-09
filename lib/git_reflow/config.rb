# frozen_string_literal: true

module GitReflow
  # This is a utility module for getting and setting git-config variables.
  module Config
    CONFIG_FILE_PATH = "#{ENV['HOME']}/.gitconfig.reflow"

    module_function

    def get(key, reload: false, all: false, local: false)
      return cached_git_config_value(key) unless reload || cached_git_config_value(key).empty?

      local = local ? '--local ' : ''
      if all
        new_value = GitReflow::Sandbox.run("git config #{local}--get-all #{key}", loud: false, blocking: false)
      else
        new_value = GitReflow::Sandbox.run("git config #{local}--get #{key}", loud: false, blocking: false)
      end
      cache_git_config_key(key, new_value)
    end

    def set(key, value, local: false)
      value = value.to_s.strip
      if local
        GitReflow::Sandbox.run "git config --replace-all #{key} \"#{value}\"", loud: false, blocking: false
      else
        GitReflow::Sandbox.run "git config -f #{CONFIG_FILE_PATH} --replace-all #{key} \"#{value}\"", loud: false, blocking: false
      end
    end

    def unset(key, value: nil, local: false)
      value = value.nil? ? '' : "\"#{value}\""
      if local
        GitReflow::Sandbox.run "git config --unset-all #{key} #{value}", loud: false, blocking: false
      else
        GitReflow::Sandbox.run "git config -f #{CONFIG_FILE_PATH} --unset-all #{key} #{value}", loud: false, blocking: false
      end
    end

    def add(key, value, local: false, global: false)
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
