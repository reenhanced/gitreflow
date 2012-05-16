@gem
Feature: User delivers a flow
  As a User
  I can deliver a flow
  So I can merge in my topic branch

  Background:
    Given I have a git repository with a branch named "master" checked out
    And I have a remote git repository named "origin"
    And the remote repository named "origin" has changes on the "master" branch
    And I cd to "master_repo"
    When I run `git-reflow start new-branch`
    And I append to "README" with:
      | changed |
    And I successfully run `git add .`
    And I successfully run `git commit -am "Changed readme"`
    Given I have a reviewed feature branch named "new-branch" checked out

  Scenario: User runs git-reflow deliver without any parameters
    Given I cd to ".."
    And the remote repository named "origin" has changes on the "master" branch
    And I cd to "master_repo"
    When I deliver my "new-branch" branch
    Then the branch "master" should be checked out
    And the branch "master" should be up to date with the remote repository
