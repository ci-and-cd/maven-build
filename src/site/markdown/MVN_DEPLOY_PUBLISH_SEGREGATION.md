
# Maven mvn deploy and artifacts publish segregation

Split `mvn deploy` and "artifacts publish" into two stages.

First deploy artifacts into a local location when running `mvn deploy`, 
then run another command to publish them and their docker image into a remote repository.

This make build process more flexible for most CI systems.


- CI_OPT_MVN_DEPLOY_PUBLISH_SEGREGATION
> default: not equals to 'true'


## maven goals actually executed upon different situations

| Command           | segregation/infrastructure | maven goals                                                                                                |
|-------------------|:--------------------------:|:----------------------------------------------------------------------------------------------------------:|
| clean             | true/any                   | `clean org.apache.maven.plugins:maven-antrun-plugin:run@local-deploy-model-path-clean`                     |
|                   |                            |                                                                                                            |
| clean             | false/any                  | `clean`                                                                                                    |
|                   |                            |                                                                                                            |
| test_and_build    | true/any                   | `deploy`                                                                                                   |
|                   |                            |                                                                                                            |
| test_and_build    | false/any                  | `install`                                                                                                  |
|                   |                            |                                                                                                            |
| publish_artifact  | true/any                   | `org.codehaus.mojo:wagon-maven-plugin:merge-maven-repos@merge-maven-repos-deploy docker:build docker:push` |
|                   |                            |                                                                                                            |
| publish_artifact  | false/any                  | `deploy`                                                                                                   |
|                   |                            |                                                                                                            |
| publish_site      | any/github                 | `site site-deploy`                                                                                         |
|                   |                            |                                                                                                            |
| publish_site      | any/not github             | `site site:stage site:stage-deploy`                                                                        |
|                   |                            |                                                                                                            |
