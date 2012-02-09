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
    Given a directory named "#{remote_name}_repo.git"
    When I cd to "#{remote_name}_repo.git"
    And I successfully run `git init --bare`
    And I cd to ".."
    And I cd to "master_repo"
    And I successfully run `git remote add #{remote_name} ../#{remote_name}_repo.git`
    And I cd to ".."
  }
end

Given /^the remote repository named "([^"]+)" has changes$/ do |remote_name|
  `cd #{remote_name}_repo.git`
  `echo 'changed' >> README`
  `git commit -am "Changed readme"`
  `cd ..`
end
