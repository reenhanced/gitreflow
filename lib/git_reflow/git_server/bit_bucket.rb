require 'bitbucket_rest_api'
require 'git_reflow/git_helpers'

module GitReflow
  module GitServer
    class BitBucket < Base
      include GitHelpers

      attr_accessor :connection

      @project_only     = false

      def initialize(config_options = {})
        @project_only = @@project_only = !!config_options.delete(:project_only)

        if @project_only
          GitReflow::Config.set('reflow.git-server', 'BitBucket', local: true)
        else
          GitReflow::Config.set('reflow.git-server', 'BitBucket')
        end
      end

      def authenticate(options = {silent: false})
        begin
          if connection and self.class.oauth_setup?
            unless options[:silent]
              puts "\nYour BitBucket account was already setup with:"
              puts "\tUser Name: #{self.class.user}"
            end
          else
            self.class.user = options[:user] || ask("Please enter your BitBucket username: ")
            puts "\nIn order to connect your BitBucket account,"
            puts "you'll need to generate an OAuth consumer key and secret"
            puts "\nVisit #{self.class.site_url}/account/user/#{self.class.user.strip}/api, and reference our README"
          end
        rescue ::BitBucket::Error::Unauthorized => e
          puts "\nBitBucket Authentication Error: #{e.inspect}"
        end
      end

      def self.connection
        if oauth_setup?
          @connection ||= ::BitBucket.new oauth_token: oauth_key, oauth_secret: oauth_secret
        end
      end

      def self.api_endpoint
        endpoint         = GitReflow::Config.get("bitbucket.endpoint")
        (endpoint.length > 0) ? endpoint : ::BitBucket::Configuration::DEFAULT_ENDPOINT
      end

      def self.site_url
        site_url     = GitReflow::Config.get("bitbucket.site")
        (site_url.length > 0) ? site_url : 'https://bitbucket.org'
      end

      def self.oauth_key
        GitReflow::Config.get("bitbucket.oauth-key")
      end

      def self.oauth_key=(oauth_key, options = {})
        GitReflow::Config.set("bitbucket.oauth-key", oauth_key, local: @@project_only)
        oauth_key
      end

      def self.oauth_secret
        GitReflow::Config.get("bitbucket.oauth-secret")
      end

      def self.oauth_secret=(oauth_secret, options = {})
        GitReflow::Config.set("bitbucket.oauth-secret", oauth_secret, local: @@project_only)
        oauth_secret
      end

      def self.oauth_setup?
        (self.oauth_key.length > 0 and self.oauth_secret.length > 0)
      end

      def self.user
        GitReflow::Config.get('bitbucket.user')
      end

      def self.user=(bitbucket_user)
        GitReflow::Config.set('bitbucket.user', bitbucket_user, local: @@project_only)
      end

      def connection
        @connection ||= self.class.connection
      end

      def create_pull_request(options = {})
        pull_request = connection.pull_requests.create(remote_user, remote_repo_name,
                                                       title: options[:title],
                                                       body: options[:body],
                                                       source: { branch: { name: current_branch }},
                                                       destination: { branch: { name: options[:base] }},
                                                       reviewers: [{ username: self.class.user }])
      end

      def find_pull_request(options = {})
        begin
          matching_pull = connection.repos.pull_requests.all(remote_user, remote_repo_name).select do |pr|
            pr.source.branch.name == options[:from] and
            pr.destination.branch.name == options[:to]
          end.first

          if matching_pull
            matching_pull.number     = matching_pull.id
            matching_pull.html_url   = matching_pull.links.self.href
            matching_pull.head       = matching_pull.source
            matching_pull.head.label = matching_pull.source.branch.name
            matching_pull.base       = matching_pull.destination
            matching_pull.base.label = matching_pull.destination.branch.name
            matching_pull
          end
        rescue ::BitBucket::Error::NotFound => e
          say "No BitBucket repo found for #{remote_user}/#{remote_repo_name}", :error
        rescue ::BitBucket::Error::Forbidden => e
          puts e.inspect
          say "You don't have API access to this repo", :error
        end
      end

      def pull_request_comments(pull_request)
        connection.repos.pull_requests.comments.all(remote_user, remote_repo_name, pull_request.id)
      end

      def has_pull_request_comments?(pull_request)
        pull_request_comments(pull_request).count > 0
      end

      def get_build_status sha
        # BitBucket does not currently support build status via API
        # for updates: https://bitbucket.org/site/master/issue/8548/better-ci-integration-add-a-build-status
        return nil
      end

      def colorized_build_description status
        ""
      end

      def reviewers(pull_request)
        return "" unless pull_request.respond_to?(:reviewers) and pull_request.reviewers.size > 0
        pull_request.participants.map {|p| p.user.username }
      end

      def reviewers_pending_response(pull_request)
        reviewers - approvals
      end

      def approvals(pull_request)
        pull_request.participants.map {|p| p.user.username if p.approved }.compact
      end

    end
  end
end
