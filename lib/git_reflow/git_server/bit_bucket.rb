require 'bitbucket_rest_api'
require 'git_reflow/git_helpers'

module GitReflow
  module GitServer
    class BitBucket < Base
      include GitHelpers

      class PullRequest < Base::PullRequest
        def initialize(attributes)
          self.source_object       = attributes
          self.number              = attributes.id
          self.html_url            = "#{attributes.source.repository.links.html.href}/pull-request/#{self.number}"
          self.feature_branch_name = attributes.source.branch.name
          self.base_branch_name    = attributes.destination.branch.name
          self.build_status        = nil
        end
      end

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

      def self.connection
        if api_key_setup?
          @connection ||= ::BitBucket.new login: self.new.remote_user, password: api_key
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

      def self.api_key
        GitReflow::Config.get("bitbucket.api-key")
      end

      def self.api_key=(key)
        GitReflow::Config.get("bitbucket.api-key", key, local: @@project_only)
      end
      def self.api_key_setup?
        (self.api_key.length > 0)
      end

      def self.user
        GitReflow::Config.get('bitbucket.user')
      end

      def self.user=(bitbucket_user)
        GitReflow::Config.set('bitbucket.user', bitbucket_user, local: @@project_only)
      end

      def authenticate(options = {silent: false})
        begin
          if connection and self.class.api_key_setup?
            unless options[:silent]
              puts "\nYour BitBucket account was already setup with:"
              puts "\tUser Name: #{self.class.user}"
            end
          else
            self.class.user = options[:user] || ask("Please enter your BitBucket username: ")
            puts "\nIn order to connect your BitBucket account,"
            puts "you'll need to generate an API key for your Team"
            puts "\nVisit #{self.class.site_url}/account/user/#{remote_user}/api-key, and reference our README"
          end
        rescue ::BitBucket::Error::Unauthorized => e
          puts "\nBitBucket Authentication Error: #{e.inspect}"
        end
      end

      def connection
        @connection ||= self.class.connection
      end

      def create_pull_request(options = {})
        PullRequest.new connection.repos.pull_requests.create(remote_user, remote_repo_name,
                                                              title: options[:title],
                                                              body: options[:body],
                                                              source: {
                                                                branch: { name: current_branch },
                                                                repository: { full_name: "#{remote_user}/#{remote_repo_name}" }
                                                              },
                                                              destination: {
                                                                branch: { name: options[:base] }
                                                              },
                                                              reviewers: [username: self.class.user])
      end

      def find_open_pull_request(options = {})
        begin
          matching_pull = connection.repos.pull_requests.all(remote_user, remote_repo_name, limit: 1).select do |pr|
            pr.source.branch.name == options[:from] and
            pr.destination.branch.name == options[:to]
          end.first

          if matching_pull
            PullRequest.new matching_pull
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

      def last_comment_for_pull_request(pull_request)
        last_comment = pull_request_comments(pull_request).first
        return "" unless last_comment
        "#{pull_request_comments(pull_request).first.content.raw}"
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
        comments = pull_request_comments(pull_request)

        return [] unless comments.size > 0
        comments.map {|c| c.user.username } - [self.class.user]
      end

      def approvals(pull_request)
        approved  = []

        connection.repos.pull_requests.activity(remote_user, remote_repo_name, pull_request.id).each do |activity|
          break unless activity.respond_to?(:approval) and activity.approval.user.username != self.class.user
          approved |= [activity.approval.user.username]
        end

        approved
      end

    end
  end
end
