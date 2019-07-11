#!/usr/bin/env bash

# usage: ./src/main/ci-script/lib_ci_tests.sh | grep ASSERT

if [ -z "${CI_OPT_PRIVATE_GIT_AUTH_TOKEN}" ]; then echo "Error, please set CI_OPT_PRIVATE_GIT_AUTH_TOKEN"; exit 1; fi

export CI_OPT_GIT_AUTH_TOKEN="${CI_OPT_PRIVATE_GIT_AUTH_TOKEN}"
export CI_OPT_CI_SCRIPT="src/main/ci-script/lib_ci.sh"
export CI_OPT_DRYRUN="true"

TEST_LOG="/tmp/lib_ci_test.log"

# arguments: expected, grep_expr
function assert_log() {
    local actual=$(cat ${TEST_LOG} | grep -E "$2" | tail -1)
    if [ "${actual}" == "$1" ]; then
        echo "ASSERT OK, expected: $1"
    else
        echo "ASSERT FAILED, expected: $1, actual: ${actual}"
    fi
}


rm -f ${TEST_LOG}
exec 3> >(tee ${TEST_LOG})
./src/main/ci-script/lib_ci.sh mvn -Dxxx=yyy clean compile package >&3
assert_log "alter_mvn result: mvn -Dxxx=yyy clean compile package" "alter_mvn result: "


rm -f ${TEST_LOG}
exec 3> >(tee ${TEST_LOG})
CI_OPT_MVN_DEPLOY_PUBLISH_SEGREGATION="true" \
./src/main/ci-script/lib_ci.sh mvn clean install >&3
assert_log "alter_mvn result: mvn clean org.apache.maven.plugins:maven-antrun-plugin:run@wagon-repository-clean deploy" "alter_mvn result: "


rm -f ${TEST_LOG}
exec 3> >(tee ${TEST_LOG})
CI_OPT_MVN_DEPLOY_PUBLISH_SEGREGATION="true" \
CI_OPT_MAVEN_CLEAN_SKIP="true" \
CI_OPT_SKIPITS="true" \
CI_OPT_MAVEN_TEST_SKIP="true" \
./src/main/ci-script/lib_ci.sh mvn deploy >&3
assert_log "alter_mvn result: mvn org.codehaus.mojo:wagon-maven-plugin:merge-maven-repos@merge-maven-repos-deploy" "alter_mvn result: "
assert_log "CI_OPT_MAVEN_CLEAN_SKIP=true" "^CI_OPT_MAVEN_CLEAN_SKIP="
assert_log "CI_OPT_SKIPITS=true" "^CI_OPT_SKIPITS="
assert_log "CI_OPT_MAVEN_TEST_SKIP=true" "^CI_OPT_MAVEN_TEST_SKIP="


rm -f ${TEST_LOG}
exec 3> >(tee ${TEST_LOG})
CI_OPT_MVN_DEPLOY_PUBLISH_SEGREGATION="true" \
CI_OPT_DOCKER="true" \
./src/main/ci-script/lib_ci.sh mvn deploy >&3
assert_log "alter_mvn result: mvn org.codehaus.mojo:wagon-maven-plugin:merge-maven-repos@merge-maven-repos-deploy docker:build docker:push" "alter_mvn result: "
