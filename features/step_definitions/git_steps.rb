Given /^I have a git repository with a branch named "([^"]+)"$/ do |branch_name|
  steps %{
    Given I'm in the home directory
    And a directory named "master_repo"
    And I cd to "master_repo"
    And I write to "README" with:
      | empty file |
    And I successfully run `git add README`
    And I successfully run `git commit -m "Initial commit"`
  }

  unless branch_name == "master"
    steps %{
      And I successfully run `git checkout -b #{branch_name}`
    }
  end
end

Given /^I have a remote git repository named "([^"]+)"$/ do |remote_name|
  steps %{
    Given a directory named "#{remote_name}_repo.git"
    When I cd to "#{remote_name}_repo.git"
    And I successfully run `git init --bare`
    And I cd to ".."
    And I cd to "master_repo"
    And I successfully run `git remote add #{remote_name}_repo.git`
    And I cd to ".."
  }
end

Given /^I'm in the home directory$/ do
  steps %{
    Given a directory named "ENV['HOME']"
    When I cd to "ENV['HOME']"
  }
end
