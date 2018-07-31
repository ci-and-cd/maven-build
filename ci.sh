#!/usr/bin/env bash


#echo -e "\n>>>>>>>>>> ---------- options in travis-ci's .travis.yml, this is for local test or debug ---------- >>>>>>>>>>"
##export CI_OPT_CI_SCRIPT="https://github.com/${TRAVIS_REPO_SLUG}/raw/${TRAVIS_BRANCH}/src/main/ci-script/lib_ci.sh"
##export CI_OPT_INFRASTRUCTURE="opensource"
#echo -e "<<<<<<<<<< ---------- options in travis-ci's .travis.yml, this is for local test or debug ---------- <<<<<<<<<<\n"


echo -e "\n>>>>>>>>>> ---------- custom, override options ---------- >>>>>>>>>>"
if [ -z "${CI_OPT_CI_SCRIPT}" ]; then CI_OPT_CI_SCRIPT="https://github.com/ci-and-cd/maven-build/raw/develop/src/main/ci-script/lib_ci.sh"; fi
if [ -z "${CI_OPT_GITHUB_SITE_REPO_OWNER}" ]; then CI_OPT_GITHUB_SITE_REPO_OWNER="home1-oss"; fi
if [ -z "${CI_OPT_GPG_KEYNAME}" ]; then CI_OPT_GPG_KEYNAME="59DBF10E"; fi
if [ -z "${CI_OPT_ORIGIN_REPO_SLUG}" ]; then CI_OPT_ORIGIN_REPO_SLUG="ci-and-cd/maven-build"; fi
if [ -z "${CI_OPT_SITE}" ]; then CI_OPT_SITE="true"; fi
if [ -z "${CI_OPT_SITE_PATH_PREFIX}" ]; then CI_OPT_SITE_PATH_PREFIX="ci-and-cd"; fi
if [ -z "${CI_OPT_SONAR_ORGANIZATION}" ]; then CI_OPT_SONAR_ORGANIZATION="home1-oss-github"; fi
if [ -z "${CI_OPT_SONAR}" ]; then CI_OPT_SONAR="true"; fi
echo -e "<<<<<<<<<< ---------- custom, override options ---------- <<<<<<<<<<\n"


echo -e "\n>>>>>>>>>> ---------- call remote script ---------- >>>>>>>>>>"
echo "source src/main/ci-script/lib_ci.sh"
source src/main/ci-script/lib_ci.sh
echo -e "<<<<<<<<<< ---------- call remote script ---------- <<<<<<<<<<\n"
