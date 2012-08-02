require 'rubygems'
require 'rake'
require 'json'
require 'open-uri'
require 'httpclient'
require 'github_api'

module GitReflow
  extend self

  def setup
    print "Please enter your GitHub username: "
    gh_user = STDIN.gets.chomp
    `stty -echo`
    print "Please enter your GitHub password (we do NOT store this): "
    gh_password = STDIN.gets.chomp
    `stty echo`
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
      push_current_branch
      pull_request = github.pull_requests.create(remote_user, remote_repo_name,
                                          'title' => options['title'],
                                          'body' => options['body'],
                                          'head' => "#{remote_user}:#{current_branch}",
                                          'base' => options['base'])

      puts "Successfully created pull request ##{pull_request.number}: #{pull_request.title}\nPull Request URL: #{pull_request.html_url}\n"
    rescue Github::Error::UnprocessableEntity => e
      errors = JSON.parse(e.response_message[:body])
      error_messages = errors["errors"].collect {|error| "GitHub Error: #{error["message"].gsub(/^base\s/, '')}" unless error["message"].nil?}.compact.join("\n")
      puts error_messages
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
        puts "Merging pull request ##{existing_pull_request[:number]}: '#{existing_pull_request[:title]}', from '#{existing_pull_request[:head][:label]}' into '#{existing_pull_request[:base][:label]}'"
        update_destination(options['base'])
        merge_feature_branch(:feature_branch => feature_branch, :destination_branch => options['base'])
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

  def remote_user
    gh_user = `git config --get remote.origin.url`.strip
    gh_user.slice!(/\:\w+/i)[1..-1]
  end

  def remote_repo_name
    gh_repo = `git config --get remote.origin.url`.strip
    gh_repo.slice(/\/(\w|-)+/i)[1..-1]
  end

  def get_first_commit_message
    `git log --pretty=format:"%s" --no-merges -n 1`.strip
  end

  private

  def set_oauth_token(oauth_token)
    `git config --global --replace-all github.oauth-token #{oauth_token}`
  end

  def push_current_branch
    exec("git push origin #{current_branch}")
  end

  def fetch_destination(destination_branch)
    `git fetch origin #{destination_branch}`
  end

  def update_destination(destination_branch)
    origin_branch = current_branch
    `git checkout #{destination_branch}`
    exec("git pull origin #{destination_branch}")
    `git checkout #{origin_branch}`
  end

  def merge_feature_branch(options = {})
    options[:destination_branch] ||= 'master'
    `git checkout #{options[:destination_branch]}`
    exec("git merge --squash #{options[:feature_branch]}")
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
end
