# build-site
Parent pom for maven projects that build maven site

## Plugins

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

## Profiles

github
> publish project site to github  
activate on property 'github-publish' present  
needs:  
env.GITHUB_INFRASTRUCTURE_CONF_GIT_TOKEN  
env.GITHUB_SITE_REPO_OWNER

## Properties and default values

- build.publish.channel
> snapshot

- site.path
> ${project.artifactId}-${build.publish.channel}
