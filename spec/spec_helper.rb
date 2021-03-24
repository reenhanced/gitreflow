require 'rubygems'
require 'rspec'
require 'ruby_jard'
require 'multi_json'
require 'webmock/rspec'

$LOAD_PATH << 'lib'
require 'git_reflow'

require 'git_reflow/rspec'

Dir[File.expand_path('../support/**/*.rb', __FILE__)].each {|f| require f}

RSpec.configure do |config|
  config.include WebMock::API
  config.include GitReflow::RSpec::CommandLineHelpers
  config.include GithubHelpers
  config.include GitReflow::RSpec::StubHelpers
  config.include GitReflow::RSpec::WorkflowHelpers

  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end

  config.mock_with :rspec do |c|
    c.syntax = [:should, :expect]
  end

  config.before(:each) do
    WebMock.reset!
    stub_command_line
    suppress_loading_of_external_workflows
    GitReflow::Workflow.reset!
    allow_message_expectations_on_nil
  end

  config.after(:each) do
    WebMock.reset!
    reset_stubbed_command_line
  end
end
