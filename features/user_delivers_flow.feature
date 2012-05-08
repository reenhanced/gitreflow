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
    And I successfully run `git-reflow review`

  Scenario: User runs git-reflow deliver without any parameters
    When I run `git-reflow deliver`
    Then the output should contain "Merging pull request #1: 'Changed readme', from 'reenhanced:new-branch' into 'reenhanced:master'"

  Scenario: User runs git-reflow start with new branch name
    Given I have a git repository with a branch named "master" checked out
    And I have a remote git repository named "origin"
    And the remote repository named "origin" has changes on the "master" branch
    And I cd to "master_repo"
    When I run `git-reflow start new-branch`
    Then a branch named "new-branch" should have been created from "master"
    And the base branch named "master" should have fetched changes from the remote git repository "origin"
    And the output should contain "Switched to a new branch 'new-branch'"
