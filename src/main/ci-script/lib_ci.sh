# no shebang line here

# download a file by curl
# arguments: curl_source, curl_target, curl_option
function download() {
    local curl_source="$1"
    local curl_target="$2"
    local curl_default_options="-H 'Cache-Control: no-cache' -L -s -t utf-8"
    local curl_option="$3 ${curl_default_options}"
    local curl_secret="$(echo $3 | sed -E 's#: [^ ]+#: <secret>#g') ${curl_default_options}"
    echo "curl ${curl_secret} -o ${curl_target} ${curl_source}"
    curl ${curl_option} -o ${curl_target} ${curl_source}
}

# download a file by curl only when file exists
# arguments: curl_source, curl_target, curl_option
function download_if_exists() {
    local curl_source="$1"
    local curl_target="$2"
    local curl_default_options="-H 'Cache-Control: no-cache' -L -s -t utf-8"
    local curl_option="$3 ${curl_default_options}"
    local curl_secret="$(echo $3 | sed -E 's#: [^ ]+#: <secret>#g') ${curl_default_options}"
    echo "Test whether remote file exists: curl -I -o /dev/null -s -w \"%{http_code}\" ${curl_secret} ${curl_source} | tail -n1"
    curl_status=$(curl -I -o /dev/null -s -w "%{http_code}" ${curl_option} ${curl_source} | tail -n1) || echo "error reading remote file."
    echo "curl_status: ${curl_status}"
    if [ "200" == "${curl_status}" ]; then
        echo "Download file: curl -o ${curl_target} ${curl_secret} ${curl_source} > /dev/null"
        curl -o ${curl_target} ${curl_option} ${curl_source} > /dev/null
    fi
}

# build a filter_script file
# filter_script filters maven or gradle's verbose output
# arguments: target_file
# returns: path of the filter_script
function filter_script() {
    local target_file="$1"

cat >${target_file} <<EOL
# filter log output
# reduce log avoid travis 4MB limit
while IFS='' read -r LINE
do
    echo "\${LINE}" \
        | grep -v 'Downloading:' \
        | grep -Ev '^Progress ' \
        | grep -Ev '^Generating .+\.html\.\.\.'
done
EOL

    chmod 755 ${target_file}
    echo "${target_file}"
}

# get slug info of current repository (directory)
# return: 'group/project' or 'owner/project'
function git_repo_slug() {
    # test cases
    # echo "Fetch URL: http://user@pass:gitservice.org:20080/owner/repo.git" | ruby -ne 'puts /^\s*Fetch.*(:|\/){1}([^\/]+\/[^\/]+).git/.match($_)[2] rescue nil'
    # echo "Fetch URL: Fetch URL: git@github.com:home1-oss/oss-build.git" | ruby -ne 'puts /^\s*Fetch.*(:|\/){1}([^\/]+\/[^\/]+).git/.match($_)[2] rescue nil'
    # echo "Fetch URL: https://github.com/owner/repo.git" | ruby -ne 'puts /^\s*Fetch.*(:|\/){1}([^\/]+\/[^\/]+).git/.match($_)[2] rescue nil'
    echo $(git remote show origin -n | ruby -ne 'puts /^\s*Fetch.*(:|\/){1}([^\/]+\/[^\/]+).git/.match($_)[2] rescue nil')
}


# >>>>>>>>>> ---------- CI option functions ---------- >>>>>>>>>>
# returns: git commit id
function build_opt_git_commit_id() {
    if [ -n "${BUILD_OPT_GIT_COMMIT_ID}" ]; then
        echo "${BUILD_OPT_GIT_COMMIT_ID}"
    else
        echo "$(git rev-parse HEAD)"
    fi
}

function build_opt_cache_directory() {
    local cache_directory=""
    if [ -n "${BUILD_OPT_CACHE_DIRECTORY}" ]; then
        cache_directory="${BUILD_OPT_CACHE_DIRECTORY}"
    else
        cache_directory="${HOME}/.oss/tmp/$(build_opt_git_commit_id)"
    fi
    mkdir -p ${cache_directory} 2>/dev/null
    echo "${cache_directory}"
}

