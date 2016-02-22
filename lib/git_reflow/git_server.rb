module GitReflow
  module GitServer
    autoload :Base,        'git_reflow/git_server/base'
    autoload :GitHub,      'git_reflow/git_server/git_hub'
    autoload :PullRequest, 'git_reflow/git_server/pull_request'

    extend self

    class ConnectionError < StandardError; end

    def connect(options = {})
      options ||= {}
      options[:provider] = 'GitHub' if "#{options[:provider]}".length <= 0
      begin
        provider_name = options[:provider]
        provider = provider_class_for(options.delete(:provider)).new(options)
        provider.authenticate(options.keep_if {|key, value| key == :silent })
        provider
      rescue ConnectionError => e
        puts "Error connecting to #{provider_name}: #{e.message}"
      end
    end

    def connection
      return nil unless current_provider
      current_provider.connection
    end

    def current_provider
      provider = "#{GitReflow::Config.get('reflow.git-server', local: true)  || GitReflow::Config.get('reflow.git-server')}"
      if provider.length > 0
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

    def create_pull_request(options = {})
      raise "#{self.class.to_s}#create_pull_request method must be implemented"
    end

    def find_open_pull_request(options = {})
      raise "#{self.class.to_s}#find_open_pull_request method must be implemented"
    end

    private

    def provider_class_for(provider)
      raise ConnectionError, "GitServer not setup for \"#{provider}\"" unless self.can_connect_to?(provider)
      GitReflow::GitServer.const_get(provider)
    end
  end
end
