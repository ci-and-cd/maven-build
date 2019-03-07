#!/usr/bin/env bash


#echo -e "\n>>>>>>>>>> ---------- override options ---------- >>>>>>>>>>"
#export CI_INFRA_OPT_GIT_PREFIX="https://gitlab.com"
#export CI_OPT_CI_SCRIPT="${CI_INFRA_OPT_GIT_PREFIX}/ci-and-cd/maven-build/raw/develop/src/main/ci-script/lib_ci.sh"
#echo -e "<<<<<<<<<< ---------- override options ---------- <<<<<<<<<<\n"


echo -e "\n>>>>>>>>>> ---------- default options ---------- >>>>>>>>>>"
if [[ -z ${CI_INFRA_OPT_GIT_PREFIX+x} ]]; then CI_INFRA_OPT_GIT_PREFIX="https://gitlab.com"; fi

if [[ -z ${CI_INFRA_OPT_MAVEN_BUILD_OPTS_REPO+x} ]] && [[ -n "${TRAVIS}" ]]; then CI_INFRA_OPT_MAVEN_BUILD_OPTS_REPO="${CI_INFRA_OPT_GIT_PREFIX}/ci-and-cd/maven-build-opts-opensource/raw/${TRAVIS_BRANCH:-develop}"; fi
if [[ -z ${CI_INFRA_OPT_MAVEN_BUILD_OPTS_REPO+x} ]] && [[ -n "${APPVEYOR}" ]]; then CI_INFRA_OPT_MAVEN_BUILD_OPTS_REPO="${CI_INFRA_OPT_GIT_PREFIX}/ci-and-cd/maven-build-opts-opensource/raw/${APPVEYOR:-develop}"; fi
if [[ -z ${CI_INFRA_OPT_MAVEN_BUILD_OPTS_REPO+x} ]]; then CI_INFRA_OPT_MAVEN_BUILD_OPTS_REPO="${CI_INFRA_OPT_GIT_PREFIX}/ci-and-cd/maven-build-opts-opensource/raw/master"; fi

if [[ -z ${CI_OPT_CI_SCRIPT+x} ]] && [[ -n "${TRAVIS}" ]]; then CI_OPT_CI_SCRIPT="${CI_INFRA_OPT_GIT_PREFIX}/${TRAVIS_REPO_SLUG:-ci-and-cd/maven-build}/raw/${TRAVIS_BRANCH:-develop}/src/main/ci-script/lib_ci.sh"; fi
if [[ -z ${CI_OPT_CI_SCRIPT+x} ]] && [[ -n "${APPVEYOR}" ]]; then CI_OPT_CI_SCRIPT="${CI_INFRA_OPT_GIT_PREFIX}/${APPVEYOR_REPO_NAME:-ci-and-cd/maven-build}/raw/${APPVEYOR_REPO_BRANCH:-develop}/src/main/ci-script/lib_ci.sh"; fi
if [[ -z ${CI_OPT_CI_SCRIPT+x} ]]; then CI_OPT_CI_SCRIPT="${CI_INFRA_OPT_GIT_PREFIX}/ci-and-cd/maven-build/raw/v0.3.8/src/main/ci-script/lib_ci.sh"; fi

if [[ -z ${CI_OPT_GITHUB_SITE_PUBLISH+x} ]]; then CI_OPT_GITHUB_SITE_PUBLISH="false"; fi
if [[ -z ${CI_OPT_GITHUB_SITE_REPO_OWNER+x} ]]; then CI_OPT_GITHUB_SITE_REPO_OWNER="ci-and-cd"; fi
if [[ -z ${CI_OPT_GPG_KEYNAME+x} ]]; then CI_OPT_GPG_KEYNAME="59DBF10E"; fi
if [[ -z ${CI_OPT_INFRASTRUCTURE+x} ]]; then CI_OPT_INFRASTRUCTURE="opensource"; fi

if [[ -z ${CI_OPT_MAVEN_EFFECTIVE_POM+x} ]]; then CI_OPT_MAVEN_EFFECTIVE_POM="false"; fi
if [[ -z ${CI_OPT_ORIGIN_REPO_SLUG+x} ]]; then if [[ -n "${CI_PROJECT_PATH}" ]]; then CI_OPT_ORIGIN_REPO_SLUG="ci-and-cd/maven-build"; else CI_OPT_ORIGIN_REPO_SLUG="ci-and-cd/maven-build"; fi; fi
if [[ -z ${CI_OPT_SITE+x} ]]; then CI_OPT_SITE="true"; fi
if [[ -z "${CI_OPT_SITE_PATH_PREFIX}" ]] && [[ "${CI_OPT_GITHUB_SITE_PUBLISH}" == "true" ]]; then
    # github site repo ci-and-cd/ci-and-cd (CI_OPT_GITHUB_SITE_REPO_NAME)
    CI_OPT_SITE_PATH_PREFIX="ci-and-cd"
elif [[ -z "${CI_OPT_SITE_PATH_PREFIX}" ]] && [[ "${CI_OPT_GITHUB_SITE_PUBLISH}" == "false" ]]; then
    # site in nexus3 raw repository
    CI_OPT_SITE_PATH_PREFIX="ci-and-cd/maven-build"
fi
if [[ -z ${CI_OPT_SONAR_ORGANIZATION+x} ]]; then CI_OPT_SONAR_ORGANIZATION="home1-oss-github"; fi
if [[ -z ${CI_OPT_SONAR+x} ]]; then CI_OPT_SONAR="true"; fi

#if [[ -z ${LOGGING_LEVEL_ROOT+x} ]]; then export LOGGING_LEVEL_ROOT="INFO"; fi
echo -e "<<<<<<<<<< ---------- default options ---------- <<<<<<<<<<\n"


echo -e "\n>>>>>>>>>> ---------- call remote script ---------- >>>>>>>>>>"
echo "source src/main/ci-script/lib_ci.sh"
source src/main/ci-script/lib_ci.sh
echo -e "<<<<<<<<<< ---------- call remote script ---------- <<<<<<<<<<\n"
