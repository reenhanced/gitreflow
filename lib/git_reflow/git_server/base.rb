require 'git_reflow/config'

module GitReflow
  class GitServer::Base
    @@connection       = nil
    @@project_only     = false

    def initialize(options)
      @@project_only = !!options.delete(:project_only)

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
      raise "#{self.class.to_s}.user method must be implemented"
    end

    def self.oauth_token
      raise "#{self.class.to_s}.oauth_token method must be implemented"
    end

    def self.oauth_token=(oauth_token)
      raise "#{self.class.to_s}.oauth_token= method must be implemented"
    end

    def self.api_endpoint
      raise "#{self.class.to_s}.api_endpoint method must be implemented"
    end

    def self.api_endpoint=(api_endpoint, options = {local: false})
      raise "#{self.class.to_s}.api_endpoint= method must be implemented"
    end

    def self.site_url
      raise "#{self.class.to_s}.site_url method must be implemented"
    end

    def self.site_url=(site_url, options = {local: false})
      raise "#{self.class.to_s}.site_url= method must be implemented"
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
