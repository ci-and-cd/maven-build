#!/usr/bin/env bash

if [ -f codesigning.asc.enc ] && [ "${TRAVIS_PULL_REQUEST}" == 'false' ]; then openssl aes-256-cbc -K ${encrypted_f1fe46eea14b_key} -iv ${encrypted_f1fe46eea14b_iv} -in codesigning.asc.enc -out codesigning.asc -d; fi

# >>>>>>>>>> ---------- override options ---------- >>>>>>>>>>
export CI_OPT_SITE_PATH_PREFIX="oss"
export CI_OPT_SONAR="true"
# <<<<<<<<<< ---------- override options ---------- <<<<<<<<<<




# >>>>>>>>>> ---------- call remote script ---------- >>>>>>>>>>
if [ -z "${CI_OPT_CI_SCRIPT}" ]; then CI_OPT_CI_SCRIPT="https://github.com/ci-and-cd/maven-build/raw/master/src/main/ci-script/lib_ci.sh"; fi
#echo "eval \$(curl -s -L ${CI_OPT_CI_SCRIPT})"
source src/main/ci-script/lib_ci.sh
# <<<<<<<<<< ---------- call remote script ---------- <<<<<<<<<<
