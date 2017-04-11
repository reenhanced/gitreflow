module GitReflow
  module Config
    extend self

    CONFIG_FILE_PATH = "#{ENV['HOME']}/.gitconfig.reflow".freeze

    def get(key, reload: false, all: false, local: false)
      if reload == false and cached_key_value = instance_variable_get(:"@#{key.tr('.-', '_')}")
        cached_key_value
      else
        local = local ? '--local ' : ''
        if all
          new_value = GitReflow::Sandbox.run "git config #{local}--get-all #{key}", loud: false, blocking: false
        else
          new_value = GitReflow::Sandbox.run "git config #{local}--get #{key}", loud: false, blocking: false
        end
        instance_variable_set(:"@#{key.tr('.-', '_')}", new_value.strip)
      end
    end

    def set(key, value, local: false)
      value = "#{value}".strip
      if local
        GitReflow::Sandbox.run "git config --replace-all #{key} \"#{value}\"", loud: false, blocking: false
      else
        GitReflow::Sandbox.run "git config -f #{CONFIG_FILE_PATH} --replace-all #{key} \"#{value}\"", loud: false, blocking: false
      end
    end

    def unset(key, value: nil, local: false)
      value = (value.nil?) ? "" : "\"#{value}\""
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
  end
end
