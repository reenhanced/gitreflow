require 'bitbucket_rest_api'
require 'git_reflow/git_helpers'

module GitReflow
  module GitServer
    class BitBucket < Base
      include GitHelpers

      attr_accessor :connection

      @project_only     = false
      @git_config_group = 'bitbucket'.freeze

      def initialize(config_options = {})
        @project_only     = !!config_options.delete(:project_only)

        bb_site_url     = self.class.site_url
        bb_api_endpoint = self.class.api_endpoint
        
        self.class.site_url     = bb_site_url
        self.class.api_endpoint = bb_api_endpoint

        if @project_only
          GitReflow::Config.set('reflow.git-server', 'BitBucket', local: true)
        else
          GitReflow::Config.set('reflow.git-server', 'BitBucket')
        end
      end

      def authenticate(options = {silent: false})
        @connection
      end

      def self.connection
        @connection
      end

    end
  end
end