# auto detect current build ref name by CI environment variables or local git info
# ${CI_BUILD_REF_NAME} show branch or tag since GitLab-CI 5.2
# CI_BUILD_REF_NAME for gitlab 8.x, see: https://gitlab.com/help/ci/variables/README.md
# CI_COMMIT_REF_NAME for gitlab 9.x, see: https://gitlab.com/help/ci/variables/README.md
# TRAVIS_BRANCH for travis-ci, see: https://docs.travis-ci.com/user/environment-variables/
# returns: current build ref name, i.e. develop, release ...
function build_opt_ref_name() {
    if [ -n "${BUILD_REF_NAME}" ]; then
        echo "${BUILD_REF_NAME}"
    elif [ -n "${TRAVIS_BRANCH}" ]; then
        echo "${TRAVIS_BRANCH}"
    elif [ -n "${CI_BUILD_REF_NAME}" ]; then
        echo "${CI_BUILD_REF_NAME}"
    elif [ -n "${CI_COMMIT_REF_NAME}" ]; then
        echo "${CI_COMMIT_REF_NAME}"
    else
        echo "$(git symbolic-ref -q --short HEAD || git describe --tags --exact-match)"
    fi
}

# auto determine current build publish channel by current build ref name
# arguments: build_opt_ref_name
function build_opt_publish_channel() {
    if [ -n "${BUILD_OPT_PUBLISH_CHANNEL}" ]; then
        echo "${BUILD_OPT_PUBLISH_CHANNEL}"
    else
        case "$(build_opt_ref_name)" in
        "develop")
            echo "snapshot"
            ;;
        "master")
            echo "release"
            ;;
        release*)
            echo "release"
            ;;
        *)
            echo "snapshot"
            ;;
        esac
    fi
}

function build_opt_site() {
    if [ -n "${BUILD_OPT_SITE}" ]; then
        echo "${BUILD_OPT_SITE}"
    else
        echo "false"
    fi
}

function build_opt_site_path_prefix() {
    if [ -n "${BUILD_OPT_SITE_PATH_PREFIX}" ]; then
        echo "${BUILD_OPT_SITE_PATH_PREFIX}"
    else
        echo $(echo $(git_repo_slug) | cut -d '/' -f2-)
    fi
}
# <<<<<<<<<< ---------- CI option functions ---------- <<<<<<<<<<


# >>>>>>>>>> ---------- CI option functions about infrastructures ---------- >>>>>>>>>>
# auto detect infrastructure using for this build.
# example of gitlab-ci's CI_PROJECT_URL: "https://example.com/gitlab-org/gitlab-ce"
# returns: github, internal or local
function infrastructure() {
    if [ -n "${INFRASTRUCTURE}" ]; then
        echo ${INFRASTRUCTURE}
    elif [ -n "${TRAVIS_REPO_SLUG}" ]; then
        echo "github"
    elif [ -n "${CI_PROJECT_URL}" ] && [[ "${CI_PROJECT_URL}" == ${INFRASTRUCTURE_INTERNAL_GIT_PREFIX}* ]]; then
        echo "internal"
    else
        echo "local"
    fi
}

# auto determine INFRASTRUCTURE_OPT_GIT_PREFIX by infrastructure for further download.
# returns: prefix of git service url (infrastructure specific), i.e. https://github.com
function infrastructure_opt_git_prefix() {
    local infrastructure="$(infrastructure)"
    if [ -n "${INFRASTRUCTURE_OPT_GIT_PREFIX}" ]; then
        echo "${INFRASTRUCTURE_OPT_GIT_PREFIX}"
    elif [ "github" == "${infrastructure}" ]; then
        if [ -n "${INFRASTRUCTURE_GITHUB_GIT_PREFIX}" ]; then echo "${INFRASTRUCTURE_GITHUB_GIT_PREFIX}"; else echo "https://github.com"; fi
    elif [ "internal" == "${infrastructure}" ]; then
        if [ -n "${CI_PROJECT_URL}" ]; then
            echo $(echo "${CI_PROJECT_URL}" | sed 's,/*[^/]\+/*$,,' | sed 's,/*[^/]\+/*$,,')
        else
            if [ -n "${INFRASTRUCTURE_INTERNAL_GIT_PREFIX}" ]; then echo "${INFRASTRUCTURE_INTERNAL_GIT_PREFIX}"; else echo "http://gitlab.internal"; fi
        fi
    else
        if [ -n "${INFRASTRUCTURE_LOCAL_GIT_PREFIX}" ]; then echo "${INFRASTRUCTURE_LOCAL_GIT_PREFIX}"; else echo "http://gitlab.local:10080"; fi
    fi
}

