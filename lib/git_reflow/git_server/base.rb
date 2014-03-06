require 'git_reflow/config'

module GitReflow
  class GitServer::Base
    @@connection       = nil
    @@config_key_scope = self.class.to_s.downcase
    @project_only      = false

    def initialize(options)
      @project_only = options.delete(:project_only)

      site_url     = self.class.site_url
      api_endpoint = self.class.api_endpoint

      if @project_only
        self.class.site_url     = site_url, { local: true }
        self.class.api_endpoint = api_endpoint, { local: true }
      else
        self.class.site_url     = site_url
        self.class.api_endpoint = api_endpoint
      end

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

    def self.api_endpoint
      raise "#{self.class.to_s}.api_endpoint method must be implemented"
    end

    def self.api_endpoint=(api_endpoint, options = {local: false})
      GitReflow::Config.set("#{@@config_key_scope}.endpoint}", api_endpoint, options)
      @@api_endpoint = api_endpoint
    end

    def self.site_url
      raise "#{self.class.to_s}.site_url method must be implemented"
    end

    def self.site_url=(site_url, options = {local: false})
      GitReflow::Config.set("#{@@config_key_scope}.site}", site_url, options)
      @@site_url = site_url
    end
  end
end
