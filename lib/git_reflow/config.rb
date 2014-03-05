module GitReflow
  module Config
    extend self

    def get(key)
      `git config --get #{key}`.strip
    end

    def set(key, value, options = { local: false })
      if options.delete(:local)
        `git config --replace-all #{key} #{value}`
      else
        `git config --global --replace-all #{key} #{value}`
      end
    end
  end
end
