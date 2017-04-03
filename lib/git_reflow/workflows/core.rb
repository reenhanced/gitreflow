$: << File.expand_path(File.dirname(File.realpath(__FILE__)) + '/../..')
require 'git_reflow/workflow'

module GitReflow
  module Workflows
    # This class contains the core workflow for git-reflow. Going forward, this
    # will act as the base class for customizing and extending git-reflow.
    class Core < Thor
      include Thor::Actions
      include Thor::Shell::Color
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
          say "We'll walk you through setting up git-reflow's defaults for all your projects."
          say "In the future, you can run \`git-reflow setup\` from the root of any project you want to setup differently."
          say "To adjust these settings globally, you can run \`git-reflow setup --global\`."
          GitReflow.run "touch #{GitReflow::Config::CONFIG_FILE_PATH}"
          say_status :info, "Created #{GitReflow::Config::CONFIG_FILE_PATH} for git-reflow specific configurations.", :yellow
          GitReflow::Config.add "include.path", GitReflow::Config::CONFIG_FILE_PATH, global: true
          say_status :info, "Added #{GitReflow::Config::CONFIG_FILE_PATH} to include.path in $HOME/.gitconfig.", :yellow
        end

        say "Available remote Git Server services"
        selected_server = ask("Which service would you like to use for this project?", limited_to: ["github", "bitbucket"])

        case selected_server
        when /github/i
          GitReflow::GitServer.connect reflow_options.merge({ provider: 'GitHub', silent: false })
        when /bitbucket/i
          GitReflow::GitServer.connect reflow_options.merge({ provider: 'BitBucket', silent: false })
        end

        GitReflow::Config.set "constants.minimumApprovals", ask("Set the minimum number of approvals (leaving blank will require approval from all commenters): "), local: reflow_options[:project_only]
        GitReflow::Config.set "constants.approvalRegex", GitReflow::GitServer::PullRequest::DEFAULT_APPROVAL_REGEX, local: reflow_options[:project_only]

        if GitReflow::Config.get('core.editor').length <= 0
          GitReflow::Config.set('core.editor', GitReflow.default_editor, local: reflow_options[:project_only])
          say_status :info, "Updated git's editor (via git config key 'core.editor') to: #{GitReflow.default_editor}.", :yellow
        end
      end

      # Start a new feature branch
      #
      # @param feature_branch [String] the name of the branch to create your feature on
      # @option base [String] the name of the base branch you want to checkout your feature from
      command(:start, defaults: {base: 'master'}) do |**params|
        base_branch    = params[:base]
        feature_branch = params[:feature_branch]

        if feature_branch.nil? or feature_branch.length <= 0
          GitReflow.say "usage: git-reflow start [new-branch-name]", :error
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
      command(:review, defaults: {base: 'master'}) do |**params|
        base_branch         = params[:base]
        create_pull_request = true

        GitReflow.fetch_destination base_branch
        begin
          GitReflow.push_current_branch

          existing_pull_request = GitReflow.git_server.find_open_pull_request( from: GitReflow.current_branch, to: base_branch )
          if existing_pull_request
            say "A pull request already exists for these branches:", :notice
            existing_pull_request.display_pull_request_summary
          else
            unless params[:title] || params[:body]
              pull_request_msg_file = "#{GitReflow.git_root_dir}/.git/GIT_REFLOW_PR_MSG"

              File.open(pull_request_msg_file, 'w') do |file|
                file.write(params[:title] || GitReflow.pull_request_template || GitReflow.current_branch)
              end

              GitReflow.run("#{GitReflow.git_editor_command} #{pull_request_msg_file}", with_system: true)

              pr_msg = File.read(pull_request_msg_file).split(/[\r\n]|\r\n/).map(&:strip)
              title  = pr_msg.shift

              File.delete(pull_request_msg_file)

              unless pr_msg.empty?
                pr_msg.shift if pr_msg.first.empty?
              end

              params[:title] = title
              params[:body]  = "#{pr_msg.join("\n")}\n"

              say "\nReview your PR:\n"
              say "--------\n"
              say "Title:\n#{params[:title]}\n\n"
              say "Body:\n#{params[:body]}\n"
              say "--------\n"

              create_pull_request = ask("Submit pull request? (Y)") =~ /y/i
            end

            if create_pull_request
              pull_request = GitReflow.git_server.create_pull_request(title: params[:title] || params[:body],
                                                            body:  params[:body],
                                                            head:  "#{GitReflow.remote_user}:#{GitReflow.current_branch}",
                                                            base:  params[:base])

              say "Successfully created pull request ##{pull_request.number}: #{pull_request.title}\nPull Request URL: #{pull_request.html_url}\n", :success
            else
              say "Review aborted.  No pull request has been created.", :review_halted
            end
          end
        rescue Github::Error::UnprocessableEntity => e
          say "Github Error: #{e.to_s}", :error
        rescue StandardError => e
          say "\nError: #{e.inspect}", :error
        end
      end

      # Checks the status of an existing pull request
      #
      # @option destination_branch [String] the branch you're merging your feature into ('master' is default)
      command(:status, defaults: {destination_branch: 'master'}) do |**params|
        pull_request = GitReflow.git_server.find_open_pull_request( :from => GitReflow.current_branch, :to => params[:destination_branch] )

        if pull_request.nil?
          say "No pull request exists for #{GitReflow.current_branch} -> #{params[:destination_branch]}", :notice
          say "Run 'git reflow review #{params[:destination_branch]}' to start the review process", :notice
        else
          say "Here's the status of your review:"
          pull_request.display_pull_request_summary
        end
      end

      command(:deploy) do |**params|
        destination_server = params[:destination_server] || 'default'
        deploy_command = GitReflow::Config.get("reflow.deploy-to-#{destination_server}-command", local: true)

        # first check is to allow for automated setup
        if deploy_command.empty?
          deploy_command = ask("Enter the command you use to deploy to #{destination_server} (leaving blank will skip deployment)")
        end

        # second check is to see if the user wants to skip
        if deploy_command.empty?
          say "Skipping deployment..."
          false
        else
          GitReflow::Config.set("reflow.deploy-to-#{destination_server}-command", deploy_command, local: true)
          run_command_with_label(deploy_command, with_system: true)
        end
      end

      # Merge and deploy a feature branch to a staging branch
      command(:stage) do |**params|
        feature_branch_name = GitReflow.current_branch
        staging_branch_name = GitReflow::Config.get('reflow.staging-branch', local: true)

        if staging_branch_name.empty?
          staging_branch_name = GitReflow.ask("What's the name of your staging branch? (default: 'staging') ")
          staging_branch_name = 'staging' if staging_branch_name.strip == ''
          GitReflow::Config.set('reflow.staging-branch', staging_branch_name, local: true)
        end

        GitReflow.run_command_with_label "git checkout #{staging_branch_name}"
        GitReflow.run_command_with_label "git pull origin #{staging_branch_name}"

        if GitReflow.run_command_with_label "git merge #{feature_branch_name}", with_system: true
          GitReflow.run_command_with_label "git push origin #{staging_branch_name}"

          staged = self.deploy(destination_server: :staging)

          if staged
            GitReflow.say "Deployed to Staging.", :success
          else
            GitReflow.say "There were issues deploying to staging.", :error
          end
        else
          GitReflow.say "There were issues merging your feature branch to staging.", :error
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
            say "No pull request exists for #{GitReflow.remote_user}:#{GitReflow.current_branch}\nPlease submit your branch for review first with \`git reflow review\`", :deliver_halted
          else

            if existing_pull_request.good_to_merge?(force: params[:force])
              # displays current status and prompts user for confirmation
              self.status destination_branch: params[:base]
              # TODO: change name of this in the merge! method
              params[:skip_lgtm] = params[:force] if params[:force]
              existing_pull_request.merge!(params)
            else
              say existing_pull_request.rejection_message, :deliver_halted
            end

          end

        rescue Github::Error::UnprocessableEntity => e
          say "Github Error: #{e.inspect}", :error
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
