require 'bitbucket_rest_api'
require 'git_reflow/git_helpers'

module GitReflow
  module GitServer
    class BitBucket < Base
      require_relative 'bit_bucket/pull_request'

      attr_reader :connection

      def initialize(config_options = {})
        project_only = !!config_options.delete(:project_only)

        # We remove any existing setup first, then setup our required config settings
        GitReflow::Config.unset('reflow.local-projects', value: "#{self.class.remote_user}/#{self.class.remote_repo_name}")
        GitReflow::Config.add('reflow.local-projects', "#{self.class.remote_user}/#{self.class.remote_repo_name}") if project_only
        GitReflow::Config.set('reflow.git-server', 'BitBucket', local: project_only)
      end

      def self.connection
        if api_key_setup?
          @connection ||= ::BitBucket.new login: remote_user, password: api_key
        end
      end

      def self.api_endpoint
        endpoint         = GitReflow::Config.get("bitbucket.endpoint", local: project_only?)
        (endpoint.length > 0) ? endpoint : ::BitBucket::Configuration::DEFAULT_ENDPOINT
      end

      def self.site_url
        site_url     = GitReflow::Config.get("bitbucket.site", local: project_only?)
        (site_url.length > 0) ? site_url : 'https://bitbucket.org'
      end

      def self.api_key
        GitReflow::Config.get("bitbucket.api-key", reload: true, local: project_only?)
      end

      def self.api_key=(key)
        GitReflow::Config.set("bitbucket.api-key", key, local: project_only?)
      end
      def self.api_key_setup?
        (self.api_key.length > 0)
      end

      def self.user
        GitReflow::Config.get('bitbucket.user', local: project_only?)
      end

      def self.user=(bitbucket_user)
        GitReflow::Config.set('bitbucket.user', bitbucket_user, local: project_only?)
      end

      def authenticate(options = {silent: false})
        begin
          if connection and self.class.api_key_setup?
            unless options[:silent]
              GitReflow.say "\nYour BitBucket account was already setup with:"
              GitReflow.say "\tUser Name: #{self.class.user}"
            end
          else
            self.class.user = options[:user] || ask("Please enter your BitBucket username: ")
            GitReflow.say "\nIn order to connect your BitBucket account,"
            GitReflow.say "you'll need to generate an API key for your team"
            GitReflow.say "Visit #{self.class.site_url}/account/user/#{self.class.remote_user}/api-key/, to generate it\n"
            self.class.api_key = ask("Please enter your team's API key: ")
            connection.repos.all(self.class.remote_user).count
            GitReflow.say "Connected to BitBucket\!", :success
          end
        rescue ::BitBucket::Error::Unauthorized => e
          GitReflow::Config.unset('bitbucket.api-key', local: self.class.project_only?)
          GitReflow.say "Invalid API key for team #{self.class.remote_user}.", :error
        end
      end

      def connection
        @connection ||= self.class.connection
      end

      def get_build_status(sha)
        # BitBucket does not currently support build status via API
        # for updates: https://bitbucket.org/site/master/issue/8548/better-ci-integration-add-a-build-status
        return nil
      end

      def colorized_build_description(state, description)
        ""
      end

      def create_pull_request(options = {})
        PullRequest.create(options)
      end

      def find_open_pull_request(options = {})
        PullRequest.find_open(options)
      end

    end
  end
end
