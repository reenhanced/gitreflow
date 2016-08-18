require 'rubygems'
require 'open-uri'
require "highline/import"
require 'httpclient'
require 'github_api'
require 'json'
require 'colorize'

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
