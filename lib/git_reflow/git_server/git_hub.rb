require 'github_api'

module GitReflow
  class GitHub < GitServer
    @@connection      = nil
    @project_only     = false
    @using_enterprise = false

    def initialize(config_options)
      @project_only     = config_options.delete(:project_only)
      @using_enterprise = config_options.delete(:enterprise)

      gh_site_url     = self.class.site_url
      gh_api_endpoint = self.class.api_endpoint

      if @using_enterprise
        gh_site_url     = ask("Please enter your Enterprise site URL (e.g. https://github.company.com):")
        gh_api_endpoint = ask("Please enter your Enterprise API endpoint (e.g. https://github.company.com/api/v3):")
      end

      if @project_only
        self.class.site_url     = gh_site_url, { local: true }
        self.class.api_endpoint = gh_api_endpoint, { local: true }
      else
        self.class.site_url     = gh_site_url
        self.class.api_endpoint = gh_api_endpoint
      end

      authenticate
    end

    def authenticate!
      begin
        gh_user     = ask("Please enter your GitHub username: ")
        gh_password = ask("Please enter your GitHub password (we do NOT store this): ") { |q| q.echo = false }

        @@connection = Github.new do |config|
          config.basic_auth = "#{gh_user}:#{gh_password}"
          config.endpoint   = GitServer::GitHub.api_endpoint
          config.site       = GitServer::GitHub.site_url
          config.adapter    = :net_http
          config.ssl        = {:verify => false}
        end

        authorization = @@connection.oauth.create 'scopes' => ['repo']
        oauth_token   = authorization[:token]

        if @project_only
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

    def authenticate
      if self.class.connection
        puts "Your GitHub account was already setup with: "
        puts "\tUser Name: #{self.class.user}"
        puts "\tEndpoint: #{self.class.api_endpoint}"
      else
        authenticate!
      end
    end

    def self.connection
      if self.oauth_token.length > 0
        @@connection ||= Github.new do |config|
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
      @@oauth_token ||= GitReflow::Config.get('github.oauth-token')
    end

    def self.oauth_token=(oauth_token, options = {})
      GitReflow::Config.set('github.oauth-token', oauth_token, options)
      @@oauth_token = oauth_token
    end

    def self.api_endpoint
      endpoint         = GitReflow::Config.get('github.endpoint')
      @@api_endpoint ||= (endpoint.length > 0) ? endpoint : ::Github::Configuration::DEFAULT_ENDPOINT
    end

    def self.site_url
      site_url     = GitReflow::Config.get('github.site')
      @@site_url ||= (site_url.length > 0) ? site_url : Github::Configuration::DEFAULT_SITE
    end
  end
end
