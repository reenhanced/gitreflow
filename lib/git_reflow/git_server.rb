module GitReflow
  module GitServer
    autoload :Base,   'git_reflow/git_server/base'
    autoload :GitHub, 'git_reflow/git_server/git_hub'

    extend self

    class ConnectionError < StandardError; end

    def connect(options = nil)
      options ||= { provider: 'GitHub' }
      begin
        provider_class_for(options.delete(:provider)).new(options)
      rescue ConnectionError => e
        puts e.message
      end
    end

    def connection
      return nil unless current_provider
      current_provider.connection
    end

    def current_provider
      if (provider = GitReflow::Config.get('reflow.git-server')) and provider.length > 0
        begin
          provider_class_for(provider)
        rescue ConnectionError => e
          puts e.message
          nil
        end
      else
        puts "[notice] Reflow hasn't been setup yet.  Run 'git reflow setup' to continue"
        nil
      end
    end

    def can_connect_to?(provider)
      GitReflow::GitServer.const_defined?(provider)
    end

    private

    def provider_class_for(provider)
      raise ConnectionError, "GitServer not setup for: #{provider}" unless self.can_connect_to?(provider)
      GitReflow::GitServer.const_get(provider)
    end
  end
end
