module GitReflow
  module GitServer
    class PullRequest
      attr_accessor :description, :html_url, :feature_branch_name, :base_branch_name, :build, :source_object, :number

      DEFAULT_APPROVAL_REGEX = /(?i-mx:lgtm|looks good to me|:\+1:|:thumbsup:|:shipit:)/

      class Build
        attr_accessor :state, :description, :url

        def initialize(state: nil, description: nil, url: nil)
          self.state       = state
          self.description = description
          self.url         = url
        end
      end

      def self.minimum_approvals
        "#{GitReflow::Config.get('constants.minimumApprovals')}"
      end

      def self.approval_regex
        if "#{GitReflow::Config.get('constants.approvalRegex')}".length > 0
          Regexp.new("#{GitReflow::Config.get('constants.approvalRegex')}")
        else
          DEFAULT_APPROVAL_REGEX
        end
      end

      def initialize(attributes)
        raise "PullRequest#initialize must be implemented"
      end

      def commit_author
        raise "#{self.class.to_s}#commit_author method must be implemented"
      end

      def comments
        raise "#{self.class.to_s}#comments method must be implemented"
      end

      def has_comments?
        comments.count > 0
      end

      def last_comment
        raise "#{self.class.to_s}#last_comment method must be implemented"
      end

      def reviewers
        raise "#{self.class.to_s}#reviewers method must be implemented"
      end

      def approvals
        raise "#{self.class.to_s}#approvals method must be implemented"
      end

      def reviewers_pending_response
        reviewers - approvals
      end

      def approved?
        has_comments_or_approvals = (has_comments? or approvals.any?)

        case self.class.minimum_approvals
        when "0"
          true
        when "", nil
          # Approvals from every commenter
          has_comments_or_approvals && reviewers_pending_response.empty?
        else
          approvals.size >= self.class.minimum_approvals.to_i
        end
      end

      def build_status
        build.nil? ? nil : build.state
      end

      def rejection_message
        if !build_status.nil? and build_status != "success"
          "#{build.description}: #{build.url}"
        elsif !approval_minimums_reached?
          "You need approval from at least #{self.class.minimum_approvals} users!"
        elsif !all_comments_addressed?
          # Maybe add what the last comment is?
          "The last comment is holding up approval:\n#{last_comment}"
        elsif reviewers_pending_response.count > 0
          "You still need a LGTM from: #{reviewers_pending_response.join(', ')}"
        else
          "Your code has not been reviewed yet."
        end
      end

      def approval_minimums_reached?
        self.class.minimum_approvals.length <= 0 or approvals.size >= self.class.minimum_approvals.to_i
      end

      def all_comments_addressed?
        self.class.minimum_approvals.length <= 0 or !last_comment.match(self.class.approval_regex).nil?
      end

      def good_to_merge?(force: false)
        return true if force

        (build_status.nil? or build_status == "success") and approved?
      end

      def display_pull_request_summary
        summary_data = {
          "branches"    => "#{self.feature_branch_name} -> #{self.base_branch_name}",
          "number"      => self.number,
          "url"         => self.html_url
        }

        notices = []
        reviewed_by = []

        # check for CI build status
        if self.build_status
          notices << "Your build status is not successful: #{self.build.url}.\n" unless self.build.state == "success"
          summary_data.merge!( "Build status" => GitReflow.git_server.colorized_build_description(self.build.state, self.build.description) )
        end

        # check for needed lgtm's
        if self.reviewers.any?
          reviewed_by = self.reviewers.map {|author| author.colorize(:red) }
          summary_data.merge!("Last comment"  => self.last_comment)

          if self.approvals.any?
            reviewed_by.map! { |author| approvals.include?(author.uncolorize) ? author.colorize(:green) : author }
          end

          notices << "You still need a LGTM from: #{reviewers_pending_response.join(', ')}\n" if reviewers_pending_response.any?
        else
          notices << "No one has reviewed your pull request.\n"
        end

        summary_data['reviewed by'] = reviewed_by.join(', ')

        padding_size = summary_data.keys.max_by(&:size).size + 2
        summary_data.keys.sort.each do |name|
          string_format = "    %-#{padding_size}s %s\n"
          printf string_format, "#{name}:", summary_data[name]
        end

        notices.each do |notice|
          GitReflow.say notice, :notice
        end
      end

      def method_missing(method_sym, *arguments, &block)
        if source_object and source_object.respond_to? method_sym
          source_object.send method_sym
        else
          super
        end
      end

      def commit_message_for_merge
        message = ""

        if "#{self.description}".length > 0
          message << "#{self.description}"
        else
          message << "#{GitReflow.get_first_commit_message}"
        end

        message << "\nMerges ##{self.number}\n"

        if lgtm_authors = Array(self.approvals) and lgtm_authors.any?
          message << "\nLGTM given by: @#{lgtm_authors.join(', @')}\n"
        end

        "#{message}\n"
      end

      def cleanup_feature_branch?
        GitReflow::Config.get('reflow.always-cleanup') == "true" || (ask "Would you like to push this branch to your remote repo and cleanup your feature branch? ") =~ /^y/i
      end

      def deliver?
        GitReflow::Config.get('reflow.always-deliver') == "true" || (ask "This is the current status of your Pull Request. Are you sure you want to deliver? ") =~ /^y/i
      end

      def cleanup_failure_message
        GitReflow.say "Cleanup halted.  Local changes were not pushed to remote repo.", :deliver_halted
        GitReflow.say "To reset and go back to your branch run \`git reset --hard origin/#{self.base_branch_name} && git checkout #{self.feature_branch_name}\`"
      end

      def merge!(options = {})
        if deliver?

          GitReflow.say "Merging pull request ##{self.number}: '#{self.title}', from '#{self.feature_branch_name}' into '#{self.base_branch_name}'", :notice

          GitReflow.update_current_branch
          GitReflow.fetch_destination(self.base_branch_name)

          message      = commit_message_for_merge
          merge_method = options[:merge_method] || GitReflow::Config.get("reflow.merge-method")
          merge_method = "squash" if "#{merge_method}".length < 1


          GitReflow.run_command_with_label "git checkout #{self.base_branch_name}"
          GitReflow.run_command_with_label "git pull origin #{self.base_branch_name}"

          case merge_method
          when /squash/i
            GitReflow.run_command_with_label "git merge --squash #{self.feature_branch_name}"
          else
            GitReflow.run_command_with_label "git merge #{self.feature_branch_name}"
          end

          GitReflow.append_to_squashed_commit_message(message) if message.length > 0

          if GitReflow.run_command_with_label 'git commit', with_system: true
            GitReflow.say "Pull request ##{self.number} successfully merged.", :success

            if cleanup_feature_branch?
              GitReflow.run_command_with_label "git push origin #{self.base_branch_name}"
              GitReflow.run_command_with_label "git push origin :#{self.feature_branch_name}"
              GitReflow.run_command_with_label "git branch -D #{self.feature_branch_name}"
              GitReflow.say "Nice job buddy."
            else
              cleanup_failure_message
            end
          else
            GitReflow.say "There were problems commiting your feature... please check the errors above and try again.", :error
          end
        else
          GitReflow.say "Merge aborted", :deliver_halted
        end
      end
    end
  end
end
