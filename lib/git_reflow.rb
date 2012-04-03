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
    github.oauth.create_authorization 'scopes' => ['repo']
  end
end
