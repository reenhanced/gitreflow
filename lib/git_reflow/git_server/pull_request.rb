module GitReflow
  module GitServer
    class PullRequest
      attr_accessor :description, :html_url, :feature_branch_name, :base_branch_name, :build_status, :source_object, :number

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

      def good_to_merge?(force: false)
        return true if force
        has_comments_or_approvals = (has_comments? or approvals.any?)
        build_status              = GitReflow.git_server.get_build_status self.build_status

        force == true or (
          (build_status.nil? or build_status.state == "success") and
          (has_comments_or_approvals and reviewers_pending_response.empty?))
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
