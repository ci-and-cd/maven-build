# build-report-and-doc
Parent pom for maven projects that build reports and docs

## Plugins

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

## Profiles

spring-restdocs
> activate by set property 'spring-restdocs' to 'true'

reports-for-site
> activate by set property 'site' to 'true'

jacoco-report
> activate by property 'jacoco' absent

dependency-check
> activate by set property 'dependency-check' to 'true'

clirr
> activate by set property 'site' to 'true'

sonar
> activate by property 'sonar' present

## Properties and default values

maven-checkstyle-plugin and maven-pmd-plugin

- checkstyle.config.location
> https://raw.githubusercontent.com/home1-oss/maven-build/master/src/main/checkstyle/google_checks_8.10.xml

- pmd.ruleset.location
> https://raw.githubusercontent.com/home1-oss/maven-build/master/src/main/pmd/pmd-ruleset-6.0.1.xml
