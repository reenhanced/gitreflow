Given /^I have a git repository with a branch named "([^"]+)"$/ do |branch_name|
  steps %{
    Given a directory named "master_repo"
    And I cd to "master_repo"
    And I write to "README" with:
      | empty file |
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
    And I successfully run `git checkout master`
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
