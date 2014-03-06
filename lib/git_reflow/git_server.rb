module GitReflow
  module GitServer
    autoload :Base, 'git_reflow/git_server/base'
    autoload :GitHub,     'git_reflow/git_server/git_hub'

    def self.connection
      if git_server_type = GitReflow::Config.get('reflow.git-server').present?
        return "GitServer type not setup for: #{git_server_type}" unless GitReflow::GitServer.const_defined?(git_server_type)
        GitReflow::GitServer.const_get(git_server_type).connection
      else
        puts "[notice] Reflow hasn't been setup yet.  Run 'git reflow setup' to continue"
      end
    end
  end
end
