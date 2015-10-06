require 'git_reflow/git_server/pull_request'

module GitReflow
  module GitServer
    class GitHub
      class PullRequest < GitReflow::GitServer::PullRequest
        def initialize(attributes)
          self.number              = attributes.number
          self.description         = attributes[:body]
          self.html_url            = attributes.html_url
          self.feature_branch_name = attributes.head.label
          self.base_branch_name    = attributes.base.label
          self.source_object       = attributes
          self.build_status        = build.state
        end

        def self.create(options = {})
          self.new(GitReflow.git_server.connection.pull_requests.create(
            GitReflow.git_server.class.remote_user,
            GitReflow.git_server.class.remote_repo_name,
            title: options[:title],
            body:  options[:body],
            head:  "#{GitReflow.git_server.class.remote_user}:#{GitReflow.git_server.class.current_branch}",
            base:  options[:base]))
        end

        def self.find_open(to: 'master', from: GitReflow.git_server.class.current_branch)
          matching_pull = GitReflow.git_server.connection.pull_requests.all(GitReflow.git_server.class.remote_user, GitReflow.git_server.class.remote_repo_name, base: to, head: "#{GitReflow.git_server.class.remote_user}:#{from}", state: 'open').first
          if matching_pull
            self.new matching_pull
          end
        end

        # override attr_reader for auto-updates
        def build_status
          @build_status ||= build.state
        end

        def commit_author
          begin
            username, branch = base.label.split(':')
            first_commit = GitReflow.git_server.connection.pull_requests.commits(username, GitReflow.git_server.class.remote_repo_name, number.to_s).first
            "#{first_commit.commit.author.name} <#{first_commit.commit.author.email}>".strip
          rescue Github::Error::NotFound
            nil
          end
        end

        def reviewers
          comment_authors
        end

        def approvals
          pull_last_committed_at = get_commited_time(self.head.sha)
          comment_authors(with: LGTM, after: pull_last_committed_at)
        end

        def comments
          comments        = GitReflow.git_server.connection.issues.comments.all        GitReflow.git_server.class.remote_user, GitReflow.git_server.class.remote_repo_name, number: self.number
          review_comments = GitReflow.git_server.connection.pull_requests.comments.all GitReflow.git_server.class.remote_user, GitReflow.git_server.class.remote_repo_name, number: self.number

          review_comments.to_a + comments.to_a
        end

        def last_comment
          "#{comments.last.body.inspect}"
        end

        def build
          github_build_status = GitReflow.git_server.get_build_status(self.head.sha)
          build_status_object = Struct.new(:state, :description, :url)
          if github_build_status
            build_status_object.new(
              github_build_status.state,
              github_build_status.description,
              github_build_status.target_url
            )
          else
            build_status_object.new
          end
        end

        private

        def comment_authors(with: nil, after: nil)
          comment_authors = []

          comments.each do |comment|
            next if after and Time.parse(comment.created_at) < after
            if (with.nil? or comment[:body] =~ with)
              comment_authors |= [comment.user.login]
            end
          end

          # remove the current user from the list to check
          comment_authors -= [self.head.user.login]
          comment_authors.uniq
        end

        def get_commited_time(commit_sha)
          last_commit = GitReflow.git_server.connection.repos.commits.find GitReflow.git_server.class.remote_user, GitReflow.git_server.class.remote_repo_name, commit_sha
          Time.parse last_commit.commit.author[:date]
        end

      end
    end
  end
end
