$: << File.expand_path(File.dirname(File.realpath(__FILE__)) + '/../..')
require 'git_reflow/workflow'

module GitReflow
  module Workflows
    # This class contains the core workflow for git-reflow. Going forward, this
    # will act as the base class for customizing and extending git-reflow.
    class Core < ::Thor
      include GitReflow::Workflow

      # Sets up the required git configurations that git-reflow depends on.
      #
      # @option local [Boolean] whether to configure git-reflow specific to the current project
      # @option enterprise [Boolean] whether to configure git-reflow for use with Github Enterprise
      desc "sets up your api token with GitHub"
      method_option :local,      aliases: "-l", type: :boolean, default: false, desc: "setup GitReflow for the current project only"
      method_option :enterprise, aliases: "-e", type: :boolean, default: false, desc: "setup GitReflow with a Github Enterprise account"
      def setup
        reflow_options             = { project_only: options[:local], enterprise: options[:enterprise] }
        existing_git_include_paths = GitReflow::Config.get('include.path', all: true).split("\n")

        unless File.exist?(GitReflow::Config::CONFIG_FILE_PATH) or existing_git_include_paths.include?(GitReflow::Config::CONFIG_FILE_PATH)
          GitReflow.shell.say "We'll walk you through setting up git-reflow's defaults for all your projects."
          GitReflow.shell.say "In the future, you can run \`git-reflow setup\` from the root of any project you want to setup differently."
          GitReflow.shell.say "To adjust these settings globally, you can run \`git-reflow setup --global\`."
          GitReflow.run "touch #{GitReflow::Config::CONFIG_FILE_PATH}", capture: true
          GitReflow.shell.say_status :info, "Created #{GitReflow::Config::CONFIG_FILE_PATH} for git-reflow specific configurations.", :yellow
          GitReflow::Config.add "include.path", GitReflow::Config::CONFIG_FILE_PATH, global: true
          GitReflow.shell.say_status :info, "Added #{GitReflow::Config::CONFIG_FILE_PATH} to include.path in $HOME/.gitconfig.", :yellow
        end

        GitReflow.shell.say "Available remote Git Server services"
        selected_server = GitReflow.shell.ask("Which service would you like to use for this project?", limited_to: ["github", "bitbucket"])

        case selected_server
        when /github/i
          GitReflow::GitServer.connect reflow_options.merge({ provider: 'GitHub', silent: false })
        when /bitbucket/i
          GitReflow::GitServer.connect reflow_options.merge({ provider: 'BitBucket', silent: false })
        end

        GitReflow::Config.set "constants.minimumApprovals", GitReflow.shell.ask("Set the minimum number of approvals (leaving blank will require approval from all commenters): "), local: reflow_options[:project_only]
        GitReflow::Config.set "constants.approvalRegex", GitReflow::GitServer::PullRequest::DEFAULT_APPROVAL_REGEX, local: reflow_options[:project_only]

        if GitReflow::Config.get('core.editor').length <= 0
          GitReflow::Config.set('core.editor', GitReflow.default_editor, local: reflow_options[:project_only])
          GitReflow.shell.say_status :info, "Updated git's editor (via git config key 'core.editor') to: #{GitReflow.default_editor}.", :yellow
        end
      end

      # Start a new feature branch
      #
      # @param feature_branch [String] the name of the branch to create your feature on
      # @option base [String] the name of the base branch you want to checkout your feature from
      desc "start FEATURE_BRANCH", "Creates a new feature branch and setup remote tracking"
      method_option :base, aliases: "-b", type: :string, default: "master", required: true
      def start(feature_branch)
        base_branch = options[:base]

        if feature_branch.nil? or feature_branch.length <= 0
          GitReflow.shell.say_status :info, "usage: git-reflow start [new-branch-name]", :red
        else
          GitReflow.run_command_with_label "git checkout #{base_branch}"
          GitReflow.run_command_with_label "git pull origin #{base_branch}"
          GitReflow.run_command_with_label "git push origin #{base_branch}:refs/heads/#{feature_branch}"
          GitReflow.run_command_with_label "git checkout --track -b #{feature_branch} origin/#{feature_branch}"
        end
      end

      # Submit a feature branch for review
      #
      # @option base [String] the name of the base branch you want to merge your feature into
      # @option title [String] the title of your pull request
      # @option body [String] the body of your pull request
      desc "review BASE_BRANCH", "push your latest feature branch changes to your remote repo and create a pull request against the BASE_BRANCH"
      method_option :title, aliases: "-t", type: :string
      method_option :message, aliases: "-m", type: :string
      def review(base = "master")
        base_branch         = options[:base]
        create_pull_request = true

        GitReflow.fetch_destination base_branch
        begin
          GitReflow.push_current_branch

          existing_pull_request = GitReflow.git_server.find_open_pull_request( from: GitReflow.current_branch, to: base_branch )
          if existing_pull_request
            GitReflow.shell.say_status :info, "A pull request already exists for these branches:", :yellow
            existing_pull_request.display_pull_request_summary
          else
            unless options[:title] || options[:body]
              pull_request_msg_file = "#{GitReflow.git_root_dir}/.git/GIT_REFLOW_PR_MSG"

              File.open(pull_request_msg_file, 'w') do |file|
                file.write(options[:title] || GitReflow.pull_request_template || GitReflow.current_branch)
              end

              GitReflow.run("#{GitReflow.git_editor_command} #{pull_request_msg_file}", with_system: true)

              pr_msg = File.read(pull_request_msg_file).split(/[\r\n]|\r\n/).map(&:strip)
              title  = pr_msg.shift

              File.delete(pull_request_msg_file)

              unless pr_msg.empty?
                pr_msg.shift if pr_msg.first.empty?
              end

              options[:title] = title
              options[:body]  = "#{pr_msg.join("\n")}\n"

              GitReflow.shell.say "\nReview your PR:\n"
              GitReflow.shell.say "--------\n"
              GitReflow.shell.say "Title:\n#{options[:title]}\n\n"
              GitReflow.shell.say "Body:\n#{options[:body]}\n"
              GitReflow.shell.say "--------\n"

              create_pull_request = GitReflow.shell.ask("Submit pull request? (Y)") =~ /y/i
            end

            if create_pull_request
              pull_request = GitReflow.git_server.create_pull_request(title: options[:title] || options[:body],
                                                            body:  options[:body],
                                                            head:  "#{GitReflow.remote_user}:#{GitReflow.current_branch}",
                                                            base:  options[:base])

              GitReflow.shell.say_status :info, "Successfully created pull request ##{pull_request.number}: #{pull_request.title}\nPull Request URL: #{pull_request.html_url}\n", :green
            else
              GitReflow.shell.say_status :info, "Review aborted.  No pull request has been created.", :red
            end
          end
        rescue Github::Error::UnprocessableEntity => e
          GitReflow.shell.say_status :error, "Github Error: #{e.to_s}", :red
        rescue StandardError => e
          GitReflow.shell.say_status :error, "\nError: #{e.inspect}", :red
        end
      end

      # Checks the status of an existing pull request
      #
      # @option destination_branch [String] the branch you're merging your feature into ('master' is default)
      desc "status BASE_BRANCH", "display information about the status of your feature branch against the BASE_BRANCH"
      def review(base = "master")
        pull_request = GitReflow.git_server.find_open_pull_request( :from => GitReflow.current_branch, :to => options[:base] )

        if pull_request.nil?
          GitReflow.shell.say_status :info, "No pull request exists for #{GitReflow.current_branch} -> #{options[:base]}", :yellow
          GitReflow.shell.say_status :info, "Run 'git reflow review #{options[:base]}' to start the review process", :yellow
        else
          GitReflow.shell.say "Here's the status of your review:"
          pull_request.display_pull_request_summary
        end
      end

      command(:deploy) do |**params|
        destination_server = params[:destination_server] || 'default'
        deploy_command = GitReflow::Config.get("reflow.deploy-to-#{destination_server}-command", local: true)

        # first check is to allow for automated setup
        if deploy_command.empty?
          deploy_command = GitReflow.shell.ask("Enter the command you use to deploy to #{destination_server} (leaving blank will skip deployment)")
        end

        # second check is to see if the user wants to skip
        if deploy_command.empty?
          GitReflow.shell.say "Skipping deployment..."
          false
        else
          GitReflow::Config.set("reflow.deploy-to-#{destination_server}-command", deploy_command, local: true)
          GitReflow.run_command_with_label(deploy_command, with_system: true)
        end
      end

      # Merge and deploy a feature branch to a staging branch
      command(:stage) do |**params|
        feature_branch_name = GitReflow.current_branch
        staging_branch_name = GitReflow::Config.get('reflow.staging-branch', local: true)

        if staging_branch_name.empty?
          staging_branch_name = GitReflow.shell.ask("What's the name of your staging branch? (default: 'staging') ")
          staging_branch_name = 'staging' if staging_branch_name.strip == ''
          GitReflow::Config.set('reflow.staging-branch', staging_branch_name, local: true)
        end

        GitReflow.run_command_with_label "git checkout #{staging_branch_name}"
        GitReflow.run_command_with_label "git pull origin #{staging_branch_name}"

        if GitReflow.run_command_with_label "git merge #{feature_branch_name}", with_system: true
          GitReflow.run_command_with_label "git push origin #{staging_branch_name}"

          staged = self.deploy(destination_server: :staging)

          if staged
            GitReflow.shell.say_status :info, "Deployed to Staging.", :green
          else
            GitReflow.shell.say_status :error, "There were issues deploying to staging.", :red
          end
        else
          GitReflow.shell.say_status :error, "There were issues merging your feature branch to staging.", :red
        end
      end

      # Deliver a feature branch to a base branch
      #
      # @option base [String] base branch to merge your feature branch into
      # @option force [Boolean] whether to force-deliver the feature branch, ignoring any QA checks
      command(:deliver, defaults: {base: 'master'}) do |**params|
        begin
          existing_pull_request = GitReflow.git_server.find_open_pull_request( from: GitReflow.current_branch, to: params[:base] )

          if existing_pull_request.nil?
            GitReflow.shell.say_status :info, "No pull request exists for #{GitReflow.remote_user}:#{GitReflow.current_branch}\nPlease submit your branch for review first with \`git reflow review\`", :red
          else

            if existing_pull_request.good_to_merge?(force: params[:force])
              # displays current status and prompts user for confirmation
              self.status destination_branch: params[:base]
              # TODO: change name of this in the merge! method
              params[:skip_lgtm] = params[:force] if params[:force]
              existing_pull_request.merge!(params)
            else
              GitReflow.shell.say_status :info, existing_pull_request.rejection_message, :red
            end

          end

        rescue Github::Error::UnprocessableEntity => e
          GitReflow.shell.say_status :error, "Github Error: #{e.inspect}", :red
        end
      end


      # Updates and synchronizes your base branch and feature branch.
      # 
      # Performs the following:
      #   $ git checkout <base_branch>
      #   $ git pull <remote_location> <base_branch>
      #   $ git checkout <current_branch>
      #   $ git pull origin <current_branch>
      #   $ git merge <base_branch>
      # @param remote [String] the name of the remote repository to fetch updates from (origin by default)
      # @param base [String] the branch that you want to fetch updates from (master by default)
      command(:refresh, defaults: {remote: 'origin', base: 'master'}) do |**params|
        GitReflow.update_feature_branch(params)
      end
    end
  end
end
