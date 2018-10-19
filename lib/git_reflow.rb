require 'rubygems'
require 'open-uri'
require 'github_api'
require "highline/import"
require 'httpclient'
require 'json'
require 'colorize'

require 'github_api'
require 'git_reflow/version.rb' unless defined?(GitReflow::VERSION)
require 'git_reflow/config'
require 'git_reflow/git_helpers'
require 'git_reflow/git_server'
require 'git_reflow/git_server/bit_bucket'
require 'git_reflow/git_server/git_hub'
require 'git_reflow/logger'
require 'git_reflow/merge_error'
require 'git_reflow/sandbox'
require 'git_reflow/workflow'
require 'git_reflow/workflows/core'

# This is a work around to silence logger spam from hashie
# https://github.com/intridea/hashie/issues/394
require "hashie"
require "hashie/logger"
Hashie.logger = Logger.new(nil)

module GitReflow
  include Sandbox
  include GitHelpers

  extend self

  def logger(*args)
    @logger ||= GitReflow::Logger.new(*args)
  end

  def workflow
    Workflow.current
  end

  def git_server
    @git_server ||= GitServer.connect provider: GitReflow::Config.get('reflow.git-server').strip, silent: true
  end

  def respond_to_missing?(method_sym, include_all = false)
    (workflow && workflow.respond_to?(method_sym, include_all)) || super(method_sym, include_all)
  end

  def method_missing(method_sym, *arguments, &block)
    if workflow && workflow.respond_to?(method_sym, false)
      workflow.send method_sym, *arguments, &block
    else
      super
    end
  end

end
