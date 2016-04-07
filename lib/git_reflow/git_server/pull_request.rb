module GitReflow
  module GitServer
    class PullRequest
      attr_accessor :description, :html_url, :feature_branch_name, :base_branch_name, :build_status, :source_object, :number

      LGTM_REGEX = /(?i-mx:lgtm|looks good to me|[:\\+1:]|:thumbsup:|:shipit:)/

      def self.num_lgtm
        "#{GitReflow::Config.get('constants.numlgtm')}".length > 0 ? "#{GitReflow::Config.get('constants.numlgtm')}" : ""
      end

      def self.lgtm_regex
        "#{GitReflow::Config.get('constants.lgtmregex')}".length > 0 ? Regexp.new("#{GitReflow::Config.get('constants.lgtmregex')}") : LGTM_REGEX
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
        raise "#{self.class.to_s}#last_comment_for method must be implemented"
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

      def enough_approvals?
        # Approvals from every commentor
        if self.class.num_lgtm == ''
          reviewers_pending_response.empty?
        else
          approvals.size >= self.class.num_lgtm.to_i and !last_comment.match(self.class.lgtm_regex).nil?

        end
      end

      def check_approvals
        has_comments_or_approvals = (has_comments? or approvals.any?)

        case PullRequest.num_lgtm
        when "0"
          true
        when "", nil
          has_comments_or_approvals && reviewers_pending_response.empty?
        else
          enough_approvals? 
        end
      end

      def good_to_merge?(force: false)
        return true if force

        (build_status.nil? or build_status == "success") and check_approvals
      end

      def display_pull_request_summary
        summary_data = {
          "branches"    => "#{self.feature_branch_name} -> #{self.base_branch_name}",
          "number"      => self.number,
          "url"         => self.html_url
        }

        notices = ""
        reviewed_by = []

        # check for CI build status
        if self.build_status
          notices << "[notice] Your build status is not successful: #{self.build.url}.\n" unless self.build.state == "success"
          summary_data.merge!( "Build status" => GitReflow.git_server.colorized_build_description(self.build.state, self.build.description) )
        end

        # check for needed lgtm's
        if self.reviewers.any?
          reviewed_by = self.reviewers.map {|author| author.colorize(:red) }
          summary_data.merge!("Last comment"  => self.last_comment)

          if self.approvals.any?
            reviewed_by.map! { |author| approvals.include?(author.uncolorize) ? author.colorize(:green) : author }
          end

          notices << "[notice] You still need a LGTM from: #{reviewers_pending_response.join(', ')}\n" if reviewers_pending_response.any?
        else
          notices << "[notice] No one has reviewed your pull request.\n"
        end

        summary_data['reviewed by'] = reviewed_by.join(', ')

        padding_size = summary_data.keys.max_by(&:size).size + 2
        summary_data.keys.sort.each do |name|
          string_format = "    %-#{padding_size}s %s\n"
          printf string_format, "#{name}:", summary_data[name]
        end

        puts "\n#{notices}" unless notices.empty?
      end

      def method_missing(method_sym, *arguments, &block)
        if source_object and source_object.respond_to? method_sym
          source_object.send method_sym
        else
          super
        end
      end
    end
  end
end
