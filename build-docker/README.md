# maven-docker
Parent pom for docker projects

## I. Usage


if src/main/resources/Dockerfile absent or CI_OPT_MVN_DEPLOY_PUBLISH_SEGREGATION=true (use script),
no docker image is built at package phase.
see profile 'docker-maven-plugin-lifecycle-binding-when-not-publish-deploy-segregation' in docker-build/pom.xml.


## II. Properties and default values

com.spotify:dockerfile-maven-plugin

- docker.registry


## III. Plugins

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

docker-maven-plugin-lifecycle-binding-when-not-publish-deploy-segregation
> activate by property 'mvn_deploy_publish_segregation' absent
build and push docker image automatically

## VI. Appendices

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
