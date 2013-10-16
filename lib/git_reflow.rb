require 'rubygems'
require 'open-uri'
require "highline/import"
require 'httpclient'
require 'github_api'
require 'json/pure'
require 'colorize'

require 'git_reflow/version.rb' unless defined?(GitReflow::VERSION)

module GitReflow
  extend self

  LGTM = /lgtm|looks good to me|:\+1:|:thumbsup:|:shipit:/i

  def setup(options = {})
    project_only     = options.delete(:project_only)
    using_enterprise = options.delete(:enterprise)
    gh_site_url      = github_site_url
    gh_api_endpoint  = github_api_endpoint

    if using_enterprise
      gh_site_url     = ask("Please enter your Enterprise site URL (e.g. https://github.company.com):")
      gh_api_endpoint = ask("Please enter your Enterprise API endpoint (e.g. https://github.company.com/api/v3):")
    end

    if project_only
      set_github_site_url(gh_site_url, local: true)
      set_github_api_endpoint(gh_api_endpoint, local: true)
    else
      set_github_site_url(gh_site_url)
      set_github_api_endpoint(gh_api_endpoint)
    end

    gh_user     = ask("Please enter your GitHub username: ")
    gh_password = ask("Please enter your GitHub password (we do NOT store this): ") { |q| q.echo = false }

    begin

      github = Github.new do |config|
        config.basic_auth = "#{gh_user}:#{gh_password}"
        config.endpoint    = GitReflow.github_api_endpoint
        config.site        = GitReflow.github_site_url
        config.adapter     = :net_http
        config.ssl         = {:verify => false}
      end

      authorization = github.oauth.create 'scopes' => ['repo']
      oauth_token   = authorization[:token]

      if project_only
        set_oauth_token(oauth_token, local: true)
      else
        set_oauth_token(oauth_token)
      end
    rescue StandardError => e
      puts "\nInvalid username or password"
    else
      puts "\nYour GitHub account was successfully setup!"
    end
  end

  def status(destination_branch)
    pull_request = find_pull_request( :from => current_branch, :to => destination_branch )

    if pull_request.nil?
      puts "\n[notice] No pull request exists for #{current_branch} -> #{destination_branch}"
      puts "[notice] Run 'git reflow review #{destination_branch}' to start the review process"
    else
      puts "Here's the status of your review:"
      display_pull_request_summary(pull_request)
      ask_to_open_in_browser(pull_request)
    end
  end

  def review(options = {})
    options['base'] ||= 'master'
    fetch_destination options['base']

    begin
      puts push_current_branch
      pull_request = github.pull_requests.create(remote_user, remote_repo_name,
                                                 'title' => options['title'],
                                                 'body'  => options['body'],
                                                 'head'  => "#{remote_user}:#{current_branch}",
                                                 'base'  => options['base'])

      puts "Successfully created pull request ##{pull_request.number}: #{pull_request.title}\nPull Request URL: #{pull_request.html_url}\n"
      ask_to_open_in_browser(pull_request.html_url)
    rescue Github::Error::UnprocessableEntity => e
      error_message = e.to_s
      if error_message =~ /request already exists/i
        existing_pull_request = find_pull_request( :from => current_branch, :to => options['base'] )
        puts "A pull request already exists for these branches:"
        display_pull_request_summary(existing_pull_request)
        ask_to_open_in_browser(existing_pull_request.html_url)
      else
        puts error_message
      end
    end
  end

  def deliver(options = {})
    feature_branch    = current_branch
    options['base'] ||= 'master'
    fetch_destination options['base']

    update_destination(current_branch)

    begin
      existing_pull_request = find_pull_request( :from => current_branch, :to => options['base'] )

      if existing_pull_request.nil?
        puts "Error: No pull request exists for #{remote_user}:#{current_branch}\nPlease submit your branch for review first with \`git reflow review\`"
      else

        open_comment_authors = find_authors_of_open_pull_request_comments(existing_pull_request)
        has_comments         = has_pull_request_comments?(existing_pull_request)

        # if there any comment_authors left, then they haven't given a lgtm after the last commit
        if (has_comments and open_comment_authors.empty?) or options['skip_lgtm']
          lgtm_authors   = comment_authors_for_pull_request(existing_pull_request, :with => LGTM)
          commit_message = existing_pull_request[:body] || get_first_commit_message
          puts "Merging pull request ##{existing_pull_request.number}: '#{existing_pull_request.title}', from '#{existing_pull_request.head.label}' into '#{existing_pull_request.base.label}'"

          update_destination(options['base'])
          merge_feature_branch(:feature_branch => feature_branch,
                               :destination_branch => options['base'],
                               :pull_request_number => existing_pull_request.number,
                               :message => "\nCloses ##{existing_pull_request.number}\n\nLGTM given by: @#{lgtm_authors.join(', @')}\n")
          append_to_squashed_commit_message(commit_message)
          puts "git commit".colorize(:green)
          committed = system('git commit')

          if committed
            puts "Merge complete!"
            deploy_and_cleanup = ask "Would you like to push this branch to your remote repo and cleanup your feature branch? "
            if deploy_and_cleanup =~ /^y/i
              run_command_with_label "git push origin #{options['base']}"
              run_command_with_label "git push origin :#{feature_branch}"
              run_command_with_label "git branch -D #{feature_branch}"
              puts "Nice job buddy."
            end
          else
            puts "There were problems commiting your feature... please check the errors above and try again."
          end
        elsif open_comment_authors.count > 0
          puts "[deliver halted] You still need a LGTM from: #{open_comment_authors.join(', ')}"
        else
          puts "[deliver halted] Your code has not been reviewed yet."
        end
      end

    rescue Github::Error::UnprocessableEntity => e
      errors = JSON.parse(e.response_message[:body])
      error_messages = errors["errors"].collect {|error| "GitHub Error: #{error["message"].gsub(/^base\s/, '')}" unless error["message"].nil?}.compact.join("\n")
      puts error_messages
    end
  end

  def github
    @github ||= Github.new do |config|
      config.oauth_token = GitReflow.github_oauth_token
      config.endpoint    = GitReflow.github_api_endpoint
      config.site        = GitReflow.github_site_url
    end
  end

  def github_api_endpoint
    endpoint = `git config --get github.endpoint`.strip
    (endpoint.length > 0) ? endpoint : Github::Configuration::DEFAULT_ENDPOINT
  end

  def set_github_api_endpoint(api_endpoint, options = {local: false})
    if options[:local]
      `git config --replace-all github.endpoint #{api_endpoint}`
    else
      `git config --global --replace-all github.endpoint #{api_endpoint}`
    end
  end

  def github_site_url
    site_url = `git config --get github.site`.strip
    (site_url.length > 0) ? site_url : Github::Configuration::DEFAULT_SITE
  end

  def set_github_site_url(site_url, options = {local: false})
    if options[:local]
      `git config --replace-all github.site #{site_url}`
    else
      `git config --global --replace-all github.site #{site_url}`
    end
  end

  def github_oauth_token
    `git config --get github.oauth-token`.strip
  end

  def current_branch
    `git branch --no-color | grep '^\* ' | grep -v 'no branch' | sed 's/^* //g'`.strip
  end

  def github_user
    `git config --get github.user`.strip
  end

  def remote_user
    gh_remote_user = `git config --get remote.origin.url`.strip
    gh_remote_user.slice!(/github\.com[\/:](\w|-|\.)+/i)[11..-1]
  end

  def remote_repo_name
    gh_repo = `git config --get remote.origin.url`.strip
    gh_repo.slice(/\/(\w|-|\.)+$/i)[1..-5]
  end

  def get_first_commit_message
    `git log --pretty=format:"%s" --no-merges -n 1`.strip
  end

  def set_oauth_token(oauth_token, options = {})
    if options.delete(:local)
      `git config --replace-all github.oauth-token #{oauth_token}`
    else
      `git config --global --replace-all github.oauth-token #{oauth_token}`
    end
  end

  def push_current_branch
    run_command_with_label "git push origin #{current_branch}"
  end

  def fetch_destination(destination_branch)
    run_command_with_label "git fetch origin #{destination_branch}"
  end

  def update_destination(destination_branch)
    origin_branch = current_branch
    run_command_with_label "git checkout #{destination_branch}"
    run_command_with_label "git pull origin #{destination_branch}"
    run_command_with_label "git checkout #{origin_branch}"
  end

  def merge_feature_branch(options = {})
    options[:destination_branch] ||= 'master'
    message                        = options[:message] || "\nCloses ##{options[:pull_request_number]}\n"

    run_command_with_label "git checkout #{options[:destination_branch]}"
    run_command_with_label "git merge --squash #{options[:feature_branch]}"
    # append pull request number to commit message
    append_to_squashed_commit_message(message)
  end

  def append_to_squashed_commit_message(message = '')
    `echo "#{message}" | cat - .git/SQUASH_MSG > ./tmp_squash_msg`
    `mv ./tmp_squash_msg .git/SQUASH_MSG`
  end

  def find_pull_request(options)
    existing_pull_request = nil
    github.pull_requests.all(remote_user, remote_repo_name, :state => 'open') do |pull_request|
      if pull_request.base.label == "#{remote_user}:#{options[:to]}" and
         pull_request.head.label == "#{remote_user}:#{options[:from]}"
         existing_pull_request = pull_request
         break
      end
    end

    existing_pull_request
  end

  def pull_request_comments(pull_request)
    comments        = github.issues.comments.all        remote_user, remote_repo_name, pull_request.number
    review_comments = github.pull_requests.comments.all remote_user, remote_repo_name, pull_request.number

    review_comments.to_a + comments.to_a
  end

  def has_pull_request_comments?(pull_request)
    pull_request_comments(pull_request).count > 0
  end

  def find_authors_of_open_pull_request_comments(pull_request)
    # first we'll gather all the authors that have commented on the pull request
    pull_last_committed_at = get_commited_time(pull_request.head.sha)
    comment_authors        = comment_authors_for_pull_request(pull_request)
    lgtm_authors           = comment_authors_for_pull_request(pull_request, :with => LGTM, :after => pull_last_committed_at)

    comment_authors - lgtm_authors
  end

  def comment_authors_for_pull_request(pull_request, options = {})
    all_comments    = pull_request_comments(pull_request)
    comment_authors = []

    all_comments.each do |comment|
      next if options[:after] and Time.parse(comment.created_at) < options[:after]
      if (options[:with].nil? or comment[:body] =~ options[:with])
        comment_authors |= [comment.user.login]
      end
    end

    # remove the current user from the list to check
    comment_authors -= [github_user]
  end

  def display_pull_request_summary(pull_request)
    summary_data = {
      "branches"    => "#{pull_request.head.label} -> #{pull_request.base.label}",
      "number"      => pull_request.number,
      "url"         => pull_request.html_url
    }

    notices = ""
    reviewed_by = comment_authors_for_pull_request(pull_request).map {|author| author.colorize(:red) }

    # check for needed lgtm's
    pull_comments = pull_request_comments(pull_request)
    if pull_comments.reject {|comment| comment.user.login == github_user}.any?
      open_comment_authors = find_authors_of_open_pull_request_comments(pull_request)
      last_committed_at    = get_commited_time(pull_request.head.sha)
      lgtm_authors         = comment_authors_for_pull_request(pull_request, :with => LGTM, :after => last_committed_at)

      summary_data.merge!("Last comment"  => pull_comments.last[:body].inspect)

      if lgtm_authors.any?
        reviewed_by.map! { |author| lgtm_authors.include?(author.uncolorize) ? author.colorize(:green) : author }
      end

      notices << "[notice] You still need a LGTM from: #{open_comment_authors.join(', ')}\n" if open_comment_authors.any?
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

  def get_commited_time(commit_sha)
    last_commit = github.repos.commits.find remote_user, remote_repo_name, commit_sha
    Time.parse last_commit.commit.author[:date]
  end

  # WARNING: this currently only supports OS X and UBUNTU
  def ask_to_open_in_browser(url)
    if RUBY_PLATFORM =~ /darwin|linux/i
      open_in_browser = ask "Would you like to open it in your browser? "
      if open_in_browser =~ /^y/i
        if RUBY_PLATFORM =~ /darwin/i
          # OS X
          `open #{url}`
        else
          # Ubuntu
          `xdg-open #{url}`
        end
      end
    end
  end

  def run_command_with_label(command, options = {})
    label_color = options.delete(:color) || :green
    puts command.colorize(label_color)
    puts `#{command}`
  end
end
