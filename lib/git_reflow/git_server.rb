module GitReflow
  module GitServer
    autoload :Base, 'git_reflow/git_server/base'
    autoload :GitHub,     'git_reflow/git_server/git_hub'

    def self.connect(options = { provider: 'GitHub' })
      begin
        provider_class_for(options.delete(:provider)).new(options)
      rescue StandardError => e
        puts e.message
      end
    end

    def self.connection
      current_provider.connection
    end

    def self.current_provider
      if (provider = GitReflow::Config.get('reflow.git-server')) and provider.length > 0
        begin
          self.provider_class_for(provider)
        rescue StandardError => e
          puts e.message
        end
      else
        puts "[notice] Reflow hasn't been setup yet.  Run 'git reflow setup' to continue"
      end
    end

    def self.can_connect_to?(provider)
      GitReflow::GitServer.const_defined?(provider)
    end

    private

    def self.provider_class_for(provider)
      raise "GitServer not setup for: #{provider}" unless self.can_connect_to?(provider)
      GitReflow::GitServer.const_get(provider)
    end
  end
end
