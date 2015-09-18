require 'git_reflow/git_server/pull_request'

module GitReflow
  module GitServer
    class BitBucket
      class PullRequest < GitReflow::GitServer::PullRequest
        def initialize(attributes)
          self.number              = attributes.id
          self.description         = attributes.description
          self.html_url            = "#{attributes.source.repository.links.html.href}/pull-request/#{self.number}"
          self.feature_branch_name = attributes.source.branch.name
          self.base_branch_name    = attributes.destination.branch.name
          self.build_status        = nil
          self.source_object       = attributes
        end

        def self.create(options = {})
          self.new GitReflow.git_server.connection.repos.pull_requests.create(
            GitReflow.git_server.class.remote_user,
            GitReflow.git_server.class.remote_repo_name,
            title: options[:title],
            body: options[:body],
            source: {
              branch: { name: GitReflow.git_server.class.current_branch },
              repository: { full_name: "#{GitReflow.git_server.class.remote_user}/#{GitReflow.git_server.class.remote_repo_name}" }
            },
            destination: {
              branch: { name: options[:base] }
            },
            reviewers: [username: GitReflow.git_server.class.user])
        end

        def self.find_open(to:, from:)
          begin
            matching_pull = connection.repos.pull_requests.all(GitReflow.git_server.class.remote_user, GitReflow.git_server.remote_repo_name, limit: 1).select do |pr|
              pr.source.branch.name == options[:from] and
              pr.destination.branch.name == options[:to]
            end.first

            if matching_pull
              self.new matching_pull
            end
          rescue ::BitBucket::Error::NotFound => e
            GitReflow.git_server.say "No BitBucket repo found for #{GitReflow.git_server.class.remote_user}/#{GitReflow.git_server.class.remote_repo_name}", :error
          rescue ::BitBucket::Error::Forbidden => e
            GitReflow.git_server.class.say "You don't have API access to this repo", :error
          end
        end


        def commit_author
          # use the author of the pull request
          self.author.username
        end

        def comments
          GitReflow.git_server.connection.repos.pull_requests.comments.all(GitReflow.git_server.class.remote_user, GitReflow.git_server.class.remote_repo_name, self.id)
        end

        def last_comment
          last_comment = comments.first
          return "" unless last_comment
          "#{last_comment.content.raw}"
        end

        def reviewers
          return [] unless comments.size > 0
          comments.map {|c| c.user.username } - [GitReflow.git_server.class.user]
        end

        def approvals
          approved  = []

          GitReflow.git_server.connection.repos.pull_requests.activity(GitReflow.git_server.class.remote_user, GitReflow.git_server.class.remote_repo_name, self.id).each do |activity|
            break unless activity.respond_to?(:approval) and activity.approval.user.username != GitReflow.git_server.class.user
            approved |= [activity.approval.user.username]
          end

          approved
        end

      end
    end
  end
end