function infrastructure_opt_git_auth_token() {
    if [ -n "${INFRASTRUCTURE_OPT_GIT_AUTH_TOKEN}" ]; then
        echo "${INFRASTRUCTURE_OPT_GIT_AUTH_TOKEN}"
    else
        local var_name="INFRASTRUCTURE_$(echo $(infrastructure) | tr '[:lower:]' '[:upper:]')_GIT_AUTH_TOKEN"
        if [ -n "${BASH_VERSION}" ]; then
            echo "${!var_name}"
        elif [ -n "${ZSH_VERSION}" ]; then
            echo "${(P)var_name}"
        else
            (>&2 echo "unsupported ${SHELL}")
            exit 1
        fi
    fi
}
# <<<<<<<<<< ---------- CI option functions about infrastructures ---------- <<<<<<<<<<


# Build MAVEN_OPTS by EXTRA_MAVEN_OPTS from BUILD_OPT_CI_OPTS_SCRIPT and BUILD_OPT_*
function build_mvn_opts() {
    local opts="${EXTRA_MAVEN_OPTS} -Dbuild.publish.channel=$(build_opt_publish_channel)"
    if [ -n "${BUILD_OPT_CHECKSTYLE_CONFIG_LOCATION}" ]; then opts="${opts} -Dcheckstyle.config.location=${BUILD_OPT_CHECKSTYLE_CONFIG_LOCATION}"; fi
    if [ "${BUILD_OPT_DEPENDENCY_CHECK}" == "true" ]; then opts="${opts} -Ddependency-check=true"; fi
    if [ -n "${INFRASTRUCTURE_OPT_DOCKER_REGISTRY}" ]; then opts="${opts} -Ddocker.registry=${INFRASTRUCTURE_OPT_DOCKER_REGISTRY}"; fi
    opts="${opts} -Dfile.encoding=UTF-8"
    if [ -n "${BUILD_OPT_FRONTEND_NODEDOWNLOADROOT}" ]; then opts="${opts} -Dfrontend.nodeDownloadRoot=${BUILD_OPT_FRONTEND_NODEDOWNLOADROOT}"; fi
    if [ -n "${BUILD_OPT_FRONTEND_NPMDOWNLOADROOT}" ]; then opts="${opts} -Dfrontend.npmDownloadRoot=${BUILD_OPT_FRONTEND_NPMDOWNLOADROOT}"; fi
    opts="${opts} -Dinfrastructure=$(infrastructure)"
    if [ "${BUILD_OPT_INTEGRATION_TEST_SKIP}" == "true" ]; then opts="${opts} -Dmaven.integration-test.skip=true"; fi
    if [ "${BUILD_OPT_TEST_FAILURE_IGNORE}" == "true" ]; then opts="${opts} -Dmaven.test.failure.ignore=true"; fi
    if [ "${BUILD_OPT_TEST_SKIP}" == "true" ]; then opts="${opts} -Dmaven.test.skip=true"; fi
    if [ "${BUILD_OPT_MVN_DEPLOY_PUBLISH_SEGREGATION}" == "true" ]; then opts="${opts} -Dmvn_deploy_publish_segregation=true"; fi
    if [ -n "${BUILD_OPT_PMD_RULESET_LOCATION}" ]; then opts="${opts} -Dpmd.ruleset.location=${BUILD_OPT_PMD_RULESET_LOCATION}"; fi
    opts="${opts} -Dsite=$(build_opt_site)"
    opts="${opts} -Dsite.path=$(build_opt_site_path_prefix)-$(build_opt_publish_channel)"
    if [ "${BUILD_OPT_SONAR}" == "true" ]; then opts="${opts} -Dsonar=true"; fi
    opts="${opts} -Duser.language=zh -Duser.region=CN -Duser.timezone=Asia/Shanghai"
    if [ -n "${BUILD_OPT_WAGON_SOURCE_FILEPATH}" ]; then opts="${opts} -Dwagon.source.filepath=${BUILD_OPT_WAGON_SOURCE_FILEPATH} -DaltDeploymentRepository=repo::default::file://${BUILD_OPT_WAGON_SOURCE_FILEPATH}"; fi

    if [ -n "${INFRASTRUCTURE_OPT_SONAR_HOST_URL}" ]; then opts="${opts} -D$(infrastructure)-sonar.host.url=${INFRASTRUCTURE_OPT_SONAR_HOST_URL}"; fi
    if [ -n "${INFRASTRUCTURE_OPT_NEXUS3}" ]; then opts="${opts} -D$(infrastructure)-nexus3.repository=${INFRASTRUCTURE_OPT_NEXUS3}/nexus/repository"; fi

    # MAVEN_OPTS that need to kept secret
    if [ -n "${BUILD_OPT_JIRA_PROJECTKEY}" ]; then opts="${opts} -Djira.projectKey=${BUILD_OPT_JIRA_PROJECTKEY} -Djira.user=${BUILD_OPT_JIRA_USER} -Djira.password=${BUILD_OPT_JIRA_PASSWORD}"; fi
    # public sonarqube config, see: https://sonarcloud.io
    if [ "github" == "$(infrastructure)" ]; then opts="${opts} -Dsonar.organization=${BUILD_OPT_SONAR_ORGANIZATION} -Dsonar.login=${BUILD_OPT_SONAR_LOGIN_TOKEN}"; fi
    if [ -n "${BUILD_OPT_MAVEN_SETTINGS_SECURITY_FILE}" ] && [ -f "${BUILD_OPT_MAVEN_SETTINGS_SECURITY_FILE}" ]; then opts="${opts} -Dsettings.security=${BUILD_OPT_MAVEN_SETTINGS_SECURITY_FILE}"; fi

    echo "${opts}"
}


