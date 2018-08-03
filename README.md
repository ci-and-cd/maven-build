# maven-build

[![Sonar](https://sonarcloud.io/api/project_badges/measure?project=cn.home1%3Amaven-build&metric=alert_status)](https://sonarcloud.io/dashboard?id=cn.home1%3Amaven-build)  
[Maven Site](https://maven-site.infra.top/ci-and-cd/maven-build/staging/index.html)  
[Source Repository](https://github.com/ci-and-cd/maven-build/tree/develop)  
[![Build Status](https://travis-ci.org/ci-and-cd/maven-build.svg?branch=develop)](https://travis-ci.org/ci-and-cd/maven-build)  


Parent pom for maven based projects

maven-build support code environment segregation and build deploy segregation.  


## I. Usage

Set maven-build as parent in maven projects.

        <parent>
            <groupId>cn.home1</groupId>
            <artifactId>maven-build</artifactId>
            <version>${maven-build.version}</version>
        </parent>

No dependency will be imported, maven-build only responsible for software engineering,
it does not interfering dependency management.

You need to provide few properties and environment variables, see next chapter.


## II. Properties, Environment variables and their default values

### 1. fetch or deploy
- private-nexus3.repository
> default: http://nexus3:28081/nexus/repository
Set this property to a real world url.

- private-nexus3.repository
> default: http://nexus3.localal:28081/nexus/repository
Set this property to a real world url.

- build.publish.channel
> default: snapshot
Set this property to 'release' when building release artifact.
Note: CI_OPT_GITHUB_SITE_REPO_OWNER

### 2. maven-surefire-plugin and maven-failsafe-plugin

- maven.test.skip
> default: false

- maven.integration-test.skip
> default: false

- maven.test.failure.ignore
> default: false

### 3. com.github.eirslett:frontend-maven-plugin
- frontend.nodeDownloadRoot
> default: https://nodejs.org/dist/

- frontend.npmDownloadRoot
> default: http://registry.npmjs.org/npm/-/

Customize these properties only when building front-end projects and default sites are not reachable.

### 4. report
#### 4.1 sonarqube
- private-sonarqube.host.url
> default: http://sonarqube:9000
- private-sonarqube.host.url
> default: http://sonarqube:9000

Need these properties only when profile 'sonar' is activated.

#### 4.2 maven-checkstyle-plugin and maven-pmd-plugin

- checkstyle.config.location
> default: https://raw.githubusercontent.com/ci-and-cd/maven-build/master/src/main/checkstyle/google_checks_8.10.xml
Need to customize when github.com is not reachable.

- pmd.ruleset.location
> default: https://raw.githubusercontent.com/ci-and-cd/maven-build/master/src/main/pmd/pmd-ruleset-6.4.0.xml
Need to customize when github.com is not reachable.

- project.reporting.outputEncoding
> default: UTF-8

### 5. site
- site.path
> default: ${project.artifactId}-${build.publish.channel}
Customize this properties if you want to publish relative projects's site into same parent directory, 
use same value on relative projects.

- CI_INFRA_OPT_OPENSOURCE_GIT_AUTH_TOKEN
> default: N/A (blank)
- CI_OPT_GITHUB_SITE_REPO_OWNER
> default: N/A (blank)
- CI_OPT_GITHUB_SITE_REPO_NAME
> default: N/A (blank)

Need these properties only when deploy site to github.com.

### 6. GPG
- CI_OPT_GPG_KEYNAME
> default: N/A (blank)
- CI_OPT_GPG_PASSPHRASE
> default: N/A (blank)

Need these properties only when deploy artifacts into maven central repository.

### 7. maven central
- CI_OPT_MAVEN_CENTRAL_USER
> Maven central's username
- CI_OPT_MAVEN_CENTRAL_PASS
> Maven central's password

Need these properties only when deploy artifacts into maven central repository.

### 8. maven-compiler-plugin and maven-javadoc-plugin
- project.build.sourceEncoding
> default: UTF-8


## III. Plugins

### 1. build
com.github.eirslett:frontend-maven-plugin

com.amashchenko.maven.plugin:gitflow-maven-plugin
> GitFlow branch model

maven-compiler-plugin with errorprone
> Source encoding.
Java source and target version see maven-build-java*

maven-enforcer-plugin
> Avoid dependency conflict

maven-source-plugin
> Build jar of source code

maven-surefire-plugin and maven-failsafe-plugin with includes and excludes configuration

pl.project13.maven:git-commit-id-plugin

### 2. report
org.asciidoctor:asciidoctor-maven-plugin
org.owasp:dependency-check-maven
org.codehaus.mojo:animal-sniffer-maven-plugin
org.codehaus.mojo:findbugs-maven-plugin
org.codehaus.mojo:jdepend-maven-plugin
org.codehaus.mojo:taglist-maven-plugin
org.codehaus.mojo:versions-maven-plugin
maven-checkstyle-plugin
maven-jxr-plugin
maven-pmd-plugin
maven-surefire-report-plugin

### 3. site
maven-site-plugin
com.github.github:site-maven-plugin

maven-antrun-plugin
> auto clean
'${project.basedir}/src/site/markdown/README.md'
'${project.basedir}/src/site/markdown/src/readme'
'${project.basedir}/src/site/resources'

maven-resources-plugin
> copy
'${project.basedir}/README.md' to '${project.basedir}/src/site/markdown'
'${project.basedir}/src/readme' to '${project.basedir}/src/site/markdown/src/readme'
'${project.basedir}/src/readme' to '${project.basedir}/src/site/resources/src/readme'
'${project.basedir}/src/site/markdown/images' to '${project.basedir}/src/site/resources/images'


## IV. Profiles

### 1. build
infrastructure_opensource
> Use maven central service.
Deploy maven site to github.

infrastructure_private
> Use nexus service at organization internal network.
Deploy maven site into organization internal mvnsite.

infrastructure_local
> Use nexus service at user's local (see [docker-nexus3](../../docker-nexus3/README.html)).
Deploy maven site into local mvnsite (see [docker-proxy](../../docker-proxy/README.html)).

git-commit-id
> Generate src/main/resources/git.properties.
activate automatically if '${maven.multiModuleProjectDirectory}/.git/HEAD' exists

mvn-deploy-publish-segregation-by-wagon
> activate by set 'mvn_deploy_publish_segregation' to 'true'

jacoco-build
> Test coverage report.
activate by property 'jacoco' absent (Enabled by default, to disable, set `-Djacoco=false`)

cobertura
> activate by set property 'jacoco' to 'false'

### 2. report
spring-restdocs
> activate by set property 'spring-restdocs' to 'true'

reports-for-site
> activate by set property 'site' to 'true'

jacoco-report
> activate by set property 'jacoco' to 'true'

dependency-check
> Generate a detailed dependency report, This takes a long time, disabled by default.
> activate by set property 'dependency-check' to 'true' (`mvn -Ddependency-check=true`), 
need to be used together with `site` profile of build-site module.

clirr
> activate by set property 'clirr' to 'true'

sonar
> activate by set property 'sonar' to 'true'

### 3. site
site
> Generate maven site for project,
run `mvn -Dsite=true site site:stage site:stage-deploy` to active this profile and build site, 
set `-Dsite.path=maven-build-snapshot` to specify upload directory.

infrastructure_opensource_site_publish
> publish project site to github  
activate on property 'github-site-publish' is true  
needs:  
env.CI_INFRA_OPT_OPENSOURCE_GIT_AUTH_TOKEN  
env.CI_OPT_GITHUB_SITE_REPO_OWNER


## V. Repositories

central, spring-libs-release, spring-milestone, spring-libs-snapshot


## VI. Jira and gitlab integration

Add args on `maven site` 

    jira.projectKey         # jira projectKey
    jira.user               # jira username
    jira.password           # jira password


## VII. Appendices

### A. Contribution to maven-build

#### A.1. local install/deploy maven-build

    mvn -e -U clean install
    
    mvn -e -U -Dinfrastructure=local -Dsite=true -Dsite.path=ci-and-cd clean install deploy site site:stage site:stage-deploy

#### A.2 Pull request

Please open PR on develop branch.

### B. GPG issue
```
gpg: signing failed: Inappropriate ioctl for device
```

To solve the problem, you need to enable loopback pinentry mode.

Add this to ~/.gnupg/gpg.conf:
```
use-agent 
pinentry-mode loopback
```
And add this to ~/.gnupg/gpg-agent.conf, creating the file if it doesn't already exist:
```
allow-loopback-pinentry
```
