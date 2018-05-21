# maven-build
Parent pom for maven based projects

## Repositories

central, spring-libs-release, spring-milestone, spring-libs-snapshot

## Plugins

com.github.eirslett:frontend-maven-plugin

com.amashchenko.maven.plugin:gitflow-maven-plugin

maven-compiler-plugin with errorprone

maven-enforcer-plugin

maven-surefire-plugin and maven-failsafe-plugin with includes and excludes configuration

pl.project13.maven:git-commit-id-plugin

## Profiles

git-commit-id
> activate automatically if '${maven.multiModuleProjectDirectory}/.git/HEAD' exists

publish-deploy-segregation-with-wagon
> activate by set 'publish_deploy_segregation' to 'true'

jacoco-build
> activate by property 'jacoco' absent

cobertura
> activate by set property 'jacoco' to 'false'

## Properties and default values

maven-compiler-plugin and maven-javadoc-plugin

- project.build.sourceEncoding
> UTF-8

-----

maven-surefire-plugin and maven-failsafe-plugin

- maven.test.skip
> false

- maven.integration-test.skip
> false

- maven.test.failure.ignore
> false

-----

com.github.eirslett:frontend-maven-plugin

- frontend.nodeDownloadRoot
> https://nodejs.org/dist/

- frontend.npmDownloadRoot
> http://registry.npmjs.org/npm/-/
