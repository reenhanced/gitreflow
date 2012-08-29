require 'rubygems'
require 'rake'
require 'json/pure'
require 'open-uri'
require "highline/import"
require 'httpclient'
require 'github_api'

module GitReflow
  extend self

  LGTM = /lgtm|looks good to me|:\+1:|:thumbsup:/i

  def setup
    gh_user = ask "Please enter your GitHub username: "
    gh_password = ask("Please enter your GitHub password (we do NOT store this): ") { |q| q.echo = false }
    puts "\nYour GitHub account was successfully setup!"
    github = Github.new :basic_auth => "#{gh_user}:#{gh_password}"
    authorization = github.oauth.create 'scopes' => ['repo']
    oauth_token = authorization[:token]
    set_oauth_token(oauth_token)
  end

  def review(options = {})
    options['base'] ||= 'master'
    fetch_destination options['base']

    begin
      puts push_current_branch
      pull_request = github.pull_requests.create(remote_user, remote_repo_name,
                                          'title' => options['title'],
                                          'body' => options['body'],
                                          'head' => "#{remote_user}:#{current_branch}",
                                          'base' => options['base'])

      puts "Successfully created pull request ##{pull_request.number}: #{pull_request.title}\nPull Request URL: #{pull_request.html_url}\n"
      ask_to_open_in_browser(pull_request.html_url)
    rescue Github::Error::UnprocessableEntity => e
      error_message = e.to_s
      if error_message =~ /request already exists/i
        existing_pull_request = find_pull_request( :from => current_branch, :to => options['base'] )
        puts "Existing pull request at: #{existing_pull_request[:html_url]}"

        # check for needed lgtm's
        pull_comments = pull_request_comments(existing_pull_request)
        if pull_comments.any?
          open_comment_authors = find_authors_of_open_pull_request_comments(existing_pull_request)
          puts "[notice] You still need a LGTM from: #{open_comment_authors.join(', ')}" if open_comment_authors.any?
        else
          puts "[notice] No one has reviewed your pull request..."
        end

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

    begin
      existing_pull_request = find_pull_request( :from => current_branch, :to => options['base'] )

      if existing_pull_request.nil?
        puts "Error: No pull request exists for #{remote_user}:#{current_branch}\nPlease submit your branch for review first with \`git reflow review\`"
      else

        open_comment_authors = find_authors_of_open_pull_request_comments(existing_pull_request)

        # if there any comment_authors left, then they haven't given a lgtm after the last commit
        if open_comment_authors.empty?
          lgtm_authors   = comment_authors_for_pull_request(existing_pull_request, :with => LGTM)
          commit_message = get_first_commit_message
          puts "Merging pull request ##{existing_pull_request[:number]}: '#{existing_pull_request[:title]}', from '#{existing_pull_request[:head][:label]}' into '#{existing_pull_request[:base][:label]}'"

          update_destination(options['base'])
          merge_feature_branch(:feature_branch => feature_branch,
                               :destination_branch => options['base'],
                               :pull_request_number => existing_pull_request[:number],
                               :message => "\nCloses ##{existing_pull_request[:number]}\n\nLGTM given by: @#{lgtm_authors.join(', @')}\n")
          append_to_squashed_commit_message(commit_message)
          committed = system('git commit')

          if committed
            puts "Merge complete!"
            deploy_and_cleanup = ask "Would you like to push this branch to your remote repo and cleanup your feature branch? "
            if deploy_and_cleanup =~ /^y/i
              puts `git push origin #{options['base']}`
              puts `git push origin :#{feature_branch}`
              puts `git branch -D #{feature_branch}`
              puts "Nice job buddy."
            end
          else
            puts "There were problems commiting your feature... please check the errors above and try again."
          end
        else
          puts "[deliver halted] You still need a LGTM from: #{open_comment_authors.join(', ')}"
        end
      end

    rescue Github::Error::UnprocessableEntity => e
      errors = JSON.parse(e.response_message[:body])
      error_messages = errors["errors"].collect {|error| "GitHub Error: #{error["message"].gsub(/^base\s/, '')}" unless error["message"].nil?}.compact.join("\n")
      puts error_messages
    end
  end

  def github
    @github ||= Github.new :oauth_token => get_oauth_token
  end

  def get_oauth_token
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

  private

  def set_oauth_token(oauth_token)
    `git config --global --replace-all github.oauth-token #{oauth_token}`
  end

  def push_current_branch
    `git push origin #{current_branch}`
  end

  def fetch_destination(destination_branch)
    `git fetch origin #{destination_branch}`
  end

  def update_destination(destination_branch)
    origin_branch = current_branch
    `git checkout #{destination_branch}`
    puts `git pull origin #{destination_branch}`
    `git checkout #{origin_branch}`
  end

  def merge_feature_branch(options = {})
    options[:destination_branch] ||= 'master'
    message                        = options[:message] || "\nCloses ##{options[:pull_request_number]}\n"

    `git checkout #{options[:destination_branch]}`
    puts `git merge --squash #{options[:feature_branch]}`
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
      if pull_request[:base][:label] == "#{remote_user}:#{options[:to]}" and
         pull_request[:head][:label] == "#{remote_user}:#{options[:from]}"
         existing_pull_request = pull_request
         break
      end
    end
    existing_pull_request
  end

  def pull_request_comments(pull_request)
    comments        = github.issues.comments.all remote_user, remote_repo_name, pull_request[:number]
    review_comments = github.pull_requests.comments.all remote_user, remote_repo_name, pull_request[:number]
    comments + review_comments
  end

  def find_authors_of_open_pull_request_comments(pull_request)
    # first we'll gather all the authors that have commented on the pull request
    all_comments    = pull_request_comments(pull_request)
    comment_authors = comment_authors_for_pull_request(pull_request)

    # now we need to check that all the commented authors have given a lgtm after the last commit
    all_comments.each do |comment|
      next unless comment_authors.include?(comment.user.login)
      pull_last_committed_at = Time.parse pull_request.head.repo.updated_at
      comment_created_at     = Time.parse(comment.created_at)
      if comment_created_at > pull_last_committed_at
        if comment.body =~ LGTM
          comment_authors -= [comment.user.login]
        else
          comment_authors << comment.user.login unless comment_authors.include?(comment.user.login)
        end
      end
    end

    comment_authors || []
  end

  def comment_authors_for_pull_request(pull_request, options = {})
    all_comments    = pull_request_comments(pull_request)
    comment_authors = []

    all_comments.each do |comment|
      comment_authors << comment.user.login if !comment_authors.include?(comment.user.login) and (options[:with].nil? or comment.body =~ options[:with])
    end

    # remove the current user from the list to check
    comment_authors -= [github_user]
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
end
