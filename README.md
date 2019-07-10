# maven-build

[![Sonar](https://sonarcloud.io/api/project_badges/measure?project=cn.home1%3Amaven-build&metric=alert_status)sonarcloud](https://sonarcloud.io/dashboard?id=cn.home1%3Amaven-build)  
  
[Maven Site release (github.io)](https://ci-and-cd.github.io/ci-and-cd/release/index.html)  
[Maven site snapshot (infra.top)](https://maven-site.infra.top/ci-and-cd/maven-build/snapshot/staging/index.html)  

[Artifacts (release)](https://oss.sonatype.org/content/repositories/releases/cn/home1/maven-build/)  
[Artifacts (snapshot)](https://oss.sonatype.org/content/repositories/snapshots/cn/home1/maven-build/)  

[Source Repository (github)](https://github.com/ci-and-cd/maven-build/tree/develop)  
[Source Repository (gitlab)](https://gitlab.com/ci-and-cd/maven-build/tree/develop)  

[![Build status](https://ci.appveyor.com/api/projects/status/kacuklbdu48bt7l1?svg=true)appveyor](https://ci.appveyor.com/project/chshawkn/maven-build)  
[![pipeline status](https://gitlab.com/ci-and-cd/maven-build/badges/develop/pipeline.svg)gitlab-ci](https://gitlab.com/ci-and-cd/maven-build/pipelines)  
[![Build Status](https://travis-ci.org/ci-and-cd/maven-build.svg?branch=develop)travis-ci](https://travis-ci.org/ci-and-cd/maven-build)  


Parent pom for maven based jar, war and docker projects

maven-build support code environment segregation and build deploy segregation.  


## I. Usage

Copy `maven-build/src/main/maven/toolchains.xml` to `~/.m2/toolchains.xml`
```bash
cp src/main/maven/toolchains.xml ~/.m2/toolchains.xml
# or
cp src/main/maven/toolchains-darwin.xml ~/.m2/toolchains.xml
```
Update jdkHome in ~/.m2/toolchains.xml

Set maven-build as parent in maven projects.

        <parent>
            <groupId>cn.home1</groupId>
            <artifactId>maven-build</artifactId>
            <version>${version.maven-build}</version>
        </parent>

No dependency will be imported, maven-build only responsible for software engineering,
it does not interfering dependency management.

TODO document about extensions
see: 
[topinfra-mvnext-module-maven-build-pom](https://github.com/ci-and-cd/topinfra-maven/tree/develop/topinfra-mvnext-module-maven-build-pom)
[topinfra-mvnext-module-infrastructure-settings](https://github.com/ci-and-cd/topinfra-maven/tree/develop/topinfra-mvnext-module-infrastructure-settings)

```bash
mvn coreext:check
mvn coreext:install
```

if src/main/resources/Dockerfile absent or CI_OPT_MVN_DEPLOY_PUBLISH_SEGREGATION=true (use script),
no docker image is built at package phase.
see profile 'dockerfile_maven_plugin-lifecycle_binding-when-not-publish_deploy_segregation' in pom.xml.

You need to provide few properties and environment variables, see next chapter.


## II. Properties, Environment variables and their default values

### 1. fetch or deploy
- private.nexus3
> default: http://nexus3:28081/nexus/repository
Set this property to a real world url.

- private.nexus3
> default: http://nexus3.localal:28081/nexus/repository
Set this property to a real world url.

- publish.channel TODO publish.channel deprecated
> default: snapshot
Set this property to 'release' when building release artifact.
Note: CI_OPT_GITHUB_GLOBAL_REPOSITORYOWNER

### 2. maven-surefire-plugin and maven-failsafe-plugin

- maven.test.skip
> default: false

- maven.test.failure.ignore
> default: false

- skipITs
> default: false

- skipTests
> default: false

### 3. com.github.eirslett:frontend-maven-plugin
- frontend.nodeDownloadRoot
> default: https://nodejs.org/dist/

- frontend.npmDownloadRoot
> default: http://registry.npmjs.org/npm/-/

Customize these properties only when building front-end projects and default sites are not reachable.

### 4. report
#### 4.1 sonarqube
- private.sonar.host.url
> default: http://sonarqube:9000
- private.sonar.host.url
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
> default: ${project.artifactId}-${publish.channel} TODO update doc
Customize this properties if you want to publish relative projects's site into same parent directory, 
use same value on relative projects.

- CI_OPT_OSSRH_GIT_AUTH_TOKEN
> default: N/A (blank)
- CI_OPT_GITHUB_GLOBAL_REPOSITORYOWNER
> default: N/A (blank)

Need these properties only when deploy site to github.com.

### 6. GPG
- CI_OPT_GPG_KEYNAME
> default: N/A (blank)
- CI_OPT_GPG_PASSPHRASE
> default: N/A (blank)

If you see 'gpg: signing failed: Inappropriate ioctl for device' on OSX with gpg (2.2.x) installed by homebrew
Edit config files:
~/.gnupg/gpg-agent.conf
```text
allow-loopback-pinentry
```
~/.gnupg/gpg.conf
```text
use-agent
pinentry-mode loopback
```

Need these properties only when deploy artifacts into maven central repository.

### 7. maven central
- CI_OPT_OSSRH_NEXUS2_USER
> Maven central's username
- CI_OPT_OSSRH_NEXUS2_PASS
> Maven central's password

Need these properties only when deploy artifacts into maven central repository.

### 8. maven-compiler-plugin and maven-javadoc-plugin
- project.build.sourceEncoding
> default: UTF-8

### 9. docker

com.spotify:dockerfile-maven-plugin

- docker.registry


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

### 4. docker

io.fabric8:docker-maven-plugin

com.spotify:dockerfile-maven-plugin
> clean, build, push docker images

maven-antrun-plugin
> clean filtered '${project.basedir}/src/main/docker/Dockerfile'

maven-resources-plugin
> copy and filter contents from 'src/main/resources/docker' into '${project.basedir}/src/main/docker'

maven-deploy-plugin
> must run after docker-maven-plugin

## IV. Profiles

### 1. build
infrastructure_ossrh
> Use maven central service.
Deploy maven site to github.

infrastructure_private
> Use nexus service at organization private (internal) network.
Deploy maven site into organization private (internal) mvnsite.

infrastructure_local
> Use nexus service at user's local (see [docker-nexus3](../../docker-nexus3/README.html)).
Deploy maven site into local mvnsite (see [docker-proxy](../../docker-proxy/README.html)).

git-commit-id
> Generate src/main/resources/git.properties.
activate automatically if '${maven.multiModuleProjectDirectory}/.git/HEAD' exists

mvn-deploy-publish-segregation-by-wagon
> activate by set 'mvn.deploy.publish.segregation' to 'true'

jacoco-build
> Test coverage report.
activate by property 'jacoco' absent (Enabled by default, to disable, set `-Djacoco=false`)

cobertura
> activate by set property 'jacoco' to 'false'

```bash
JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk-11.0.2.jdk/Contents/Home" mvn help:active-profiles clean package

JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk-10.jdk/Contents/Home" mvn help:active-profiles clean package

JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk-9.0.4.jdk/Contents/Home" mvn help:active-profiles clean package

JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk1.8.0_201.jdk/Contents/Home" mvn help:active-profiles clean package
```

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

infrastructure_ossrh_site_publish
> publish project site to github  
activate on property 'github.site.publish' is true  
needs:  
env.CI_OPT_OSSRH_GIT_AUTH_TOKEN  
env.CI_OPT_GITHUB_GLOBAL_REPOSITORYOWNER


### 4. docker

dockerfile_maven_plugin-lifecycle_binding-when-not-publish_deploy_segregation
> activate by property 'mvn.deploy.publish.segregation' absent
build and push docker image automatically

## V. Repositories

central, spring-libs-release, spring-milestone, spring-libs-snapshot


## VI. Jira and gitlab integration

Add args on `maven site` 

    jira.projectKey         # jira projectKey
    jira.user               # jira username
    jira.password           # jira password


## VII. Appendices


## A. Example ~/.docker/daemon.json of Docker for Mac
```json
{
  "debug" : true,
  "experimental" : true,
  "registry-mirrors" : [
    "https://docker.mirrors.ustc.edu.cn",
    "http://hub-mirror.c.163.com",
    "http://mirror.gcr.io"
  ]
}
```

### B. Contribution to maven-build

#### B.1. local install/deploy maven-build

    export MAVEN_HOME="${PWD}/../extension-core/target/apache-maven-3.6.1/apache-maven-3.6.1"

    cp src/main/maven/settings-global.xml /usr/local/Cellar/maven/3.6.1/libexec/conf/settings.xml
    cp src/main/maven/settings-global.xml ~/.m2/wrapper/dists/topinfra-maven-dist-0.0.1-20190710.085622-33/7nshe2k13lvltgpe5mc3ibvhrg/apache-maven-3.6.1/conf/settings.xml
    
    CI_OPT_INFRASTRUCTURE=ossrh ./mvnw -e -U clean install
    
    CI_OPT_INFRASTRUCTURE=ossrh CI_OPT_ORIGIN_REPO=true CI_OPT_SONAR=true CI_OPT_SONAR_LOGIN= CI_OPT_SONAR_ORGANIZATION=home1-oss-github ./mvnw -e sonar:sonar
    
    CI_OPT_GITHUB_SITE_PUBLISH="true" CI_OPT_INFRASTRUCTURE=ossrh CI_OPT_OSSRH_GIT_AUTH_TOKEN="${CI_OPT_OSSRH_GIT_AUTH_TOKEN}" CI_OPT_SITE="true" CI_OPT_GITHUB_GLOBAL_REPOSITORYOWNER="ci-and-cd" CI_OPT_SITE_PATH_PREFIX="maven-build" ./mvnw -e -U clean install site-deploy
    
    CI_OPT_GITHUB_SITE_PUBLISH="false" CI_OPT_INFRASTRUCTURE=ossrh CI_OPT_OSSRH_MVNSITE_PASSWORD="${CI_OPT_OSSRH_MVNSITE_PASSWORD}" CI_OPT_OSSRH_MVNSITE_USERNAME="${CI_OPT_OSSRH_MVNSITE_USERNAME}" CI_OPT_NEXUS3="https://nexus3.infra.top" CI_OPT_SITE="true" CI_OPT_SITE_PATH_PREFIX="ci-and-cd/maven-build" ./mvnw -e -U clean install site site:stage site:stage-deploy

#### B.2 Pull request

Please open PR on develop branch.

### C. GPG issues
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

### References
see: https://github.com/APNIC-net/repositoryd/blob/master/pom.xml

see: https://github.com/stevespringett/dependency-check-sonar-plugin/tree/SonarQube_6.x
see: https://docs.sonarqube.org/display/PLUG/JaCoCo+Plugin

Java 11
see: https://dzone.com/articles/apis-to-be-removed-from-java-11
see: https://medium.com/criciumadev/its-time-migrating-to-java-11-5eb3868354f9
see: https://dzone.com/articles/migrating-springboot-applications-to-latest-java-v
