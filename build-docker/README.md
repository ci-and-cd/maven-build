# maven-docker
Parent pom for docker projects

## Plugins

io.fabric8:docker-maven-plugin

com.spotify:docker-maven-plugin
> clean, build, push docker images

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

## Example ~/.docker/daemon.json of Docker for Mac
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
