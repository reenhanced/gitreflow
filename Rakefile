#!/usr/bin/env rake
require 'rake'
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
 
Dir[File.join(File.dirname(__FILE__),'lib/tasks/*.rake')].each { |f| load f }

RSpec::Core::RakeTask.new(:spec)
 
task :default => [:spec]
