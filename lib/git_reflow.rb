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
    gh_repo.slice!(/\/\w+/i)[1..-1]
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
end
