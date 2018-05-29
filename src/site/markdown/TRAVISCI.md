
# Travis-ci

## java

travis-ci's oraclejdk8
java version "1.8.0_151"
JAVA_HOME /usr/lib/jvm/java-8-oracle

travis-ci's oraclejdk9
java version "9.0.1"
JAVA_HOME /usr/lib/jvm/java-9-oracle

## install travis cli on mac

* see [travis.rb](https://github.com/travis-ci/travis.rb#installation)

    brew install ruby
    sudo gem update --system
    sudo gem install travis -v 1.8.8 --no-rdoc --no-ri
    travis version
    

`travis login` or `travis login --github-token $CI_INFRA_OPT_OPENSOURCE_GIT_AUTH_TOKEN`

## Deploying to Maven Repositories from Tavis CI

* see: [Deploying to Maven Repositories from Tavis CI](https://vzurczak.wordpress.com/2014/09/23/deploying-to-maven-repositories-from-tavis-ci/)

## Publishing a Maven Site to GitHub Pages with Travis-CI

* see: [Publishing a Maven Site to GitHub Pages with Travis-CI](https://blog.lanyonm.org/articles/2015/12/19/publish-maven-site-github-pages-travis-ci.html)


    travis encrypt CI_INFRA_OPT_OPENSOURCE_GIT_AUTH_TOKEN="${CI_INFRA_OPT_OPENSOURCE_GIT_AUTH_TOKEN}" --add env.global

## Environment variables

see: [Environment variables](https://docs.travis-ci.com/user/environment-variables/)

Variables in travis repo settings:

|name                                   | usage                                          | note                           |
|---------------------------------------|:----------------------------------------------:|:------------------------------:|
|CI_OPT_GITHUB_SITE_REPO_OWNER          | for github maven site                          | Display value in build log     |
|CI_INFRA_OPT_OPENSOURCE_GIT_AUTH_TOKEN | for github maven site and config fetch         | Not display value in build log |
|                                       |                                                |                                |
|CI_OPT_MAVEN_CENTRAL_USER              | for deploy artifact | Do not set on forked repo, Not display value in build log |
|CI_OPT_MAVEN_CENTRAL_PASS              | for deploy artifact | Do not set on forked repo, Not display value in build log |

## Note

    env:
      global:
      # ci-script and infrastructure config ref, ex master/develop/v1.0.8
      - CI_OPT_CI_SCRIPT=https://github.com/ci-and-cd/maven-build/raw/master/src/main/ci-script/lib_ci.sh
      # or delete /etc/mavenrc
      - MAVEN_SKIP_RC=true
    # Skipping the Installation Step
    install: true


## Deploy to github releases

    # v is refered to gitflow-maven-plugin:versionTagPrefix
    before_deploy:
    - export PROJECT_MAVEN_VERSION=${TRAVIS_TAG/v/}

    deploy:
      provider: releases
      api_key: $CI_INFRA_OPT_OPENSOURCE_GIT_AUTH_TOKEN
      file: "target/oss-keygen-${PROJECT_MAVEN_VERSION}.jar"
      skip_cleanup: true
      on:
        tag: true
        #all_branches: true

    after_deploy:
    - echo "deploy finished!"