# check if current repository is a spring-cloud-configserver's config repository
function is_config_repository() {
    if [[ "$(basename $(pwd))" == *-config ]] && ([ -f "application.yml" ] || [ -f "application.properties" ]); then
        return
    fi
    false
}


# key line to make whole build process file when command using pipelines fails
set -e && set -o pipefail


# >>>>>>>>>> ---------- build context info ---------- >>>>>>>>>>
echo "gitlab-ci variables: CI_BUILD_REF_NAME: ${CI_BUILD_REF_NAME}, CI_COMMIT_REF_NAME: ${CI_COMMIT_REF_NAME}, CI_PROJECT_URL: ${CI_PROJECT_URL}"
echo "travis-ci variables: TRAVIS_BRANCH: ${TRAVIS_BRANCH}, TRAVIS_EVENT_TYPE: ${TRAVIS_EVENT_TYPE}, TRAVIS_REPO_SLUG: ${TRAVIS_REPO_SLUG}"

if [ -f "${HOME}/.bashrc" ]; then source "${HOME}/.bashrc"; fi
echo "PWD: $(pwd)"
echo "USER: $(whoami)"
# <<<<<<<<<< ---------- build context info ---------- <<<<<<<<<<


# >>>>>>>>>> ---------- must have variables ---------- >>>>>>>>>>
if [ -z "${BUILD_OPT_CI_OPTS_SCRIPT}" ]; then BUILD_OPT_CI_OPTS_SCRIPT="src/main/ci-script/ci_opts_$(infrastructure).sh"; fi
echo "BUILD_OPT_CI_OPTS_SCRIPT: ${BUILD_OPT_CI_OPTS_SCRIPT}"
INFRASTRUCTURE_OPT_CONF_LOC="$(infrastructure_opt_git_prefix)/maven-build/maven-build-$(infrastructure)/raw/master"
echo "INFRASTRUCTURE_OPT_CONF_LOC: ${INFRASTRUCTURE_OPT_CONF_LOC}"
#if [ -z "$(infrastructure_opt_git_auth_token)" ]; then echo "INFRASTRUCTURE_OPT_GIT_AUTH_TOKEN not set, exit."; exit 1; else echo "INFRASTRUCTURE_OPT_GIT_AUTH_TOKEN: <secret>"; fi
#if [ -z "${BUILD_OPT_MAVEN_BUILD_REPOSITORY}" ]; then echo "BUILD_OPT_MAVEN_BUILD_REPOSITORY not set, exit."; exit 1; fi
# <<<<<<<<<< ---------- must have variables ---------- <<<<<<<<<<


