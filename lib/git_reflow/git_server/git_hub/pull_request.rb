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
          pull_last_committed_at = get_committed_time(self.head.sha)
          comment_authors(with: self.class.approval_regex, after: pull_last_committed_at)
        end

        def comments
          comments        = GitReflow.git_server.connection.issues.comments.all        GitReflow.git_server.class.remote_user, GitReflow.git_server.class.remote_repo_name, number: self.number
          review_comments = GitReflow.git_server.connection.pull_requests.comments.all GitReflow.git_server.class.remote_user, GitReflow.git_server.class.remote_repo_name, number: self.number

          review_comments.to_a + comments.to_a
        end

        def last_comment
          if comments.last.nil?
            ""
          else
            "#{comments.last.body.inspect}"
          end
        end

        def approved?
          if self.class.minimum_approvals.to_i == 0
            super
          else
            approvals.size >= self.class.minimum_approvals.to_i and !last_comment.match(self.class.approval_regex).nil?
          end
        end

        def merge!(options = {})
           
          # fallback to default merge process if user "forces" merge
          if(options[:skip_lgtm])
            super options
          else
            if deliver?
              GitReflow.say "Merging pull request ##{number}: '#{title}', from '#{feature_branch_name}' into '#{base_branch_name}'", :notice

              unless options[:title] || options[:message]

                # prompts user for commit_title and commit_message
                pull_request_msg_file = "#{GitReflow.git_root_dir}/.git/SQUASH_MSG"

                File.open(pull_request_msg_file, 'w') do |file|
                  file.write("#{self.title}\n#{self.body}\n")
                end

                GitReflow.run("#{GitReflow::DEFAULT_EDITOR} #{pull_request_msg_file}", with_system: true)
                pr_msg = File.read(pull_request_msg_file).split(/[\r\n]|\r\n/).map(&:strip)
        
                title  = pr_msg.shift

                File.delete(pull_request_msg_file)

                unless pr_msg.empty? 
                  pr_msg.shift if pr_msg.first.empty?
                end

                options[:title] = title
                options[:body]  = "#{pr_msg.join("\n")}\n"

                GitReflow.say "\nReview your PR:\n"
                GitReflow.say "--------\n"
                GitReflow.say "Title:\n#{options[:title]}\n\n"
                GitReflow.say "Body:\n#{options[:body]}\n"
                GitReflow.say "--------\n"

                create_pull_request = ask("Submit pull request? (Y)") =~ /y/i
              end

              message = self.commit_message_for_merge

              merge_response = GitReflow::GitServer::GitHub.connection.pull_requests.merge(
                "#{GitReflow.git_server.class.remote_user}", 
                "#{GitReflow.git_server.class.remote_repo_name}", 
                "#{self.number}", 
                {
                  "commit_title" => "#{options[:title]}",
                  "commit_message" => "#{options[:body]}",
                  "sha" => "#{self.head.sha}",
                  "squash" => true
                }
              )

              if merge_response.success?
                GitReflow.run_command_with_label "git checkout #{base_branch_name}"
                # Pulls merged changes from remote base_branch
                GitReflow.run_command_with_label "git pull origin #{base_branch_name}"
                GitReflow.say "Pull Request successfully merged.", :success

                if cleanup_feature_branch?
                  GitReflow.run_command_with_label "git push origin :#{feature_branch_name}"
                  GitReflow.run_command_with_label "git branch -D #{feature_branch_name}"
                  GitReflow.say "Nice job buddy."
                else
                  cleanup_failure_message
                end
              else
                GitReflow.say merge_response.to_s, :deliver_halted
                GitReflow.say "There were problems commiting your feature... please check the errors above and try again.", :error
              end
            else
              GitReflow.say "Merge aborted", :deliver_halted
            end
          end
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
          comment_authors -= [self.user.login]
          comment_authors.uniq
        end

        def get_committed_time(commit_sha)
          last_commit = GitReflow.git_server.connection.repos.commits.find GitReflow.git_server.class.remote_user, GitReflow.git_server.class.remote_repo_name, commit_sha
          Time.parse last_commit.commit.author[:date]
        end

      end
    end
  end
end
