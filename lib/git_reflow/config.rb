module GitReflow
  module Config
    extend self

    def get(key)
      if cached_key_value = instance_variable_get(:"@#{key.tr('.-', '_')}")
        cached_key_value
      else
        new_value = GitReflow::Sandbox.run "git config --get #{key}", loud: false
        instance_variable_set(:"@#{key.tr('.-', '_')}", new_value)
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
  end
end
