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
    authorization = github.oauth.create_authorization 'scopes' => ['repo']
    oauth_token = authorization[:token]
    set_oauth_token(oauth_token)
  end

  def deliver(args = {})
    github.pull_requests.create_request('reenhanced', 'repo',
                                                  'title' => 'Title',
                                                  'body' => 'Body',
                                                  'head' => 'reenhanced:banana')
  end

  def github
    @github ||= Github.new :oauth_token => get_oauth_token
  end

  def get_oauth_token
    `git config --get github.oauth-token`.strip
  end

  def remote_user
    gh_user = `git config --get remote.origin.url`.strip
    gh_user.slice!(/\:\w+/i)[1..-1]
  end

  def remote_repo_name
    gh_repo = `git config --get remote.origin.url`.strip
    gh_repo.slice!(/\/\w+/i)[1..-1]
  end

  private
  def set_oauth_token(oauth_token)
    `git config --global --add github.oauth-token #{oauth_token}`
  end
end
