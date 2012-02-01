Given /^I have a git repository with a branch named "([^"+])"$/ do |branch_name|
  steps %{
    Given I have a remote git repository named "origin"
    And a directory named "master_repo"
    When I cd to "master_repo"
    And I successfully run `git init .`
    And I successfully run `git checkout -b #{branch_name}`
  }
end

Given /^I have a remote git repository named "([^"+])"$/ do |remote_name|
  steps %{
    Given a directory named "#{remote_name}_repo.git"
    When I cd to "#{remote_name}_repo.git"
    And I successfully run `git init --bare`
  }
end
