require 'git_reflow/config'

module GitReflow
  class GitServer::Base
    @connection       = nil
    @project_only     = false
    @git_config_group = 'base'

    def initialize(options)
      @project_only = !!options.delete(:project_only)

      site_url     = self.class.site_url
      api_endpoint = self.class.api_endpoint

      self.class.site_url     = site_url
      self.class.api_endpoint = api_endpoint

      authenticate
    end

    def authenticate
      raise "#{self.class.to_s}#authenticate method must be implemented"
    end

    def find_pull_request(options)
      raise "#{self.class.to_s}#find_pull_request(options) method must be implemented"
    end

    def self.connection
      raise "#{self.class.to_s}.connection method must be implemented"
    end

    def self.user
      GitReflow::Config.get("#{@git_config_group}.user")
    end

    def self.oauth_token
      GitReflow::Config.get("#{@git_config_group}.oauth-token")
    end

    def self.oauth_token=(oauth_token, options = {})
      GitReflow::Config.set("#{@git_config_group}.oauth-token", oauth_token, local: @project_only)
      oauth_token
    end

    def self.api_endpoint
      endpoint         = GitReflow::Config.get("#{@git_config_group}.endpoint")
      (endpoint.length > 0) ? endpoint : ::Github::Configuration.new.endpoint
    end

    def self.api_endpoint=(api_endpoint)
      GitReflow::Config.set("#{@git_config_group}.endpoint", api_endpoint, local: @project_only)
      api_endpoint
    end

    def self.site_url
      site_url     = GitReflow::Config.get("#{@git_config_group}.site")
      (site_url.length > 0) ? site_url : ::Github::Configuration.new.site
    end

    def self.site_url=(site_url)
      GitReflow::Config.set("#{@git_config_group}.site", site_url, local: @project_only)
      site_url
    end

    def connection
      @connection ||= self.class.connection
    end

    def pull_request_comments(pull_request)
      raise "#{self.class.to_s}#pull_request_comments(pull_request) method must be implemented"
    end

    def has_pull_request_comments?(pull_request)
      pull_request_comments(pull_request).count > 0
    end

    def get_build_status sha
      raise "#{self.class.to_s}#get_build_status(sha) method must be implemented"
    end

    def colorized_build_description status
      raise "#{self.class.to_s}#colorized_build_description(status) method must be implemented"
    end

    def find_authors_of_open_pull_request_comments(pull_request)
      raise "#{self.class.to_s}#find_authors_of_open_pull_request_comments(pull_request) method must be implemented"
    end

    def get_commited_time(commit_sha)
      raise "#{self.class.to_s}#get_commited_time(commit_sha) method must be implemented"
    end
  end
end
