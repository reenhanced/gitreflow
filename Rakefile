#!/usr/bin/env rake
require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "github_changelog_generator/task"

RSpec::Core::RakeTask.new(:spec)

GitHubChangelogGenerator::RakeTask.new :changelog do |config|
  config.user = 'reenhanced'
  config.project = 'gitreflow'
  config.since_tag = 'v0.9.2'
  config.future_release = 'master'
end

task :default => :spec