# Load remote script library here


# TODO find *Dockerfile* or *docker-compose*.yml
if [ -f Dockerfile ] || [ -f src/main/resources/docker/Dockerfile ] || [ -f src/main/docker/Dockerfile ]; then
    # >>>>>>>>>> ---------- init docker config and docker login ---------- >>>>>>>>>>
    if [ ! -d "${HOME}/.docker/" ]; then echo "mkdir ${HOME}/.docker/ "; mkdir -p "${HOME}/.docker/"; fi
    # Download docker's config.json if current infrastructure has this file
    download_if_exists "${INFRASTRUCTURE_OPT_CONF_LOC}/src/main/docker/config.json" "${HOME}/.docker/config.json" "-H \"PRIVATE-TOKEN: $(infrastructure_opt_git_auth_token)\""
    # TODO NEXUS3_DEPLOYMENT_PASSWORD for docker login when using internal infrastructure
    if [ -n "${BUILD_OPT_DOCKERHUB_PASS}" ] && [ -n "${BUILD_OPT_DOCKERHUB_USER}" ]; then
        docker login -p="${BUILD_OPT_DOCKERHUB_PASS}" -u="${BUILD_OPT_DOCKERHUB_USER}" https://registry-1.docker.io/v1/
        docker login -p="${BUILD_OPT_DOCKERHUB_PASS}" -u="${BUILD_OPT_DOCKERHUB_USER}" https://registry-1.docker.io/v2/
    fi
    # <<<<<<<<<< ---------- init docker config and docker login ---------- <<<<<<<<<<
fi


if [ -f pom.xml ]; then
# >>>>>>>>>> ---------- maven settings.xml and settings-security.xml ---------- >>>>>>>>>>
    # Maven settings.xml
    if [ -z "${BUILD_OPT_MAVEN_SETTINGS}" ]; then
        if [ -z "${BUILD_OPT_MAVEN_SETTINGS_FILE}" ]; then BUILD_OPT_MAVEN_SETTINGS_FILE="$(pwd)/src/main/maven/settings-$(infrastructure).xml"; fi
        if [ ! -f "${BUILD_OPT_MAVEN_SETTINGS_FILE}" ]; then
            BUILD_OPT_MAVEN_SETTINGS_FILE="$(build_opt_cache_directory)/settings-$(infrastructure)-$(build_opt_git_commit_id).xml"
            download "${INFRASTRUCTURE_OPT_CONF_LOC}/src/main/maven/settings.xml" "${BUILD_OPT_MAVEN_SETTINGS_FILE}" "-H \"PRIVATE-TOKEN: $(infrastructure_opt_git_auth_token)\""
        fi
        export BUILD_OPT_MAVEN_SETTINGS="-s ${BUILD_OPT_MAVEN_SETTINGS_FILE}"
    fi
    echo "BUILD_OPT_MAVEN_SETTINGS: ${BUILD_OPT_MAVEN_SETTINGS}"

    # Download maven's settings-security.xml if current infrastructure has this file
    download_if_exists "${INFRASTRUCTURE_OPT_CONF_LOC}/src/main/maven/settings-security.xml" "${HOME}/.m2/settings-security.xml" "-H \"PRIVATE-TOKEN: $(infrastructure_opt_git_auth_token)\""
    # <<<<<<<<<< ---------- maven settings.xml and settings-security.xml ---------- <<<<<<<<<<


    # >>>>>>>>>> ---------- maven properties and environment variables ---------- >>>>>>>>>>
    # Load infrastructure specific ci options (BUILD_OPT_CI_OPTS_SCRIPT)
    if [ ! -f "${BUILD_OPT_CI_OPTS_SCRIPT}" ]; then
        BUILD_OPT_CI_OPTS_SCRIPT="${INFRASTRUCTURE_OPT_CONF_LOC}/src/main/ci-script/ci_opts.sh"
        echo "eval \$(curl -H 'Cache-Control: no-cache' -H \"PRIVATE-TOKEN: <secret>\" -s -L ${BUILD_OPT_CI_OPTS_SCRIPT})"
        eval "$(curl -H 'Cache-Control: no-cache' -H "PRIVATE-TOKEN: ${INFRASTRUCTURE_OPT_GIT_AUTH_TOKEN}" -s -L ${BUILD_OPT_CI_OPTS_SCRIPT})"
    else
        . ${BUILD_OPT_CI_OPTS_SCRIPT}
    fi

    export MAVEN_OPTS="$(build_mvn_opts)"

    if [ "github" == "$(infrastructure)" ]; then
        if [ -z "${BUILD_OPT_GITHUB_SITE_REPO_NAME}" ]; then export BUILD_OPT_GITHUB_SITE_REPO_NAME="$(build_opt_site_path_prefix)"; fi
        if [ -z "${BUILD_OPT_GITHUB_SITE_REPO_OWNER}" ]; then export BUILD_OPT_GITHUB_SITE_REPO_OWNER="$(echo $(git_repo_slug) | cut -d '/' -f1-)"; fi
    fi
    # <<<<<<<<<< ---------- maven properties and environment variables ---------- <<<<<<<<<<


    # >>>>>>>>>> ---------- maven and project info ---------- >>>>>>>>>>
    mvn ${BUILD_OPT_MAVEN_SETTINGS} -version

    # Maven effective pom
    # output some log to avoid travis timeout
    if [ -z "${MAVEN_EFFECTIVE_POM_FILE}" ]; then MAVEN_EFFECTIVE_POM_FILE="$(build_opt_cache_directory)/effective-pom-$(build_opt_git_commit_id).xml"; fi
    echo "MAVEN_EFFECTIVE_POM_FILE: ${MAVEN_EFFECTIVE_POM_FILE}"
    set +e
    mvn ${BUILD_OPT_MAVEN_SETTINGS} -U help:effective-pom | grep 'Downloading:' | awk '!(NR%10)'
    mvn ${BUILD_OPT_MAVEN_SETTINGS} help:effective-pom > ${MAVEN_EFFECTIVE_POM_FILE}
    if [ $? -ne 0 ]; then
        echo "error on generate effective-pom"
        cat ${MAVEN_EFFECTIVE_POM_FILE}
        exit 1
    fi
    set -e && set -o pipefail
    # <<<<<<<<<< ---------- maven and project info ---------- <<<<<<<<<<
