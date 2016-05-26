require 'github_api'
require 'git_reflow/git_helpers'

module GitReflow
  module GitServer
    class GitHub < Base
      require_relative 'git_hub/pull_request'

      extend GitHelpers
      include Sandbox

      attr_accessor :connection

      def initialize(config_options = {})
        project_only     = !!config_options.delete(:project_only)
        using_enterprise = !!config_options.delete(:enterprise)

        gh_site_url     = self.class.site_url
        gh_api_endpoint = self.class.api_endpoint

        if using_enterprise
          gh_site_url     = ask("Please enter your Enterprise site URL (e.g. https://github.company.com):")
          gh_api_endpoint = ask("Please enter your Enterprise API endpoint (e.g. https://github.company.com/api/v3):")
        end

        self.class.site_url     = gh_site_url
        self.class.api_endpoint = gh_api_endpoint

        # We remove any existing setup first, then setup our required config settings
        GitReflow::Config.unset('reflow.local-projects', value: "#{self.class.remote_user}/#{self.class.remote_repo_name}")
        GitReflow::Config.add('reflow.local-projects', "#{self.class.remote_user}/#{self.class.remote_repo_name}") if project_only
        GitReflow::Config.set('reflow.git-server', 'GitHub', local: project_only)
      end

      def self.connection
        if self.oauth_token.length > 0
          @connection ||= ::Github.new do |config|
            config.oauth_token = GitServer::GitHub.oauth_token
            config.endpoint    = GitServer::GitHub.api_endpoint
            config.site        = GitServer::GitHub.site_url
          end
        end
      end

      def self.user
        GitReflow::Config.get('github.user')
      end

      def self.user=(github_user)
        GitReflow::Config.set('github.user', github_user, local: project_only?)
      end

      def self.oauth_token
        GitReflow::Config.get('github.oauth-token')
      end

      def self.oauth_token=(oauth_token)
        GitReflow::Config.set('github.oauth-token', oauth_token, local: project_only?)
        oauth_token
      end

      def self.api_endpoint
        endpoint         = "#{GitReflow::Config.get('github.endpoint')}".strip
        (endpoint.length > 0) ? endpoint : ::Github.endpoint
      end

      def self.api_endpoint=(api_endpoint)
        GitReflow::Config.set("github.endpoint", api_endpoint, local: project_only?)
        api_endpoint
      end

      def self.site_url
        site_url     = "#{GitReflow::Config.get('github.site')}".strip
        (site_url.length > 0) ? site_url : ::Github.site
      end

      def self.site_url=(site_url)
        GitReflow::Config.set("github.site", site_url, local: project_only?)
        site_url
      end

      def connection
        @connection ||= self.class.connection
      end

      def authenticate(options = {silent: false})
        if connection and self.class.oauth_token.length > 0
          unless options[:silent]
            GitReflow.say "Your GitHub account was already setup with: "
            GitReflow.say "\tUser Name: #{self.class.user}"
            GitReflow.say "\tEndpoint: #{self.class.api_endpoint}"
          end
        else
          begin
            gh_user     = options[:user] || ask("Please enter your GitHub username: ")
            gh_password = options[:password] || ask("Please enter your GitHub password (we do NOT store this): ") { |q| q.echo = false }

            @connection = ::Github.new do |config|
              config.basic_auth = "#{gh_user}:#{gh_password}"
              config.endpoint   = GitServer::GitHub.api_endpoint
              config.site       = GitServer::GitHub.site_url
              config.adapter    = :net_http
            end

            @connection.connection_options = {headers: {"X-GitHub-OTP" => options[:two_factor_auth_code]}} if options[:two_factor_auth_code]

            previous_authorizations = @connection.oauth.all.select {|auth| auth.note == "git-reflow (#{run('hostname', loud: false).strip})" }
            if previous_authorizations.any?
              authorization = previous_authorizations.last
              GitReflow.say "You have previously setup git-reflow on this machine, but we can no longer find the stored token.", :error
              GitReflow.say "Please visit https://github.com/settings/tokens and delete the token for: git-reflow (#{run('hostname', loud: false).strip})", :notice
              raise "Setup could not be completed."
            else
              authorization = @connection.oauth.create scopes: ['repo'], note: "git-reflow (#{run('hostname', loud: false).strip})"
            end

            self.class.oauth_token = authorization.token

          rescue ::Github::Error::Unauthorized => e
            if e.inspect.to_s.include?('two-factor')
              begin
                # dummy request to trigger a 2FA SMS since a HTTP GET won't do it
                @connection.oauth.create scopes: ['repo'], note: "thank Github for not making this straightforward"
              rescue ::Github::Error::Unauthorized
              ensure
                two_factor_code = ask("Please enter your two-factor authentication code: ")
                self.authenticate options.merge({user: gh_user, password: gh_password, two_factor_auth_code: two_factor_code})
              end
            else
              GitReflow.say "Github Authentication Error: #{e.inspect}", :error
            end
          rescue StandardError => e
            raise "We were unable to authenticate with Github."
          else
            GitReflow.say "Your GitHub account was successfully setup!", :success
          end
        end

        @connection
      end

      def get_build_status(sha)
        connection.repos.statuses.all(self.class.remote_user, self.class.remote_repo_name, sha).first
      end

      def colorized_build_description(state, description)
        colorized_statuses = {
          pending: :yellow,
          success: :green,
          error: :red,
          failure: :red }
        description.colorize( colorized_statuses[state.to_sym] )
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
