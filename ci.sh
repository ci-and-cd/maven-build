#!/usr/bin/env bash


echo -e "\n>>>>>>>>>> ---------- custom, override options ---------- >>>>>>>>>>"
export CI_OPT_SITE_PATH_PREFIX="ci-and-cd"
export CI_OPT_GITHUB_SITE_REPO_OWNER="home1-oss"
export CI_OPT_GPG_KEYNAME="59DBF10E"
export CI_OPT_SONAR_ORGANIZATION="home1-oss-github"
export CI_OPT_SONAR="true"
echo -e "<<<<<<<<<< ---------- custom, override options ---------- <<<<<<<<<<\n"


echo -e "\n>>>>>>>>>> ---------- call remote script ---------- >>>>>>>>>>"
if [ -z "${CI_OPT_CI_SCRIPT}" ]; then CI_OPT_CI_SCRIPT="https://github.com/ci-and-cd/maven-build/raw/master/src/main/ci-script/lib_ci.sh"; fi
echo "source src/main/ci-script/lib_ci.sh"
source src/main/ci-script/lib_ci.sh
echo -e "<<<<<<<<<< ---------- call remote script ---------- <<<<<<<<<<\n"
