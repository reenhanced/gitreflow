require 'rubygems'
require 'open-uri'
require 'github_api'
require "highline/import"
require 'httpclient'
require 'json'
require 'colorize'

# XXX: work around logger spam from hashie (required by github api)
# https://github.com/intridea/hashie/issues/394
require "hashie"
require "hashie/logger"
Hashie.logger = Logger.new(nil)


require 'github_api'
require 'git_reflow/version.rb' unless defined?(GitReflow::VERSION)
require 'git_reflow/config'
require 'git_reflow/git_helpers'
require 'git_reflow/git_server'
require 'git_reflow/git_server/bit_bucket'
require 'git_reflow/git_server/git_hub'
require 'git_reflow/merge_error'
require 'git_reflow/os_detector'
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

  def workflow
    Workflow.current
  end

  def default_editor
    "#{ENV['EDITOR'] || 'vi'}".freeze
  end

  def git_server
    @git_server ||= GitServer.connect provider: GitReflow::Config.get('reflow.git-server').strip, silent: true
  end

  def respond_to?(method_sym, include_all = false)
    (workflow and workflow.respond_to?(method_sym, include_all)) || super(method_sym, include_all)
  end

  def method_missing(method_sym, *arguments, &block)
    if workflow and workflow.respond_to? method_sym
      workflow.send method_sym, *arguments, &block
    else
      super
    end
  end

end