fi


if [ -n "${GRADLE_INIT_SCRIPT}" ]; then
    if [[ "${GRADLE_INIT_SCRIPT}" == http* ]]; then
        GRADLE_INIT_SCRIPT_FILE="$(build_opt_cache_directory)/$(basename $(echo ${GRADLE_INIT_SCRIPT}))"
        curl -H 'Cache-Control: no-cache' -t utf-8 -s -L -o ${GRADLE_INIT_SCRIPT_FILE} ${GRADLE_INIT_SCRIPT}
        echo "curl -H 'Cache-Control: no-cache' -t utf-8 -s -L -o ${GRADLE_INIT_SCRIPT_FILE} ${GRADLE_INIT_SCRIPT}"
        export GRADLE_PROPERTIES="${GRADLE_PROPERTIES} --init-script ${GRADLE_INIT_SCRIPT_FILE}"
    else
        export GRADLE_PROPERTIES="${GRADLE_PROPERTIES} --init-script ${GRADLE_INIT_SCRIPT}"
    fi
fi

export GRADLE_PROPERTIES="${GRADLE_PROPERTIES} -Pinfrastructure=$(infrastructure)"
export GRADLE_PROPERTIES="${GRADLE_PROPERTIES} -PtestFailureIgnore=${BUILD_OPT_TEST_FAILURE_IGNORE}"
export GRADLE_PROPERTIES="${GRADLE_PROPERTIES} -Psettings=${BUILD_OPT_MAVEN_SETTINGS_FILE}"
if [ -n "${BUILD_OPT_MAVEN_SETTINGS_SECURITY_FILE}" ]; then
  export GRADLE_PROPERTIES="${GRADLE_PROPERTIES} -Psettings.security=${BUILD_OPT_MAVEN_SETTINGS_SECURITY_FILE}"
fi
echo "GRADLE_PROPERTIES: ${GRADLE_PROPERTIES}"

gradle --stacktrace ${GRADLE_PROPERTIES} -version
