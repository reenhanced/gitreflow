module GitReflow
  module GitServer
    class MergeError < StandardError
      def initialize(msg="Merge failed")
        super(msg)
      end
    end
  end
end
