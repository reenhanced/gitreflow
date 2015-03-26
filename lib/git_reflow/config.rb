module GitReflow
  module Config
    extend self

    def get(key, options = {reload: false})
      if options[:reload] == false and cached_key_value = instance_variable_get(:"@#{key.tr('.-', '_')}")
        cached_key_value
      else
        if options[:all]
          new_value = GitReflow::Sandbox.run "git config --get-all #{key}", loud: false
        else
          new_value = GitReflow::Sandbox.run "git config --get #{key}", loud: false
        end
        instance_variable_set(:"@#{key.tr('.-', '_')}", new_value.strip)
      end
    end

    def set(key, value, options = { local: false })
      value = value.strip
      if options.delete(:local)
        GitReflow::Sandbox.run "git config --replace-all #{key} \"#{value}\"", loud: false
      else
        GitReflow::Sandbox.run "git config --global --replace-all #{key} \"#{value}\"", loud: false
      end
    end

    def unset(key, options = { local: false })
      value = (options[:value].nil?) ? "" : "\"#{options[:value]}\""
      if options.delete(:local)
        GitReflow::Sandbox.run "git config --unset #{key} #{value}", loud: false
      else
        GitReflow::Sandbox.run "git config --global --unset #{key} #{value}", loud: false
      end
    end

    def add(key, value, options = { local: false })
      if options.delete(:local)
        GitReflow::Sandbox.run "git config --add #{key} \"#{value}\"", loud: false
      else
        GitReflow::Sandbox.run "git config --global --add #{key} \"#{value}\"", loud: false
      end
    end
  end
end
