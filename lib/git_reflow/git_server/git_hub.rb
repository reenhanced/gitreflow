require 'github_api'
require 'git_reflow/git_helpers'

module GitReflow
  module GitServer
    class GitHub < Base
      extend GitHelpers
      include Sandbox

      class PullRequest < Base::PullRequest
        def initialize(attributes)
          self.description         = attributes.body
          self.html_url            = attributes.html_url
          self.feature_branch_name = attributes.head.label
          self.base_branch_name    = attributes.base.label
          self.build_status        = attributes.head.sha
          self.source_object       = attributes
        end
      end

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

        if project_only
          GitReflow::Config.add('reflow.local-projects', "#{self.class.remote_user}/#{self.class.remote_repo_name}")
          GitReflow::Config.set('reflow.git-server', 'GitHub', local: true)
        else
          GitReflow::Config.unset('reflow.local-projects', value: "#{self.class.remote_user}/#{self.class.remote_repo_name}")
          GitReflow::Config.set('reflow.git-server', 'GitHub')
        end
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
            puts "Your GitHub account was already setup with: "
            puts "\tUser Name: #{self.class.user}"
            puts "\tEndpoint: #{self.class.api_endpoint}"
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
              config.ssl        = {:verify => false}
            end

            @connection.connection_options = {headers: {"X-GitHub-OTP" => options[:two_factor_auth_code]}} if options[:two_factor_auth_code]

            previous_authorizations = @connection.oauth.all.select {|auth| auth.note == "git-reflow (#{run('hostname', loud: false).strip})" }
            if previous_authorizations.any?
              authorization = previous_authorizations.last
            else
              authorization = @connection.oauth.create scopes: ['repo'], note: "git-reflow (#{run('hostname', loud: false).strip})"
            end

            self.class.oauth_token = authorization.token

          rescue ::Github::Error::Unauthorized => e
            if e.inspect.to_s.include?('two-factor')
              two_factor_code = ask("Please enter your two-factor authentication code: ")
              self.authenticate options.merge({user: gh_user, password: gh_password, two_factor_auth_code: two_factor_code})
            else
              puts "\nGithub Authentication Error: #{e.inspect}"
            end
          rescue StandardError => e
            puts "\nInvalid username or password: #{e.inspect}"
          else
            puts "\nYour GitHub account was successfully setup!"
          end
        end

        @connection
      end

      def create_pull_request(options = {})
        pull_request = connection.pull_requests.create(self.class.remote_user, self.class.remote_repo_name,
                                                       title: options[:title],
                                                       body:  options[:body],
                                                       head:  "#{self.class.remote_user}:#{self.class.current_branch}",
                                                       base:  options[:base])
      end

      def find_open_pull_request(options = {})
        matching_pull = connection.pull_requests.all(self.class.remote_user, self.class.remote_repo_name, base: options[:to], head: "#{self.class.remote_user}:#{options[:from]}", :state => 'open').first
        if matching_pull
          PullRequest.new matching_pull
        end
      end

      def reviewers(pull_request)
        comment_authors_for_pull_request(pull_request)
      end

      def approvals(pull_request)
        pull_last_committed_at = get_commited_time(pull_request.head.sha)
        lgtm_authors           = comment_authors_for_pull_request(pull_request, :with => LGTM, :after => pull_last_committed_at)
      end

      def pull_request_comments(pull_request)
        comments        = connection.issues.comments.all        self.class.remote_user, self.class.remote_repo_name, number: pull_request.number
        review_comments = connection.pull_requests.comments.all self.class.remote_user, self.class.remote_repo_name, number: pull_request.number

        review_comments.to_a + comments.to_a
      end

      def last_comment_for_pull_request(pull_request)
        "#{pull_request_comments(pull_request).last.body.inspect}"
      end

      def get_build_status sha
        connection.repos.statuses.all(self.class.remote_user, self.class.remote_repo_name, sha).first
      end

      def colorized_build_description status
        colorized_statuses = { pending: :yellow, success: :green, error: :red, failure: :red }
        status.description.colorize( colorized_statuses[status.state.to_sym] )
      end

      def comment_authors_for_pull_request(pull_request, options = {})
        all_comments    = pull_request_comments(pull_request)
        comment_authors = []

        all_comments.each do |comment|
          next if options[:after] and Time.parse(comment.created_at) < options[:after]
          if (options[:with].nil? or comment[:body] =~ options[:with])
            comment_authors |= [comment.user.login]
          end
        end

        # remove the current user from the list to check
        comment_authors -= [self.class.user]
        comment_authors.uniq
      end

      def get_commited_time(commit_sha)
        last_commit = connection.repos.commits.find self.class.remote_user, self.class.remote_repo_name, commit_sha
        Time.parse last_commit.commit.author[:date]
      end

    end
  end
end
