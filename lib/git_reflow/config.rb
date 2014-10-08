module GitReflow
  module Config
    extend self

    def get(key)
      GitReflow::Sandbox.run "git config --get #{key}", loud: false
    end

    def set(key, value, options = { local: false })
      if options.delete(:local)
        GitReflow::Sandbox.run "git config --replace-all #{key} \"#{value}\"", loud: false
      else
        GitReflow::Sandbox.run "git config --global --replace-all #{key} \"#{value}\"", loud: false
      end
    end
  end
end
