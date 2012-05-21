Given /^I have a git repository with a branch named "([^"]+)" checked out$/ do |branch_name|
  steps %{
    Given a directory named "master_repo"
    And I cd to "master_repo"
    And I write to "README" with:
      | Initialized |
    And I successfully run `git init`
    And I successfully run `git add README`
    And I successfully run `git commit -m "Initial commit"`
  }

  unless branch_name == "master"
    steps %{
      And I successfully run `git checkout -b #{branch_name}`
    }
  end

  steps %{
    And I cd to ".."
  }
end

Given /^I have a remote git repository named "([^"]+)"$/ do |remote_name|
  steps %{
    Given a directory named "#{remote_name}_repo"
    When I cd to "#{remote_name}_repo"
    And I successfully run `git init`
    And I write to "README" with:
      | Initialized |
    And I successfully run `git add .`
    And I successfully run `git commit -am "Initial commit"`
    And I cd to ".."
    And I cd to "master_repo"
    And I successfully run `git remote add #{remote_name} ../#{remote_name}_repo`
    And I cd to ".."
  }
end

Given /^the remote repository named "([^"]+)" has changes on the "([^"]+)" branch$/ do |remote_name, branch_name|
  steps %{
    Given a directory named "#{remote_name}_repo"
    When I cd to "#{remote_name}_repo"
    And I successfully run `git checkout #{branch_name}`
    And I append to "README" with:
      | changed |
    And I successfully run `git add .`
    And I successfully run `git commit -am "Changed readme"`
    And I cd to ".."
  }
end

Given /^the repository has been initialized$/ do
  steps %{
    Given I successfully run `git branch`
    Then the output should contain "master"
  }
end

Given /^I have a new branch named "([^"]+)" checked out$/ do |branch_name|
  steps %{
    When I cd to "master_repo"
    And I successfully run `git checkout -b #{branch_name}`
  }
end

Given /^I have a reviewed feature branch named "([^"]+)" checked out$/ do |branch_name|
  pull = {
    "title" => "Amazing new feature",
    "body"  => "Please pull this in!",
    "head"  => "reenhanced:#{branch_name}",
    "base"  => "master",
    "state" => "open"
  }
  stub_github_with(
    :user => 'reenhanced',
    :repo => 'repo',
    :branch => branch_name,
    :pull => pull
  )

  review_options = {
    'base'  => pull['base'],
    'title' => pull['title'],
    'body'  => pull['body']
  }

  GitReflow.review review_options

  # ensure we do not stay inside the remote repo
  steps %{
    Given I cd to ".."
  }
end

When /^I deliver my "([^"]+)" branch$/ do |branch_name|
  pull = {
    "title" => "Amazing new feature",
    "body"  => "Please pull this in!",
    "head"  => "reenhanced:#{branch_name}",
    "base"  => "master",
    "state" => "open"
  }
  stub_github_with(
    :user => 'reenhanced',
    :repo => 'repo',
    :branch => branch_name,
    :pull => pull
  )
  GitReflow.deliver
  GitReflow.stub(:current_branch).and_return("master")
end

Then /^a branch named "([^"]+)" should have been created from "([^"]+)"$/ do |new_branch, base_branch|
  steps %{
    Then the output should match /\\* \\[new branch\\]\\s* #{Regexp.escape(base_branch)}\\s* \\-\\> #{Regexp.escape(new_branch)}/
  }
end

Then /^the base branch named "([^"]+)" should have fetched changes from the remote git repository "([^"]+)"$/ do |base_branch, remote_name|
  steps %{
    Then the output should match /\\* \\[new branch\\]\\s* #{Regexp.escape(base_branch)}\\s* \\-\\> #{remote_name}.#{Regexp.escape(base_branch)}/
  }
end

Then /^the subcommand "([^"]+)" should run$/ do |subcommand|
  has_subcommand?(subcommand).should be_true
end

Then /^the branch "([^"]+)" should be checked out$/ do |branch_name|
  GitReflow.current_branch.should == branch_name
end

Then /^the branch "([^"]+)" should be up to date with the remote repository$/ do |branch_name|
  steps %{
    When I successfully run `git fetch origin`
    And I run `git pull origin #{branch_name}`
    Then the output should contain "Already up-to-date"
  }
end
