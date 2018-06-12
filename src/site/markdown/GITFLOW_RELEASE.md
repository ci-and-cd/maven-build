# How to release Apache Maven projects

Release Apache Maven projects using gitflow-maven-plugin


## I. prepare release on develop branch

1. Merge features that will be released into `develop` branch.

   1.1. Make sure CI build sucess and all tests passed on feature branch before merge.

   1.2. Squash commits into one.

   You should squash commits on feature branch before merge it into develop branch

   ```bash
   # What we are describing here will destroy commit history and can go wrong. 
   # For this reason, do the squashing on a separate branch.
   # This way, if you screw up, you can go back to your original branch, 
   # make another branch for squashing and try again.
   git checkout -b squashed_feature
   
   # To squash all commits since you branched away from develop, do
   git rebase -i develop
   ```

   Your editor will open with a file like this:

   ```tex
   
   pick fda59df commit 1
   pick x536897 commit 2
   pick c01a668 commit 3
   ```

   Each line represents a commit (in chronological order, the latest commit will be at the **bottom**).  

   To transform all these commits into a single one, change the file to this:

   ```tex
   pick fda59df commit 1
   squash x536897 commit 2
   squash c01a668 commit 3
   ```

   This means, you take the first commit, and squash the following onto it.  
   If you remove a line, the corresponding commit is actually really lost.  
   Don't bother changing the commit messages because they are ignored.  
   After saving the squash settings, your editor will open once more to ask for a commit message for the squashed commit.  
   You can now merge your feature as a single commit into the develop:

   ```bash
   git checkout develop
   git merge squashed_feature
   ```

   see: [squash-several-git-commits-into-a-single-commit](https://makandracards.com/makandra/527-squash-several-git-commits-into-a-single-commit)


   Don’t recommend using this kind of violence operation.

   ```bash
   git reset --soft HEAD~3
   git push origin HEAD --force
   ```

   see: [Squash my last X commits together using Git](https://stackoverflow.com/questions/5189560/squash-my-last-x-commits-together-using-git) 


2. Run tests on develop branch, make sure every thing works.

   You should run unit test at local and push code to trigger a CI build and run integration tests on CI runner/slave.


3. Run `mvn gitflow:release-start` to create a release branch.

   You need to provide

   - release version (the version number without tailing `-SNAPSHOT`)

   Plugin will update each pom.xml in multi module project to apply the release version, but you need to

   check and update version numbers in documents yourself very carefully.

   This is the reason why I add a ugly `.OSS` suffix in version number, it makes search easier.

4. You should on `release/${project.version}` branch now, if `mvn gitflow:release-start` run without error.



## II. Release on `releases/${project.version}` branch

1. Make sure all version numbers in code and documents are correctly updated.

2. Optionally, you can squash all commits since you branched away from master.

3. Push code (`git push --set-upstream origin release/${project.version}`) to trigger CI build and release artifacts by CI build.

   If CI build failed, fix it and repeat step 2 and 3.

   You should not modify any thing after build suceed, If you do need this, start it over and release a new version.

4. Finish release by run `mvn gitflow:release-finish`

   Local `release/${project.version}` branch will be deleted automatically.
   If remote `release/${project.version}` branch not deleted automatically, you can do it manually by `git push -d release/${project.version}`

5. Push tag `v${project.version}`
   Gitflow plugin should push tag `v${project.version}` automatically, if not do it manually by `git push origin tag_name`.
   If you use github, you can build archive on CI system and create a release on github.
   
6. Make sure master and develop branch are pushed.

## V. What CI do

CI should just run tests and create package (not publish artifacts into repository) on Pull/Merge Requests, no snapshots, no maven site.

CI should publish snapshots and maven site on develop branch push.

CI should publish releases and maven site on releases/* branch push.

CI do nothing on master branch push.

CI can build and publish release archive (can skip tests here) to git service or do nothing when version tag pushed.
