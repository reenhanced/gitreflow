require 'github_api'
require 'git_reflow/git_helpers'

module GitReflow
  module GitServer
    class GitHub < Base
      include GitHelpers

      attr_accessor :connection

      @@project_only     = false
      @@using_enterprise = false

      def initialize(config_options)
        @@project_only     = !!config_options.delete(:project_only)
        @@using_enterprise = !!config_options.delete(:enterprise)

        gh_site_url     = self.class.site_url
        gh_api_endpoint = self.class.api_endpoint

        if @@using_enterprise
          gh_site_url     = ask("Please enter your Enterprise site URL (e.g. https://github.company.com):")
          gh_api_endpoint = ask("Please enter your Enterprise API endpoint (e.g. https://github.company.com/api/v3):")
        end

        self.class.site_url     = gh_site_url
        self.class.api_endpoint = gh_api_endpoint

        if @@project_only
          GitReflow::Config.set('reflow.git-server', 'GitHub', local: true)
        else
          GitReflow::Config.set('reflow.git-server', 'GitHub')
        end

        authenticate
      end

      def authenticate
        if @connection
          puts "Your GitHub account was already setup with: "
          puts "\tUser Name: #{self.class.user}"
          puts "\tEndpoint: #{self.class.api_endpoint}"
        else
          begin
            gh_user     = ask("Please enter your GitHub username: ")
            gh_password = ask("Please enter your GitHub password (we do NOT store this): ") { |q| q.echo = false }

            @connection = ::Github.new do |config|
              config.basic_auth = "#{gh_user}:#{gh_password}"
              config.endpoint   = GitServer::GitHub.api_endpoint
              config.site       = GitServer::GitHub.site_url
              config.adapter    = :net_http
              config.ssl        = {:verify => false}
            end

            previous_authorizations = @connection.oauth.all.select {|auth| auth.note == "git-reflow (#{`hostname`.strip})" }
             if previous_authorizations.any?
               authorization = previous_authorizations.last
             else
               authorization = @connection.oauth.create scopes: ['repo'], note: "git-reflow (#{`hostname`.strip})"
             end

             oauth_token   = authorization.token

            if @@project_only
              self.class.oauth_token = oauth_token, { local: true }
            else
              self.class.oauth_token = oauth_token
            end
            puts "\nYour GitHub account was successfully setup!"
          rescue StandardError => e
            puts "\nInvalid username or password: #{e.inspect}"
          else
            puts "\nYour GitHub account was successfully setup!"
          end
        end
      end

      def find_pull_request(options)
        existing_pull_request = nil
        @connection.pull_requests.all(self.remote_user, remote_repo_name, :state => 'open') do |pull_request|
          if pull_request.base.label == "#{self.remote_user}:#{options[:to]}" and
             pull_request.head.label == "#{self.remote_user}:#{options[:from]}"
             existing_pull_request = pull_request
             break
          end
        end

        existing_pull_request
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

      def self.oauth_token
        GitReflow::Config.get('github.oauth-token')
      end

      def self.oauth_token=(oauth_token, options = {})
        GitReflow::Config.set('github.oauth-token', oauth_token, local: @@project_only)
        oauth_token
      end

      def self.api_endpoint
        endpoint         = GitReflow::Config.get('github.endpoint')
        (endpoint.length > 0) ? endpoint : ::Github::Configuration.new.endpoint
      end

      def self.api_endpoint=(api_endpoint)
        GitReflow::Config.set("github.endpoint", api_endpoint, local: @@project_only)
        api_endpoint
      end

      def self.site_url
        site_url     = GitReflow::Config.get('github.site')
        (site_url.length > 0) ? site_url : ::Github::Configuration.new.site
      end

      def self.site_url=(site_url)
        GitReflow::Config.set("github.site", site_url, local: @@project_only)
        site_url
      end
    end
  end
end
