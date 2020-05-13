<h1>
  git-reflow – Automate your git workflow<br/>
  <small><em>(2015 Fukuoka Ruby Award Winner)</em></small>
</h1>

<p>
  <a href="https://actions-badge.atrox.dev/reenhanced/gitreflow/goto?ref=master" title="git workflow">
    <img alt="Git workflow powered by git-reflow"  src="https://img.shields.io/endpoint.svg?url=https%3A%2F%2Factions-badge.atrox.dev%2Freenhanced%2Fgitreflow%2Fbadge%3Fref%3Dmaster&style=flat">
  </a>
  <a href="https://github.com/reenhanced/gitreflow" title="git workflow">
    <img alt="Git workflow powered by git-reflow"  src="https://img.shields.io/badge/git--reflow-v0.9.0-blue.svg?style=flat">
  </a>
  <a href="http://inch-ci.org/github/reenhanced/gitreflow" title="documentation coverage">
    <img src="http://inch-ci.org/github/reenhanced/gitreflow.svg?branch=master&style=shields" alt="Git-Reflow Documentation" />
  </a>
</p>

* [Usage Overview](#usage-overview)
* [Getting Started](#getting-started)
* [Documentation](http://www.rubydoc.info/gems/git_reflow)
* [Guiding Priciples](#guiding-priciples)

![git-reflow deliver](http://reenhanced.com/reflow/git-reflow-deliver.gif)

If your workflow looks like this:
1. Create a feature branch
2. Write great code
3. Create a pull request against master
4. Get 'lgtm' through a code review
5. Merge to master (squashed by default, but can be overridden; [why we prefer squash-merge](https://github.com/reenhanced/gitreflow/issues/52))
6. Delete the feature branch

Reflow will make your life easier.

Reflow automatically creates pull requests, ensures the code review is approved, and merges finished branches to master with a great commit message template.

## Usage Overview
Create and switch to new branch `nh-branchy-branch`:
```
    $ git reflow start nh-branchy-branch
```
Create a pull request for your branch against `master` or a custom `base-branch`:
```
    $ git reflow review
```
If your code is approved, merge to `base-branch` and delete the feature branch:
```
    $ git reflow deliver
```

----

## Benefits
* Enforce code reviews across your team.
* Know that your entire team delivers code the same way.
* Reduce the knowledge needed to deliver great code.
* Have a commit history that's clean and actually usable.
* Revert features with ease (if needed).
* Work with diverse teams with less worry about different processes.
* Stop searching for other git workflows.
  Reflow covers 90% of your needs without junk you'll never use.

## Features
* Automatically create pull requests to master
* Automatically ensure that your code is reviewed before merging
* Start with sensible commit messages by default
* Squash merge feature branches because results are more important than details
* Automatically clean up obsolete feature branches after a successful merge

----

### Prerequisites

**Editor** When reviewing the title and body for a new pull request, or reviewing
the commit message when delivering a feature, we will open a temporary file with
your default editor.  We will use git's chosen editor first (`git config core.editor`),
then we try your `EDITOR` environment variable, and lastly we fallback on "vim".
If you would like to use an editor of your choice, we recommend setting it with
git's config.  As an example, to use Atom as your editor for all git commands:

```
$ git config --global core.editor "atom --wait"
```

See GitHub's full article on [associating text editors with Git](https://help.github.com/articles/associating-text-editors-with-git/) for more information on adding this.


## Getting Started
On your first install, you'll need to setup your Github credentials. These are used only to get an OAuth token that we will store in a reflow-specific git config file.
We use this token so we can create pull requests from the command line.

```
$ gem install git_reflow

... installs gem ...

$ git reflow setup
Please enter your GitHub username: nhance
Please enter your GitHub password (we do NOT store this):

Your GitHub account was successfully setup!
```

This is safe to run multiple times. We don't care. We save this information in a
special git configuration file (`~/.gitconfig.reflow`) that get's included into
your global `~/.gitconfig` file.

For usage with Github Enterprise, or other custom configurations, see our [Advanced Usage Guide](https://github.com/reenhanced/gitreflow/wiki/Advanced-Usage).


### Starting a feature branch
![git reflow start](http://reenhanced.com/reflow/git-reflow-start.gif)

This sets up a feature branch remotely and brings a local copy to your machine. Yeah, you can do this by hand pretty easily, so skip this command if you want. This is just a handy shortcut with no magic.

    git reflow start nh-branch-name

`git reflow start` takes in the name of the new branch name that you want to create your feature on.
In addition, it takes in an optional flag of a _base-branch_ name (`--base`). If you don't pass in this parameter,
then it will look up the `reflow.base-branch` git configuration or default to "master". The base branch name is the base branch that you want to base your feature off of.
This ensures that every time you start a new base branch, it will be based off of your latest remote base.

    git reflow start nh-branch-name --base base-branch-name

> **[PROTIP]**  Use your initials at the beginning of each branch so your team knows
  who is responsible for each. My initials are `N.H.`, so all of my branches start with `nh-`

### Refreshing your current branch based on your base branch
```
git reflow refresh
```

This command updates your **feature-branch** and **base-branch** according to the **remote-location** and then merges your **base-branch** into your **feature-branch**. This is just a handy command to keep your branches up to date at any point in time if someone else has committed to the base-branch or the remote.
```
git reflow refresh -r <remote-location> -b <base-branch>
```

You pass in the name of the remote to fetch from and the name of the **base-branch** that you would like to merge into your **feature-branch**. The **remote-location** defaults to `origin` and the base-branch defaults to `master`. This command also takes in remote and branch name as flag options.

> **Note:** If no `base-branch` argument is provided, then we'll look for a `reflow.base-branch` git
> configuration and fallback to `master` as the default.

### Reviewing your work
![git reflow review](http://reenhanced.com/reflow/git-reflow-review.gif)
```
git reflow review
```

All of our work is reviewed by our team. This helps spread knowledge to multiple parties and keeps the quality of our code consistent.

The `review` step creates a pull request for the currently checked out feature branch against master. That's all you want to do most of the time.
We assume you know what you're doing, so if you need something different, do it by hand.

After making commits to your branch, run `review`. Didn't push it up? No problem, we'll do it for you.
```
git reflow review -t <title> -m <message> <base-branch>
```
> **Note:** `-t` and `-m` are optional, as is the `base-branch` argument. If no
> base-branch is provided, then we'll look for a `reflow.base-branch` git
> configuration and fallback to `master` as the default.

If you do not pass the title or message options to the review command, you will be given an editor to write your PR request commit message, similar to `git commit`. The first line is the title, the rest is the body.

```
$ git reflow review

Review your PR:
--------
Title:
rj_209_test

Body:
[lib] updates review command to address issues
--------
Submit pull request? (Y): <enter>
git fetch origin master
From github.com:meesterdude/gitreflow
 * branch            master     -> FETCH_HEAD

git push origin rj_test
Everything up-to-date

Successfully created pull request #6: rj_test
Pull Request URL: https://github.com/meesterdude/gitreflow/pull/6
Would you like to push this branch to your remote repo and cleanup your feature branch? y<enter>
```

We output the pull request URL so you can distribute it to your team.

#### How it works
Behind the scenes, this is how `review` works:
```
git fetch origin
```

Are we up-to-date with changes from master?
If not, fail with "master has newer changes".

Then,
```
git push origin current-branch # Updates remote branch
```

Do we have pull request?
If not, create it and print "Pull request created at http://pull-url/". If so, print the url for the existing request.

### Checking your branch status
![git reflow status](http://reenhanced.com/reflow/git-reflow-status.gif)
```
git reflow status <base-branch>
```

> **Note:** If no `base-branch` is provided, then we'll look for a `reflow.base-branch` git
> configuration and fallback to `master` as the default.

Sometimes you start working on a branch and can't get back to it for a while. It happens. Use +status+ to check on the status of your work.

```
$ git reflow status

Here's the status of your review:
  branches:     reenhanced:nh-readme-update -> reenhanced:master
  number:       35
  reviewed by:
  url:          https://github.com/reenhanced/gitreflow/pull/35

[notice] No one has reviewed your pull request.
```

This gives you details on who's reviewed your pull request. If someone has participated in reviewed,
but not given you an approval, this will tell you. `status` prevents you from having to open a browser
to find out where your pull request is at. But in case you want to take a look, we give you the option to open it for you.

### Delivering approved code
![git-reflow deliver](http://reenhanced.com/reflow/git-reflow-deliver.gif)
```
git reflow deliver <base-branch>
```

> **Note:** If no `base-branch` argument is provided, then we'll look for a `reflow.base-branch` git
> configuration and fallback to `master` as the default.

> **Also:** This documentation is for the process for the github "remote" merge process via the github_api.
  For the bitbucket standard or github manual process (used when the user applies -f force flag to the "remote" merge via the github_api), please go to section B.


You kick butt. You've got your code reviewed and now you're ready to merge it down to `master` and deploy. Reflow's `deliver` command will take care of all of the steps for you to make this happen.

Reflow's `deliver` requires you to have a pull request, so you'll be protected on those mornings when the coffee isn't working yet.
We built this **to get in your way and make you follow the process**. If you don't like it, do it by hand. You already know what you're doing.

You'll be presented with a pre-filled commit message based on the body of your pull request with references to the pull request and reviewers.

Want to clean up your feature branch afterwards? You'll be prompted after you edit your commit message if you want to clean up your **feature-branch** on Github. If you answer `no`, then your **feature-branch** will exist for you to clean it up later.

This is what it looks like:
```
$ git reflow deliver
Here's the status of your review:
    branches:     simonzhu24:test1234 -> simonzhu24:master
    number:       51
    reviewed by:  @codenamev
    url:          https://github.com/simonzhu24/test/pull/51

This is the current status of your Pull Request. Are you sure you want to deliver? yes

Merging pull request #51: 'last commit message', from 'simonzhu24:test1234' into 'simonzhu24:master'
git checkout master
Switched to branch 'master'
Your branch is ahead of 'origin/master' by 1 commit.
  (use "git push" to publish your local commits)

[success] Pull Request successfully merged.
Would you like to cleanup your feature branch? yes
git pull origin master
remote: Counting objects: 1, done.
remote: Total 1 (delta 0), reused 0 (delta 0), pack-reused 0
Unpacking objects: 100% (1/1), done.
From https://github.com/simonzhu24/test
 * branch            master     -> FETCH_HEAD
   0d8f5e0..f853efa  master     -> origin/master
Updating 0b6782f..f853efa
Fast-forward
 README.md | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)

git push origin :test1234
To https://github.com/simonzhu24/test.git
 - [deleted]         test1234

git branch -D test1234
Deleted branch test1234 (was e130c7a).
Nice job buddy.
```

#### How it works

This is what we do behind the scenes when you do `deliver`

* Does a pull request exist?
  * If not, stop here. You need to run `review`.
* Has the review been completed? Did we get an approval from everyone who's participated?
  * If not, show a list of authors that need to approve.
* If the review is done, it's time to merge. Here's what happens:
  1. First, we use the github_api gem to merge the pull request ([see here for how we do this](../blob/master/lib/git_reflow_git_server/git_hub/pull_request.rb:102-107)).
     > **Notice:** we will do a `squash-merge` by default. You can [customize the merge method for your project](https://github.com/reenhanced/gitreflow/wiki/Full-List-of-Configuration-Options).
  2. Next, we prompt you if you want to cleanup: `Would you like cleanup your feature branch?`
    * If `yes`, then we'll update the **base-branch** and delete the **feature-branch**
      ```
      git pull origin <base-branch>
      git push origin :<feature-branch>
      git branch -D <feature-branch>
      ```

    * If 'no', then just stop here. The user can clean up his branch locally.

##### This is what the process looks like for Bitbucket or if you force deliver (`git reflow deliver -f`):
```
  From github.com:reenhanced/gitreflow
  * branch            master     -> FETCH_HEAD
  Merging pull request #36: 'Enforce at least one LGTM before delivery', from 'reenhanced:nh-fail-without-lgtm' into 'reenhanced:master'
  Already up-to-date.
  Switched to branch 'nh-fail-without-lgtm'
  Switched to branch 'master'
  Updating c2ec1b1..f90e111
   Squash commit -- not updating HEAD
   lib/git_reflow.rb | 71 +++++++++++++++++++++++++++----------------------------
   1 file changed, 35 insertions(+), 36 deletions(-)
  [master d1b4dd5] Enforces LGTM before deliver, even with no comments.
   1 file changed, 35 insertions(+), 36 deletions(-)
  Merge complete!
  Would you like to push this branch to your remote repo and cleanup your feature branch? y
  Counting objects: 7, done.
  Delta compression using up to 16 threads.
  Compressing objects: 100% (4/4), done.
  Writing objects: 100% (4/4), 1.38 KiB, done.
  Total 4 (delta 2), reused 0 (delta 0)
  To git@github.com:reenhanced/gitreflow.git
     c2ec1b1..d1b4dd5  master -> master

  To git@github.com:reenhanced/gitreflow.git
   - [deleted]         nh-fail-without-lgtm

  Deleted branch nh-fail-without-lgtm (was f90e111).
```
This is what the default commit message looks like:
```
  Enforces LGTM before deliver, even with no comments.
  Removes the need to review the pull request yourself if you make a
  comment.

  Better error message if setup fails.

  Bug fixes.

  Closes #36

  LGTM given by: @codenamev

  Squashed commit of the following:

  commit f90e111
  Author: Nicholas Hance <nhance@reenhanced.com>
  Date:   Thu Jul 11 15:33:29 2013 -0400
  ...
```

If the review is done, it's time to merge. Here's what happens:

1. First, update our local `master` so we don't get conflicts
  ```
  git checkout master
  git pull origin master
  ```

2. Next, merge our feature branch (in our case `squash-merge`)
  ```
  git merge --squash nh-branch-name
  ```

3. Now, we'll apply a little magic so we have a great commit message by default.
  Your editor will open and you'll see a nice default for your commit message based on the pull request body.
  ```
  git commit
  ```
  > **Note:** We use `.git/COMMIT_EDITMSG` by default for populating this. See the [Full List of Configuration](https://github.com/reenhanced/gitreflow/wiki/Full-List-of-Configuration-Options) for how you can change this.

4. Once you've saved the commit, we'll make sure you want to continue.
  ```
  Merge complete!
  Would you like to push this branch to your remote repo and cleanup your feature branch?
  ```
  * If 'yes', then we'll push to **base-branch**(default: `master`) and delete the **feature-branch**
    ```
    git pull origin master
    git push origin master
    git push origin :nh-branch-name
    git branch -D nh-branch-name
    ```
  * If 'no', then just stop here. The user can reset his local **base-branch**. And we're done!

## Guiding Principles
* Your workflow should resemble the following:

  ![git reflow workflow](http://reenhanced.com/images/reflow.png)

* You should already know what you're doing.
  We assume you know how to use git.

* The `master` branch is your codebase.
  You don't need multiple branches for code you want to use.

* `master` should remain stable at all times.
  The entire team depends on it.

* No direct commits to `master`.
  All work happens in feature branches. From a single commit to hundreds.

* All feature branches are reviewed via pull requests.

* Looks Good To Me. All feature branches require approval.
  We check both Github's Approvals, and look for the string 'LGTM' in a comment on the pull request to know it's ready to merge.

* If you make a new commit in your branch, you require another review.

* Depending on your `git config constants.minimumApprovals` setting, which we specify in your ~/.gitconfig.reflow (created upon reflow setup), you can have the following:

| minimumApprovals | Applied Restrictions                                                          |
|:----------------:| ------------------------------------------------------------------------------|
| ""               | All participants in a pull request must approve the pull request.             |
| "0"              | 0 approvals required for you to merge PR.                                     |
| "1"              | You need a minimum of 1 LGTM and the last comment on your PR must be an LGTM. |
| "2"              | You need a minimum of 2 LGTM and the last comment on your PR must be an LGTM. |

* Once approved, your **feature-branch** is merged to your **base-branch**.
  This makes the history of the **base-branch** extremely clean and easy to follow.

* `git blame` becomes your friend. You'll know who to blame and can see the full context of changes.
  Squash commits to **base-branch** mean every commit represents the whole feature, not a "typo fix".


## Configuration

  In order to streamline delivery you can set the following git config to:

  1. always clean up the feature branch after the PR is merged
    ```
    git config --global --add "reflow.always-cleanup" "true"
    ```
  2. always deliver without further prompt
    ```
    git config --global --add "reflow.always-deliver" "true"
    ```

  See our [Advanced Usage](https://github.com/reenhanced/gitreflow/wiki/Full-List-of-Configuration-Options) for more ways you can customize your workflow.

## Customization

Git-reflow's default process isn't meant to fit every team, which is why we've introduced [Custom Workflows](https://github.com/reenhanced/gitreflow/wiki/Custom-Workflows). With a custom workflow, you can:

* Add hooks to be run before, or after any command
* Use one of our pre-configured workflows as a basis for your own
* Override any of the default commands
* Create new commands

---

## Contributing
Pull requests are welcome. Please fork and submit. We use this tool every single day and as long as what you want to add doesn't change our workflow, we are happy to accept your updates. Feel free to add your Github username to the list below.

Authors:
* @codenamev
* @armyofgnomes
* @nhance

Built by Reenhanced:
http://www.reenhanced.com

**Looking for a capable team for your project? Get in touch. We're looking to grow.**

_Licensed using the MIT license. Do whatever you like with this, but don't blame us if it breaks anything. You're a professional, and you're responsible for the tools you use._
