# Changelog

## [v0.9.4](https://github.com/reenhanced/gitreflow/tree/v0.9.4) (2020-11-10)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.9.3...v0.9.4)

**Merged pull requests:**

- Fixed typo [\#244](https://github.com/reenhanced/gitreflow/pull/244) ([hsbt](https://github.com/hsbt))

## [v0.9.3](https://github.com/reenhanced/gitreflow/tree/v0.9.3) (2020-06-02)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.9.2...v0.9.3)

**Implemented enhancements:**

- Add documention for GitReflow::Config [\#237](https://github.com/reenhanced/gitreflow/issues/237)
- Add documentation [\#157](https://github.com/reenhanced/gitreflow/issues/157)

**Closed issues:**

- GitHub authentication issues [\#193](https://github.com/reenhanced/gitreflow/issues/193)

**Merged pull requests:**

- Upgrade dependencies [\#242](https://github.com/reenhanced/gitreflow/pull/242) ([codenamev](https://github.com/codenamev))
- Creates multi-ruby-tests.yml [\#241](https://github.com/reenhanced/gitreflow/pull/241) ([codenamev](https://github.com/codenamev))
- Documention for GitReflow::Config [\#238](https://github.com/reenhanced/gitreflow/pull/238) ([PuZZleDucK](https://github.com/PuZZleDucK))
- Fixes several issues related to git-reflow setup [\#236](https://github.com/reenhanced/gitreflow/pull/236) ([codenamev](https://github.com/codenamev))

## [v0.9.2](https://github.com/reenhanced/gitreflow/tree/v0.9.2) (2019-09-10)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.9.1...v0.9.2)

**Closed issues:**

- Rebase when refreshing? [\#234](https://github.com/reenhanced/gitreflow/issues/234)

**Merged pull requests:**

- Update dependencies and trap INT signal [\#235](https://github.com/reenhanced/gitreflow/pull/235) ([codenamev](https://github.com/codenamev))

## [v0.9.1](https://github.com/reenhanced/gitreflow/tree/v0.9.1) (2019-04-17)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.9.0...v0.9.1)

**Closed issues:**

- Purpose of core `stage` command? [\#232](https://github.com/reenhanced/gitreflow/issues/232)

## [v0.9.0](https://github.com/reenhanced/gitreflow/tree/v0.9.0) (2018-11-09)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.8.10...v0.9.0)

**Implemented enhancements:**

- Make a git-reflow specific configuration for storing a custom base-branch [\#202](https://github.com/reenhanced/gitreflow/issues/202)

**Fixed bugs:**

- bitbucket: error occurs while creating pull request [\#93](https://github.com/reenhanced/gitreflow/issues/93)
- Review command race condition [\#84](https://github.com/reenhanced/gitreflow/issues/84)

**Closed issues:**

- ear [\#225](https://github.com/reenhanced/gitreflow/issues/225)
- Nokogiri not getting installed:- [\#220](https://github.com/reenhanced/gitreflow/issues/220)
- git reflow status returns with 401 - Bad credentials [\#219](https://github.com/reenhanced/gitreflow/issues/219)
- No help from git reflow --help [\#118](https://github.com/reenhanced/gitreflow/issues/118)
- f has already been specified as a switch in the command deliver \(ArgumentError\) [\#59](https://github.com/reenhanced/gitreflow/issues/59)
- Command to edit default commit format [\#51](https://github.com/reenhanced/gitreflow/issues/51)

**Merged pull requests:**

- Fix critical issue, and update deps [\#245](https://github.com/reenhanced/gitreflow/pull/245) ([codenamev](https://github.com/codenamev))
- Allows for configuring a custom base-branch [\#231](https://github.com/reenhanced/gitreflow/pull/231) ([codenamev](https://github.com/codenamev))
- Fixes many scoping issues with new Workflow [\#229](https://github.com/reenhanced/gitreflow/pull/229) ([codenamev](https://github.com/codenamev))
- Retry pull-request creation if there are errors [\#226](https://github.com/reenhanced/gitreflow/pull/226) ([codenamev](https://github.com/codenamev))
- Fixes loading of custom workflow file to once per session [\#224](https://github.com/reenhanced/gitreflow/pull/224) ([codenamev](https://github.com/codenamev))
- Allow for custom commit/merge message templates [\#223](https://github.com/reenhanced/gitreflow/pull/223) ([codenamev](https://github.com/codenamev))

## [v0.8.10](https://github.com/reenhanced/gitreflow/tree/v0.8.10) (2018-04-19)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.8.9...v0.8.10)

**Merged pull requests:**

- Updates rubies and gems [\#221](https://github.com/reenhanced/gitreflow/pull/221) ([codenamev](https://github.com/codenamev))
- Remove lingering `skip\_lgtm` options in favor of `force` option [\#218](https://github.com/reenhanced/gitreflow/pull/218) ([codenamev](https://github.com/codenamev))
- Remove dead code [\#217](https://github.com/reenhanced/gitreflow/pull/217) ([codenamev](https://github.com/codenamev))
- Updates REAME to Markdown [\#216](https://github.com/reenhanced/gitreflow/pull/216) ([codenamev](https://github.com/codenamev))
- Updates readme with details on customization [\#214](https://github.com/reenhanced/gitreflow/pull/214) ([codenamev](https://github.com/codenamev))

## [v0.8.9](https://github.com/reenhanced/gitreflow/tree/v0.8.9) (2017-04-26)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.8.8...v0.8.9)

**Fixed bugs:**

- `git reflow deliver` no longer squashing! [\#212](https://github.com/reenhanced/gitreflow/issues/212)
- Github approval message is not seen as a LGTM [\#207](https://github.com/reenhanced/gitreflow/issues/207)

**Merged pull requests:**

- Adds checks for new GH reviews when delivering [\#215](https://github.com/reenhanced/gitreflow/pull/215) ([codenamev](https://github.com/codenamev))

## [v0.8.8](https://github.com/reenhanced/gitreflow/tree/v0.8.8) (2017-04-24)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.8.7...v0.8.8)

## [v0.8.7](https://github.com/reenhanced/gitreflow/tree/v0.8.7) (2017-04-21)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.8.4...v0.8.7)

**Implemented enhancements:**

- Use a logger instead of `puts` [\#156](https://github.com/reenhanced/gitreflow/issues/156)

**Closed issues:**

- Rejected push deletes local branch on deliver [\#206](https://github.com/reenhanced/gitreflow/issues/206)
- Running setup multiple times will create multiple entries in .gitconfig [\#203](https://github.com/reenhanced/gitreflow/issues/203)
- Add Direct Merge Workflow [\#201](https://github.com/reenhanced/gitreflow/issues/201)
- undefined method for strip [\#197](https://github.com/reenhanced/gitreflow/issues/197)
- Ideas for additional steps, such as linting, etc. [\#190](https://github.com/reenhanced/gitreflow/issues/190)

**Merged pull requests:**

- 0.8.7 [\#213](https://github.com/reenhanced/gitreflow/pull/213) ([nhance](https://github.com/nhance))
- Updates Github merge request to use new `merge\_method` param [\#211](https://github.com/reenhanced/gitreflow/pull/211) ([codenamev](https://github.com/codenamev))
- Adds a logger to log command runs [\#210](https://github.com/reenhanced/gitreflow/pull/210) ([codenamev](https://github.com/codenamev))
- All commands that are run through reflow \(except git-config\) are now blocking [\#209](https://github.com/reenhanced/gitreflow/pull/209) ([codenamev](https://github.com/codenamev))
- Fix loading of PR template from '.github' directory [\#208](https://github.com/reenhanced/gitreflow/pull/208) ([codenamev](https://github.com/codenamev))
- \[\#201\] Add direct merge workflow [\#205](https://github.com/reenhanced/gitreflow/pull/205) ([codenamev](https://github.com/codenamev))
- \[\#203\] Evaluate environment variables when checking existing config files [\#204](https://github.com/reenhanced/gitreflow/pull/204) ([Shalmezad](https://github.com/Shalmezad))
- \[53\] Allow workflows to be loaded from git config [\#199](https://github.com/reenhanced/gitreflow/pull/199) ([codenamev](https://github.com/codenamev))

## [v0.8.4](https://github.com/reenhanced/gitreflow/tree/v0.8.4) (2016-08-22)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.8.3...v0.8.4)

**Closed issues:**

- error: We were unable to authenticate with Github [\#196](https://github.com/reenhanced/gitreflow/issues/196)
- Introduce the idea of "Workflows" to customize steps [\#53](https://github.com/reenhanced/gitreflow/issues/53)

**Merged pull requests:**

- \[53\] Create core workflow module to consolidate commands [\#198](https://github.com/reenhanced/gitreflow/pull/198) ([codenamev](https://github.com/codenamev))

## [v0.8.3](https://github.com/reenhanced/gitreflow/tree/v0.8.3) (2016-08-04)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.8.2...v0.8.3)

## [v0.8.2](https://github.com/reenhanced/gitreflow/tree/v0.8.2) (2016-08-01)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.8.1...v0.8.2)

**Fixed bugs:**

- git-reflow setup not working on Windows [\#187](https://github.com/reenhanced/gitreflow/issues/187)

**Closed issues:**

- non-master base branch does not work for the deliver command [\#192](https://github.com/reenhanced/gitreflow/issues/192)
- git-reflow fork command [\#188](https://github.com/reenhanced/gitreflow/issues/188)
- Bitbucket setup not working [\#186](https://github.com/reenhanced/gitreflow/issues/186)
- Default approval regex not respecting :+1: [\#182](https://github.com/reenhanced/gitreflow/issues/182)
- \[SOLVED\] Unable To Install the GEM \(install nokogiri manually to solve the issue\) [\#178](https://github.com/reenhanced/gitreflow/issues/178)
- Can we switch off LGTM reviews? [\#177](https://github.com/reenhanced/gitreflow/issues/177)
- gitreflow does not cache github token? [\#173](https://github.com/reenhanced/gitreflow/issues/173)
- message below the fold in review [\#105](https://github.com/reenhanced/gitreflow/issues/105)

**Merged pull requests:**

- \[\#187\] Update git-reflow config file path to use $HOME for windows support [\#195](https://github.com/reenhanced/gitreflow/pull/195) ([codenamev](https://github.com/codenamev))
- \[192\] Allow delivery to custom base branch [\#194](https://github.com/reenhanced/gitreflow/pull/194) ([codenamev](https://github.com/codenamev))
- Refactor tests to allow for use of reflow test helpers in third-party gems [\#189](https://github.com/reenhanced/gitreflow/pull/189) ([codenamev](https://github.com/codenamev))
- \[Issue \#182\] Fix LGTM Expression [\#185](https://github.com/reenhanced/gitreflow/pull/185) ([simonzhu24](https://github.com/simonzhu24))
- Use $EDITOR as text editor fallback [\#184](https://github.com/reenhanced/gitreflow/pull/184) ([timraasveld](https://github.com/timraasveld))
- Respect GitHub pull request template [\#179](https://github.com/reenhanced/gitreflow/pull/179) ([timraasveld](https://github.com/timraasveld))

## [v0.8.1](https://github.com/reenhanced/gitreflow/tree/v0.8.1) (2016-05-26)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.8.0...v0.8.1)

**Closed issues:**

- undefined method `git\_editor\_comand' for GitReflow:Module [\#176](https://github.com/reenhanced/gitreflow/issues/176)
- github PR ends up "closed" instead of "merged" [\#149](https://github.com/reenhanced/gitreflow/issues/149)
- Update README to mention how to update an in-progress feature branch from origin/master [\#125](https://github.com/reenhanced/gitreflow/issues/125)
- Option to silence the offer to open the PR in my browser? [\#117](https://github.com/reenhanced/gitreflow/issues/117)
- command for merging updates from base branch [\#74](https://github.com/reenhanced/gitreflow/issues/74)
- Support for non-master branch [\#73](https://github.com/reenhanced/gitreflow/issues/73)

## [v0.8.0](https://github.com/reenhanced/gitreflow/tree/v0.8.0) (2016-05-26)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.7.5...v0.8.0)

**Implemented enhancements:**

- Upgrade RSpec [\#162](https://github.com/reenhanced/gitreflow/issues/162)

**Closed issues:**

- Setup doesn't work with GH two-factor turned on [\#175](https://github.com/reenhanced/gitreflow/issues/175)
- --base switch does not work? [\#174](https://github.com/reenhanced/gitreflow/issues/174)
- Idea: git reflow promote \<promotion branch\> [\#168](https://github.com/reenhanced/gitreflow/issues/168)
- add changelog support [\#100](https://github.com/reenhanced/gitreflow/issues/100)
- Always have reflow start create a branch from master [\#66](https://github.com/reenhanced/gitreflow/issues/66)

**Merged pull requests:**

- Cleanup new Github merge for next release [\#172](https://github.com/reenhanced/gitreflow/pull/172) ([codenamev](https://github.com/codenamev))
- Bug Fix for Merging "reenhanced:master" instead of "master" [\#171](https://github.com/reenhanced/gitreflow/pull/171) ([simonzhu24](https://github.com/simonzhu24))
- Sz issue/149 fix commit message to merge instead of close [\#170](https://github.com/reenhanced/gitreflow/pull/170) ([simonzhu24](https://github.com/simonzhu24))
- Fixing Refresh to take in parameter for "base" instead of "branch" [\#169](https://github.com/reenhanced/gitreflow/pull/169) ([simonzhu24](https://github.com/simonzhu24))
- \[Issue \#66\] Always have reflow start create a branch from master [\#167](https://github.com/reenhanced/gitreflow/pull/167) ([simonzhu24](https://github.com/simonzhu24))
- \[162\] Updating Rspec Version to 3.3.0 [\#165](https://github.com/reenhanced/gitreflow/pull/165) ([simonzhu24](https://github.com/simonzhu24))
- \[Issue \#66 + \#74\] Implementing "Git Reflow Refresh" [\#164](https://github.com/reenhanced/gitreflow/pull/164) ([simonzhu24](https://github.com/simonzhu24))
- \[issue: 162\] Updating Rspecs: Use "Allow" instead of "Stub" [\#163](https://github.com/reenhanced/gitreflow/pull/163) ([simonzhu24](https://github.com/simonzhu24))

## [v0.7.5](https://github.com/reenhanced/gitreflow/tree/v0.7.5) (2016-04-14)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.7.4...v0.7.5)

**Implemented enhancements:**

- Modernize gem file structure [\#158](https://github.com/reenhanced/gitreflow/issues/158)

**Closed issues:**

- Remove unused gitreflow-common [\#154](https://github.com/reenhanced/gitreflow/issues/154)
- Option to require LGTM from only one person? [\#141](https://github.com/reenhanced/gitreflow/issues/141)

**Merged pull requests:**

- \[Issue \#141\] Fixing Issues and Adding Configurable Nx LGTM and LGTM Regex Options, Adding Rspec Tests [\#161](https://github.com/reenhanced/gitreflow/pull/161) ([simonzhu24](https://github.com/simonzhu24))
- modernize gem structure; Fixes \#158 [\#159](https://github.com/reenhanced/gitreflow/pull/159) ([pboling](https://github.com/pboling))
- Remove unused gitreflow-common [\#155](https://github.com/reenhanced/gitreflow/pull/155) ([pboling](https://github.com/pboling))

## [v0.7.4](https://github.com/reenhanced/gitreflow/tree/v0.7.4) (2016-04-08)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.7.3...v0.7.4)

**Fixed bugs:**

- Deliver command doesn't sync feature branch before merge [\#152](https://github.com/reenhanced/gitreflow/issues/152)
- SSL Verification is turned off [\#151](https://github.com/reenhanced/gitreflow/issues/151)

## [v0.7.3](https://github.com/reenhanced/gitreflow/tree/v0.7.3) (2016-03-24)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.7.2...v0.7.3)

**Fixed bugs:**

- Setting title is ignored from review [\#127](https://github.com/reenhanced/gitreflow/issues/127)
- Don't open EDITOR if there is an existing PR for this branch [\#123](https://github.com/reenhanced/gitreflow/issues/123)

**Closed issues:**

- add "Created With Reflow" [\#101](https://github.com/reenhanced/gitreflow/issues/101)
- Store OAuth token somewhere else? [\#54](https://github.com/reenhanced/gitreflow/issues/54)

## [v0.7.2](https://github.com/reenhanced/gitreflow/tree/v0.7.2) (2016-02-22)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.7.1...v0.7.2)

**Closed issues:**

- git: 'reflow' is not a git command. See 'git --help' [\#146](https://github.com/reenhanced/gitreflow/issues/146)
- option to use non-master branch by default everywhere [\#145](https://github.com/reenhanced/gitreflow/issues/145)
- Deliver to custom branch? [\#144](https://github.com/reenhanced/gitreflow/issues/144)

## [v0.7.1](https://github.com/reenhanced/gitreflow/tree/v0.7.1) (2015-10-27)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.7.0...v0.7.1)

**Merged pull requests:**

- Fix the ask to open in browser dialog on Mac. [\#143](https://github.com/reenhanced/gitreflow/pull/143) ([squaresurf](https://github.com/squaresurf))

## [v0.7.0](https://github.com/reenhanced/gitreflow/tree/v0.7.0) (2015-10-14)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.6.7...v0.7.0)

**Fixed bugs:**

- Hide author's name from list of LGTMs we need to get [\#126](https://github.com/reenhanced/gitreflow/issues/126)

**Closed issues:**

- Command Injection in append\_to\_squashed\_commit\_message. [\#134](https://github.com/reenhanced/gitreflow/issues/134)

## [v0.6.7](https://github.com/reenhanced/gitreflow/tree/v0.6.7) (2015-09-29)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.6.6...v0.6.7)

## [v0.6.6](https://github.com/reenhanced/gitreflow/tree/v0.6.6) (2015-09-28)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.6.5...v0.6.6)

**Merged pull requests:**

- Fix review message parsing from editor failed [\#133](https://github.com/reenhanced/gitreflow/pull/133) ([francois](https://github.com/francois))

## [v0.6.5](https://github.com/reenhanced/gitreflow/tree/v0.6.5) (2015-08-31)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.6.4...v0.6.5)

**Closed issues:**

- Request: git reflow review --quick or --update [\#129](https://github.com/reenhanced/gitreflow/issues/129)
- Feature Request: command to cleanly land a contributor's PR [\#128](https://github.com/reenhanced/gitreflow/issues/128)

## [v0.6.4](https://github.com/reenhanced/gitreflow/tree/v0.6.4) (2015-08-04)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.6.3...v0.6.4)

**Fixed bugs:**

- reflow needs an lgtm from myself [\#116](https://github.com/reenhanced/gitreflow/issues/116)

## [v0.6.3](https://github.com/reenhanced/gitreflow/tree/v0.6.3) (2015-08-03)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.6.2...v0.6.3)

**Closed issues:**

- Github pre-receive hook to ensure review is not skipped [\#121](https://github.com/reenhanced/gitreflow/issues/121)
- Error: \#\<NameError: wrong constant name \> [\#120](https://github.com/reenhanced/gitreflow/issues/120)

## [v0.6.2](https://github.com/reenhanced/gitreflow/tree/v0.6.2) (2015-08-03)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.6.1...v0.6.2)

**Fixed bugs:**

- GIT\_REFLOW\_PR\_MSG: Permission denied [\#115](https://github.com/reenhanced/gitreflow/issues/115)
- Git reflow setup undefined method `body` [\#96](https://github.com/reenhanced/gitreflow/issues/96)

**Closed issues:**

- deliver halted because lgtm not detected, but lgtm exists [\#119](https://github.com/reenhanced/gitreflow/issues/119)
- Clarify when I would want to install reflow or git\_reflow [\#113](https://github.com/reenhanced/gitreflow/issues/113)
- Clarify when I would want to install reflow or git\_reflow [\#112](https://github.com/reenhanced/gitreflow/issues/112)
- Error when running git reflow review [\#107](https://github.com/reenhanced/gitreflow/issues/107)
- Default PR title from branch name rather than last commit [\#89](https://github.com/reenhanced/gitreflow/issues/89)

**Merged pull requests:**

- Clarify how to pick which gem [\#114](https://github.com/reenhanced/gitreflow/pull/114) ([sethladd](https://github.com/sethladd))
- Add number attribute to Base:PullRequest [\#110](https://github.com/reenhanced/gitreflow/pull/110) ([tanin47](https://github.com/tanin47))

## [v0.6.1](https://github.com/reenhanced/gitreflow/tree/v0.6.1) (2015-06-02)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.6.0...v0.6.1)

**Closed issues:**

- git reflow setup not working [\#106](https://github.com/reenhanced/gitreflow/issues/106)

## [v0.6.0](https://github.com/reenhanced/gitreflow/tree/v0.6.0) (2015-05-15)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.5.3...v0.6.0)

## [v0.5.3](https://github.com/reenhanced/gitreflow/tree/v0.5.3) (2015-05-15)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.5.2...v0.5.3)

**Closed issues:**

- rescue/allow retry on review submit [\#102](https://github.com/reenhanced/gitreflow/issues/102)
- tmp\_squash\_msg can be improved [\#97](https://github.com/reenhanced/gitreflow/issues/97)
- Getting following error while setting up GitHub with reflow [\#94](https://github.com/reenhanced/gitreflow/issues/94)

**Merged pull requests:**

- tmp\_squash\_msh is not removed if we use git reflow in other directories than root. [\#98](https://github.com/reenhanced/gitreflow/pull/98) ([tanin47](https://github.com/tanin47))

## [v0.5.2](https://github.com/reenhanced/gitreflow/tree/v0.5.2) (2015-04-03)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.5.1...v0.5.2)

## [v0.5.1](https://github.com/reenhanced/gitreflow/tree/v0.5.1) (2015-03-26)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.5.0...v0.5.1)

## [v0.5.0](https://github.com/reenhanced/gitreflow/tree/v0.5.0) (2015-03-26)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.4.2...v0.5.0)

**Fixed bugs:**

- bad URI on git reflow status [\#88](https://github.com/reenhanced/gitreflow/issues/88)

**Closed issues:**

- Changing remote url in \reponame\.git\config to make reflow deliver work [\#75](https://github.com/reenhanced/gitreflow/issues/75)

## [v0.4.2](https://github.com/reenhanced/gitreflow/tree/v0.4.2) (2015-02-10)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.4.1...v0.4.2)

**Fixed bugs:**

- Allow for non-ssh origin urls [\#71](https://github.com/reenhanced/gitreflow/issues/71)

**Closed issues:**

- 404 error on all PR functions [\#77](https://github.com/reenhanced/gitreflow/issues/77)
- Show an error message when trying to use the `http` url [\#72](https://github.com/reenhanced/gitreflow/issues/72)
- Setup does not work when 2-factor authentication is enabled [\#57](https://github.com/reenhanced/gitreflow/issues/57)
- Github Enterprise Compatibility [\#42](https://github.com/reenhanced/gitreflow/issues/42)

## [v0.4.1](https://github.com/reenhanced/gitreflow/tree/v0.4.1) (2014-10-28)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.4.0...v0.4.1)

**Closed issues:**

- License does not have year and name filled in [\#69](https://github.com/reenhanced/gitreflow/issues/69)

## [v0.4.0](https://github.com/reenhanced/gitreflow/tree/v0.4.0) (2014-10-16)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.3.5...v0.4.0)

**Merged pull requests:**

- Make sure to create feature branch with current branch as base [\#64](https://github.com/reenhanced/gitreflow/pull/64) ([esposito](https://github.com/esposito))
- \[fix\] Show delivery halted message properly [\#63](https://github.com/reenhanced/gitreflow/pull/63) ([shirshendu](https://github.com/shirshendu))

## [v0.3.5](https://github.com/reenhanced/gitreflow/tree/v0.3.5) (2014-03-05)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.3.4...v0.3.5)

**Closed issues:**

- Getting a 'error: POST https://api.github.com/authorizations: 422' when entering correct user/password [\#60](https://github.com/reenhanced/gitreflow/issues/60)
- Why is squashed merging your preferred workflow? [\#52](https://github.com/reenhanced/gitreflow/issues/52)
- Commit editor prints last commit line twice on top on deliver [\#49](https://github.com/reenhanced/gitreflow/issues/49)
- `git reflow status` does not open in browser when answering 'y' [\#48](https://github.com/reenhanced/gitreflow/issues/48)
- Setup fails [\#47](https://github.com/reenhanced/gitreflow/issues/47)

**Merged pull requests:**

- Add CI build status integration if present [\#58](https://github.com/reenhanced/gitreflow/pull/58) ([shirshendu](https://github.com/shirshendu))
- Add note to created oauth token so users can find them on their tokens page [\#55](https://github.com/reenhanced/gitreflow/pull/55) ([marten](https://github.com/marten))

## [v0.3.4](https://github.com/reenhanced/gitreflow/tree/v0.3.4) (2013-11-01)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.3.3...v0.3.4)

**Fixed bugs:**

- Skip lgtm not functional [\#41](https://github.com/reenhanced/gitreflow/issues/41)

**Closed issues:**

- Syntax for `review` [\#44](https://github.com/reenhanced/gitreflow/issues/44)
- Print all git commands [\#43](https://github.com/reenhanced/gitreflow/issues/43)

## [v0.3.3](https://github.com/reenhanced/gitreflow/tree/v0.3.3) (2013-10-16)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.3.2...v0.3.3)

**Closed issues:**

- License missing from gemspec [\#40](https://github.com/reenhanced/gitreflow/issues/40)

**Merged pull requests:**

- Fix --skip-lgtm option was never passed to the `\#deliver` method [\#45](https://github.com/reenhanced/gitreflow/pull/45) ([francois](https://github.com/francois))

## [v0.3.2](https://github.com/reenhanced/gitreflow/tree/v0.3.2) (2013-07-25)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.3.1...v0.3.2)

## [v0.3.1](https://github.com/reenhanced/gitreflow/tree/v0.3.1) (2013-07-12)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.3...v0.3.1)

## [v0.3](https://github.com/reenhanced/gitreflow/tree/v0.3) (2013-07-12)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.2.5...v0.3)

## [v0.2.5](https://github.com/reenhanced/gitreflow/tree/v0.2.5) (2013-03-04)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.2.5-with-tests...v0.2.5)

## [v0.2.5-with-tests](https://github.com/reenhanced/gitreflow/tree/v0.2.5-with-tests) (2013-03-04)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.2.4...v0.2.5-with-tests)

## [v0.2.4](https://github.com/reenhanced/gitreflow/tree/v0.2.4) (2012-09-21)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.2.2...v0.2.4)

## [v0.2.2](https://github.com/reenhanced/gitreflow/tree/v0.2.2) (2012-09-17)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.2.1...v0.2.2)

## [v0.2.1](https://github.com/reenhanced/gitreflow/tree/v0.2.1) (2012-08-30)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/v0.2...v0.2.1)

## [v0.2](https://github.com/reenhanced/gitreflow/tree/v0.2) (2012-08-28)

[Full Changelog](https://github.com/reenhanced/gitreflow/compare/e84b48641d5ec6f5d87674c9152830e08ffe1b76...v0.2)

**Merged pull requests:**

- Adds documentation to reflow [\#13](https://github.com/reenhanced/gitreflow/pull/13) ([nhance](https://github.com/nhance))



\* *This Changelog was automatically generated by [github_changelog_generator](https://github.com/github-changelog-generator/github-changelog-generator)*
