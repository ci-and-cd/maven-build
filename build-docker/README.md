# maven-docker
Parent pom for docker projects

## Plugins

io.fabric8:docker-maven-plugin

com.spotify:docker-maven-plugin
> clean, build, deploy docker images

maven-antrun-plugin
> clean filtered '${project.basedir}/src/main/docker/Dockerfile'

maven-resources-plugin
> copy and filter contents from 'src/main/resources/docker' into '${project.basedir}/src/main/docker'

maven-deploy-plugin
> must run after docker-maven-plugin

## Profiles

docker-maven-plugin-lifecycle-binding-when-not-publish-deploy-segregation
> activate by property 'publish_deploy_segregation' absent
build and push docker image automatically

## Properties and default values

maven-compiler-plugin and maven-javadoc-plugin

- docker.registry
> registry.docker.local
