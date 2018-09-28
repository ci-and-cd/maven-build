# no shebang line here


# download a file by curl
# arguments: curl_source, curl_target, curl_option
function download() {
    local curl_source="$1"
    local curl_target="$2"
    local curl_default_options="-H \"Cache-Control: no-cache\" -L -S -s -t utf-8"
    local curl_option="$3 ${curl_default_options}"
    local curl_secret="$(echo $3 | sed -E "s#: [^ ]+#: <secret>'#g") ${curl_default_options}"
    (>&2 echo "test contents between ${curl_target} and ${curl_source}")
    if [ -f ${curl_target} ] && [ -z "$(diff ${curl_target} <(sh -c "set -e; curl ${curl_option} ${curl_source} 2>&1"))" ]; then
        (>&2 echo "contents identical, skip download")
    else
        if [ ! -d $(dirname ${curl_target}) ]; then mkdir -p $(dirname ${curl_target}); fi
        echo "curl ${curl_secret} -o ${curl_target} ${curl_source} 2>/dev/null"
        sh -c "set -e; curl ${curl_option} -o ${curl_target} ${curl_source} 2>/dev/null"
    fi
}

# download a file by curl only when file exists
# arguments: curl_source, curl_target, curl_option
function download_if_exists() {
    if [ "$(is_remote_resource_exists "$1" "$3")" == "true" ]; then
        download "$1" "$2" "$3"
    fi
}

function filter_secret_variables() {
    while read line; do
      printf "%s\n" "$line" \
        | sed -E 's#KEYNAME=.+#KEYNAME=<secret>#g' \
        | sed -E 's#ORGANIZATION=.+#ORGANIZATION=<secret>#g'\
        | sed -E 's#PASS=.+#PASS=<secret>#g' \
        | sed -E 's#PASSWORD=.+#PASSWORD=<secret>#g' \
        | sed -E 's#PASSPHRASE=.+#PASSPHRASE=<secret>#g' \
        | sed -E 's#TOKEN=.+#TOKEN=<secret>#g' \
        | sed -E 's#USER=.+#USER=<secret>#g' \
        | sed -E 's#USERNAME=.+#USERNAME=<secret>#g'
    done
}

# arguments: curl_source, curl_option
function is_remote_resource_exists() {
    local curl_source="$1"
    local curl_default_options="-H \"Cache-Control: no-cache\" -L -s -t utf-8"
    local curl_option="$2 ${curl_default_options}"
    local curl_secret="$(echo $2 | sed -E "s#: [^ ]+#: <secret>'#g") ${curl_default_options}"
    (>&2 echo "Test whether remote file exists: curl -I -o /dev/null -w \"%{http_code}\" ${curl_secret} ${curl_source} | tail -n1")
    local status_code=$(sh -c "curl -I -o /dev/null -w \"%{http_code}\" ${curl_option} ${curl_source} | tail -n1 || echo -n 500")
    (>&2 echo "status_code: ${status_code}")
    if [ "200" == "${status_code}" ]; then echo "true"; else echo "false"; fi
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
        | { grep -v 'Downloading:' || true; } \
        | { grep -Ev '^Progress ' || true; } \
        | { grep -Ev '^Generating .+\.html\.\.\.' || true; }
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
    # echo "Fetch URL: Fetch URL: git@github.com:ci-and-cd/maven-build.git" | ruby -ne 'puts /^\s*Fetch.*(:|\/){1}([^\/]+\/[^\/]+).git/.match($_)[2] rescue nil'
    # echo "Fetch URL: https://github.com/owner/repo.git" | ruby -ne 'puts /^\s*Fetch.*(:|\/){1}([^\/]+\/[^\/]+).git/.match($_)[2] rescue nil'
    local repo_slug=""
    if [ -n "${TRAVIS_REPO_SLUG}" ]; then
        repo_slug="${TRAVIS_REPO_SLUG}"
    elif [ -n "${APPVEYOR_REPO_NAME}" ]; then
        repo_slug="${APPVEYOR_REPO_NAME}"
    elif [ -n "${CI_PROJECT_PATH}" ]; then
        repo_slug="${CI_PROJECT_PATH}"
    elif [ -d .git ]; then
        repo_slug=$(git remote show origin -n | ruby -ne 'puts /^\s*Fetch.*(:|\/){1}([^\/]+\/[^\/]+).git/.match($_)[2] rescue nil')
    else
        (>&2 echo "Can not find value for git_repo_slug, exit")
        return 1
    fi
    (>&2 echo "git_repo_slug result: ${repo_slug}")
    echo "${repo_slug}"
}

# see: http://stackoverflow.com/questions/16989598/bash-comparing-version-numbers
# arguments: first_version, second_version
# return: if first_version is greater than second_version
function version_gt() {
    if [ ! -z "$(sort --help | { grep GNU || true; })" ]; then
        test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1";
    else
        test "$(printf '%s\n' "$@" | sort | head -n 1)" != "$1";
    fi
}

# >>>>>>>>>> ---------- CI option functions ---------- >>>>>>>>>>

# returns: true or false
function ci_opt_user_docker() {
    if [ -n "${CI_OPT_USE_DOCKER}" ]; then
        echo "${CI_OPT_USE_DOCKER}"
    else
        if [ -n "$(find . -name '*Docker*')" ] || [ -n "$(find . -name '*docker-compose*.yml')" ]; then
            echo "true"
        else
            echo "false"
        fi
    fi
}

# returns: git commit id
function ci_opt_git_commit_id() {
    if [ -n "${CI_OPT_GIT_COMMIT_ID}" ]; then
        echo "${CI_OPT_GIT_COMMIT_ID}"
    else
        echo "$(git rev-parse HEAD)"
    fi
}

function ci_opt_cache_directory() {
    local cache_directory=""
    if [ -n "${CI_OPT_CACHE_DIRECTORY}" ]; then
        cache_directory="${CI_OPT_CACHE_DIRECTORY}"
    else
        cache_directory="${HOME}/.ci-and-cd/tmp/$(ci_opt_git_commit_id)"
    fi
    mkdir -p ${cache_directory} 2>/dev/null
    echo "${cache_directory}"
}

# determine current is origin (original) or forked
function ci_opt_is_origin_repo() {
    if [ -n "${CI_OPT_IS_ORIGIN_REPO}" ]; then
        echo "${CI_OPT_IS_ORIGIN_REPO}"
    else
        if [ -z "${CI_OPT_ORIGIN_REPO_SLUG}" ]; then CI_OPT_ORIGIN_REPO_SLUG="unknown/unknown"; fi
        if ([ "${CI_OPT_ORIGIN_REPO_SLUG}" == "$(git_repo_slug)" ] && [ "${TRAVIS_EVENT_TYPE}" != "pull_request" ] && [ -z "${APPVEYOR_PULL_REQUEST_HEAD_REPO_NAME}" ]); then
            echo "true";
        else
            echo "false";
        fi
    fi
}

# auto detect infrastructure using for this build.
# example of gitlab-ci's CI_PROJECT_URL: "https://example.com/gitlab-org/gitlab-ce"
# returns: opensource, private or customized infrastructure name
function ci_opt_infrastructure() {
    if [ -n "${CI_OPT_INFRASTRUCTURE}" ]; then
        echo ${CI_OPT_INFRASTRUCTURE}
    elif [ -n "${TRAVIS_REPO_SLUG}" ]; then
        echo "opensource"
    elif [ -n "${CI_PROJECT_URL}" ] && [[ "${CI_PROJECT_URL}" == ${CI_INFRA_OPT_PRIVATE_GIT_PREFIX}* ]]; then
        echo "private"
    else
        echo "private"
    fi
}

# auto detect current build ref name by CI environment variables or local git info
# gitlab-ci
# ${CI_REF_NAME} show branch or tag since GitLab-CI 5.2
# CI_REF_NAME for gitlab 8.x, see: https://gitlab.com/help/ci/variables/README.md
# CI_COMMIT_REF_NAME for gitlab 9.x, see: https://gitlab.com/help/ci/variables/README.md
#
# travis-ci
# TRAVIS_BRANCH for travis-ci, see: https://docs.travis-ci.com/user/environment-variables/
# for builds triggered by a tag, this is the same as the name of the tag (TRAVIS_TAG).
#
# appveyor
# APPVEYOR_REPO_BRANCH - build branch. For Pull Request commits it is base branch PR is merging into
# APPVEYOR_REPO_TAG - true if build has started by pushed tag; otherwise false
# APPVEYOR_REPO_TAG_NAME - contains tag name for builds started by tag; otherwise this variable is
# returns: current build ref name, i.e. develop, release ...
function ci_opt_ref_name() {
    if [ -n "${CI_OPT_REF_NAME}" ]; then
        echo "${CI_OPT_REF_NAME}"
    elif [ -n "${TRAVIS_BRANCH}" ]; then
        echo "${TRAVIS_BRANCH}"
    elif [ -n "${APPVEYOR_REPO_TAG}" ]; then
        if [ "${APPVEYOR_REPO_TAG_NAME}" == "false" ]; then echo "${APPVEYOR_REPO_TAG}"; else echo "${APPVEYOR_REPO_BRANCH}"; fi
    elif [ -n "${CI_REF_NAME}" ]; then
        echo "${CI_REF_NAME}"
    elif [ -n "${CI_COMMIT_REF_NAME}" ]; then
        echo "${CI_COMMIT_REF_NAME}"
    elif [ -d .git ] || [ -f .git ]; then
        # .git is a file in git submodule
        echo "$(git symbolic-ref -q --short HEAD || git describe --tags --exact-match)"
    else
        (>&2 echo "Can not find value for CI_OPT_REF_NAME, using default value 'master'")
        echo "master"
    fi
}

# auto determine current build publish channel by current build ref name
# arguments: ci_opt_ref_name
function ci_opt_publish_channel() {
    if [ -n "${CI_OPT_PUBLISH_CHANNEL}" ]; then
        echo "${CI_OPT_PUBLISH_CHANNEL}"
    else
        case "$(ci_opt_ref_name)" in
        "develop")
            echo "snapshot"
            ;;
        hotfix*)
            echo "release"
            ;;
        release*)
            echo "release"
            ;;
        support*)
            echo "release"
            ;;
        *)
            echo "snapshot"
            ;;
        esac
    fi
}

function ci_opt_publish_to_repo() {
    if [ -n "${CI_OPT_PUBLISH_TO_REPO}" ]; then
        echo "${CI_OPT_PUBLISH_TO_REPO}"
    else
        local ref_name="$(ci_opt_ref_name)"
        if [ "$(ci_opt_is_origin_repo)" == "true" ]; then
            case "${ref_name}" in
            "develop")
                echo "true"
                ;;
            feature*)
                echo "true"
                ;;
            hotfix*)
                echo "true"
                ;;
            release*)
                echo "true"
                ;;
            support*)
                echo "true"
                ;;
            *)
                echo "false"
                ;;
            esac
        else
            case "${ref_name}" in
            "develop")
                echo "false"
                ;;
            feature*)
                echo "true"
                ;;
            hotfix*)
                echo "false"
                ;;
            release*)
                echo "false"
                ;;
            support*)
                echo "false"
                ;;
            *)
                echo "false"
                ;;
            esac
        fi
    fi
}

function ci_opt_site() {
    if [ -n "${CI_OPT_SITE}" ]; then
        echo "${CI_OPT_SITE}"
    else
        echo "false"
    fi
}

function ci_opt_site_path_prefix() {
    if [ -n "${CI_OPT_SITE_PATH_PREFIX}" ]; then
        echo "${CI_OPT_SITE_PATH_PREFIX}"
    else
        echo $(echo $(git_repo_slug) | cut -d '/' -f2-)
    fi
}
# <<<<<<<<<< ---------- CI option functions ---------- <<<<<<<<<<


# >>>>>>>>>> ---------- CI option functions about infrastructures ---------- >>>>>>>>>>
# arguments: default_value
function find_git_prefix_from_ci_script() {
    (>&2 echo "find CI_INFRA_OPT_GIT_PREFIX from CI_OPT_CI_SCRIPT: ${CI_OPT_CI_SCRIPT}, default_value: $1")
    if [[ "${CI_OPT_CI_SCRIPT}" == http* ]]; then
        echo $(echo ${CI_OPT_CI_SCRIPT} | sed -E 's#/[^/]+/[^/]+/raw/[^/]+/.+##')
    else
        echo "$1"
    fi
}

# auto determine CI_INFRA_OPT_GIT_PREFIX by infrastructure for further download.
# returns: prefix of git service url (infrastructure specific), i.e. https://github.com
function ci_infra_opt_git_prefix() {
    (>&2 echo "ci_infra_opt_git_prefix infrastructure: $(ci_opt_infrastructure), CI_OPT_CI_SCRIPT: ${CI_OPT_CI_SCRIPT}")
    if [ -n "${CI_INFRA_OPT_GIT_PREFIX}" ]; then
        echo "${CI_INFRA_OPT_GIT_PREFIX}"
    else
        local infrastructure="$(ci_opt_infrastructure)"
        local default_value=""
        if [ "opensource" == "${infrastructure}" ]; then
            default_value="https://github.com"
            CI_INFRA_OPT_GIT_PREFIX="${CI_INFRA_OPT_OPENSOURCE_GIT_PREFIX}"
        elif [ "private" == "${infrastructure}" ] || [ -z "${infrastructure}" ]; then
            default_value="http://gitlab"
            CI_INFRA_OPT_GIT_PREFIX="${CI_INFRA_OPT_PRIVATE_GIT_PREFIX}"
        fi

        if [ -z "${CI_INFRA_OPT_GIT_PREFIX}" ]; then
            CI_INFRA_OPT_GIT_PREFIX=$(find_git_prefix_from_ci_script "${default_value}")
        elif [ -n "${CI_PROJECT_URL}" ]; then
            CI_INFRA_OPT_GIT_PREFIX=$(echo "${CI_PROJECT_URL}" | sed 's,/*[^/]\+/*$,,' | sed 's,/*[^/]\+/*$,,')
        fi
        echo ${CI_INFRA_OPT_GIT_PREFIX}
    fi
}

function ci_infra_opt_git_auth_token() {
    if [ -n "${CI_INFRA_OPT_GIT_AUTH_TOKEN}" ]; then
        echo "${CI_INFRA_OPT_GIT_AUTH_TOKEN}"
    else
        local var_name="CI_INFRA_OPT_$(echo $(ci_opt_infrastructure) | tr '[:lower:]' '[:upper:]')_GIT_AUTH_TOKEN"
        (>&2 echo "ci_infra_opt_git_auth_token var_name: ${var_name}")
        if [ -n "${BASH_VERSION}" ]; then
            (>&2 echo "ci_infra_opt_git_auth_token BASH_VERSION: ${BASH_VERSION}")
            echo "${!var_name}"
        elif [ -n "${ZSH_VERSION}" ]; then
            (>&2 echo "ci_infra_opt_git_auth_token ZSH_VERSION: ${ZSH_VERSION}")
            echo "${(P)var_name}"
        else
            (>&2 echo "unsupported ${SHELL}")
            return 1
        fi
    fi
}
# <<<<<<<<<< ---------- CI option functions about infrastructures ---------- <<<<<<<<<<


# Build MAVEN_OPTS by variables from CI_OPT_CI_OPTS_SCRIPT and CI_OPT_*
function ci_opt_maven_opts() {
    if [ -n "${CI_OPT_MAVEN_OPTS}" ]; then
        echo "${CI_OPT_MAVEN_OPTS}"
    else
        local opts="${MAVEN_OPTS}"
        if [ -n "${CI_OPT_EXTRA_MAVEN_OPTS}" ]; then opts="${opts} ${CI_OPT_EXTRA_MAVEN_OPTS}"; fi

        opts="${opts} -Dbuild.publish.channel=$(ci_opt_publish_channel)"
        if [ -n "${CI_OPT_CHECKSTYLE_CONFIG_LOCATION}" ]; then opts="${opts} -Dcheckstyle.config.location=${CI_OPT_CHECKSTYLE_CONFIG_LOCATION}"; fi
        if [ "${CI_OPT_CLEAN_SKIP}" == "true" ]; then opts="${opts} -Dmaven.clean.skip=true"; fi
        if [ "${CI_OPT_DEPENDENCY_CHECK}" == "true" ]; then opts="${opts} -Ddependency-check=true"; fi

        opts="${opts} -Dgpg.executable=${GPG_EXECUTABLE}"
        if version_gt $(${GPG_EXECUTABLE} --batch=true --version | { grep -E '[0-9]+\.[0-9]+\.[0-9]+' || true; } | head -n1 | awk '{print $NF}') "2.1"; then
            opts="${opts} -Dgpg.loopback=true"
        fi

        if [ -n "${CI_INFRA_OPT_DOCKER_REGISTRY}" ] && [[ "${CI_INFRA_OPT_DOCKER_REGISTRY}" != *docker.io ]]; then opts="${opts} -Ddocker.registry=${CI_INFRA_OPT_DOCKER_REGISTRY}"; fi
        if [ -n "${CI_OPT_DOCKER_IMAGE_PREFIX}" ]; then opts="${opts} -Ddocker.image.prefix=${CI_OPT_DOCKER_IMAGE_PREFIX}"; fi
        opts="${opts} -Dfile.encoding=UTF-8"
        if [ -n "${CI_OPT_FRONTEND_NODEDOWNLOADROOT}" ]; then opts="${opts} -Dfrontend.nodeDownloadRoot=${CI_OPT_FRONTEND_NODEDOWNLOADROOT}"; fi
        if [ -n "${CI_OPT_FRONTEND_NPMDOWNLOADROOT}" ]; then opts="${opts} -Dfrontend.npmDownloadRoot=${CI_OPT_FRONTEND_NPMDOWNLOADROOT}"; fi
        opts="${opts} -Dinfrastructure=$(ci_opt_infrastructure)"
        if [ "${CI_OPT_INTEGRATION_TEST_SKIP}" == "true" ]; then opts="${opts} -Dmaven.integration-test.skip=true"; else opts="${opts} -Dmaven.integration-test.skip=false"; fi
        if [ "${CI_OPT_JACOCO}" == "true" ]; then opts="${opts} -Djacoco=true"; elif [ "${CI_OPT_JACOCO}" == "false" ]; then opts="${opts} -Djacoco=false"; fi
        if [ "${CI_OPT_TEST_FAILURE_IGNORE}" == "true" ]; then opts="${opts} -Dmaven.test.failure.ignore=true"; fi
        if [ "${CI_OPT_TEST_SKIP}" == "true" ]; then opts="${opts} -Dmaven.test.skip=true"; else opts="${opts} -Dmaven.test.skip=false"; fi
        if [ "${CI_OPT_MVN_DEPLOY_PUBLISH_SEGREGATION}" == "true" ]; then opts="${opts} -Dmvn_deploy_publish_segregation=true"; fi
        if [ -n "${CI_OPT_PMD_RULESET_LOCATION}" ]; then opts="${opts} -Dpmd.ruleset.location=${CI_OPT_PMD_RULESET_LOCATION}"; fi
        opts="${opts} -Dsite=$(ci_opt_site)"
        opts="${opts} -Dsite.path=$(ci_opt_site_path_prefix)/$(ci_opt_publish_channel)"
        if [ "$(ci_opt_site)" == "true" ] && [ "$(ci_opt_infrastructure)" == "opensource" ]; then
            if [ "${CI_OPT_GITHUB_SITE_PUBLISH}" == "true" ]; then
                opts="${opts} -Dgithub-site-publish=true"
            else
                opts="${opts} -Dgithub-site-publish=false"
            fi
        fi
        # if sonar=true, jacoco should be set to true also
        if [ "${CI_OPT_SONAR}" == "true" ]; then opts="${opts} -Dsonar=true -Djacoco=true"; fi
        opts="${opts} -Duser.language=zh -Duser.region=CN -Duser.timezone=Asia/Shanghai"
        if [ -n "${CI_OPT_WAGON_SOURCE_FILEPATH}" ]; then opts="${opts} -Dwagon.source.filepath=${CI_OPT_WAGON_SOURCE_FILEPATH} -DaltDeploymentRepository=repo::default::file://${CI_OPT_WAGON_SOURCE_FILEPATH}"; fi

        if [ "${CI_OPT_SONAR}" == "true" ] && [ -n "${CI_INFRA_OPT_SONAR_HOST_URL}" ]; then opts="${opts} -D$(ci_opt_infrastructure)-sonarqube.host.url=${CI_INFRA_OPT_SONAR_HOST_URL}"; fi
        if [ "${CI_OPT_SONAR}" == "true" ] && [ -n "${CI_OPT_SONAR_LOGIN}" ]; then opts="${opts} -Dsonar.login=${CI_OPT_SONAR_LOGIN}"; fi
        if [ "${CI_OPT_SONAR}" == "true" ] && [ -n "${CI_OPT_SONAR_LOGIN_TOKEN}" ]; then opts="${opts} -Dsonar.login=${CI_OPT_SONAR_LOGIN_TOKEN}"; fi
        if [ "${CI_OPT_SONAR}" == "true" ] && [ -n "${CI_OPT_SONAR_PASSWORD}" ]; then opts="${opts} -Dsonar.password=${CI_OPT_SONAR_PASSWORD}"; fi
        if [ -n "${CI_INFRA_OPT_NEXUS3}" ]; then opts="${opts} -D$(ci_opt_infrastructure)-nexus3.repository=${CI_INFRA_OPT_NEXUS3}/nexus/repository"; fi

        # MAVEN_OPTS that need to kept secret
        if [ -n "${CI_OPT_JIRA_PROJECTKEY}" ]; then opts="${opts} -Djira.projectKey=${CI_OPT_JIRA_PROJECTKEY} -Djira.user=${CI_OPT_JIRA_USER} -Djira.password=${CI_OPT_JIRA_PASSWORD}"; fi
        # public sonarqube config, see: https://sonarcloud.io
        if [ "${CI_OPT_SONAR}" == "true" ] && [ -n "${CI_OPT_SONAR_ORGANIZATION}" ] && [ "$(ci_opt_infrastructure)" == "opensource" ]; then opts="${opts} -Dsonar.organization=${CI_OPT_SONAR_ORGANIZATION}"; fi
        if [ -n "${CI_OPT_MAVEN_SETTINGS_SECURITY_FILE}" ] && [ -f "${CI_OPT_MAVEN_SETTINGS_SECURITY_FILE}" ]; then opts="${opts} -Dsettings.security=${CI_OPT_MAVEN_SETTINGS_SECURITY_FILE}"; fi

        echo "${opts}"
    fi
}

# Build GRADLE_PROPERTIES by variables from CI_OPT_CI_OPTS_SCRIPT and CI_OPT_*
function ci_opt_gradle_properties() {
    if [ -n "${CI_OPT_GRADLE_PROPERTIES}" ]; then
        echo "${CI_OPT_GRADLE_PROPERTIES}"
    else
        local properties="";
        if [ -n "${CI_OPT_GRADLE_INIT_SCRIPT}" ]; then properties="${properties} --init-script ${CI_OPT_GRADLE_INIT_SCRIPT}"; fi
        properties="${properties} -Pinfrastructure=$(ci_opt_infrastructure)"
        properties="${properties} -PtestFailureIgnore=${CI_OPT_TEST_FAILURE_IGNORE}"
        properties="${properties} -Psettings=${CI_OPT_MAVEN_SETTINGS_FILE}"
        if [ -n "${CI_OPT_MAVEN_SETTINGS_SECURITY_FILE}" ]; then properties="${properties} -Psettings.security=${CI_OPT_MAVEN_SETTINGS_SECURITY_FILE}"; fi
        echo "${properties}"
    fi
}

function init_docker_config() {
    if [ ! -d "${HOME}/.docker/" ]; then echo "mkdir ${HOME}/.docker/ "; mkdir -p "${HOME}/.docker/"; fi

    if [ "${CI_OPT_DRYRUN}" != "true" ]; then
        # Download docker's config.json if current infrastructure has this file
        #download_if_exists "${CI_INFRA_OPT_MAVEN_BUILD_OPTS_REPO}/src/main/docker/config.json" "${HOME}/.docker/config.json" "-H 'PRIVATE-TOKEN: $(ci_infra_opt_git_auth_token)'"
        #download_if_exists "${CI_INFRA_OPT_MAVEN_BUILD_OPTS_REPO}/src/main/docker/daemon.json" "${HOME}/.docker/daemon.json" "-H 'PRIVATE-TOKEN: $(ci_infra_opt_git_auth_token)'"

        if [ -n "${CI_OPT_DOCKER_REGISTRY_PASS}" ] && [ -n "${CI_OPT_DOCKER_REGISTRY_USER}" ] && [ -n "${CI_INFRA_OPT_DOCKER_REGISTRY}" ]; then
            if [[ "${CI_INFRA_OPT_DOCKER_REGISTRY_URL}" == https* ]]; then
                echo "docker logging into secure registry ${CI_INFRA_OPT_DOCKER_REGISTRY} (${CI_INFRA_OPT_DOCKER_REGISTRY_URL})"
                echo logging into secure registry ${CI_INFRA_OPT_DOCKER_REGISTRY}
                echo ${CI_OPT_DOCKER_REGISTRY_PASS} | docker login --password-stdin -u="${CI_OPT_DOCKER_REGISTRY_USER}" ${CI_INFRA_OPT_DOCKER_REGISTRY}
            else
                echo "docker logging into insecure registry ${CI_INFRA_OPT_DOCKER_REGISTRY} (${CI_INFRA_OPT_DOCKER_REGISTRY_URL})"
                echo logging into insecure registry ${CI_INFRA_OPT_DOCKER_REGISTRY}
                echo ${CI_OPT_DOCKER_REGISTRY_PASS} | DOCKER_OPTS="–insecure-registry ${CI_INFRA_OPT_DOCKER_REGISTRY}" docker login --password-stdin -u="${CI_OPT_DOCKER_REGISTRY_USER}" ${CI_INFRA_OPT_DOCKER_REGISTRY}
            fi
            echo "docker login done"
        else
            echo "skip docker login"
        fi
    fi
}

function pull_base_image() {
    if type -p docker > /dev/null; then
        local dockerfiles=($(find . -name '*Docker*'))
        echo "Found ${#dockerfiles[@]} Dockerfiles, '${dockerfiles[@]}'"
        # mvn could not resolve sibling dependencies on first build of a version
        #if [ ${#dockerfiles[@]} -gt 0 ]; then
        #    echo mvn ${CI_OPT_MAVEN_SETTINGS} -e process-resources
        #    mvn ${CI_OPT_MAVEN_SETTINGS} -e process-resources
        #fi

        local base_images=($(find . -name '*Docker*' | xargs cat | { grep -E '^FROM' || true; } | awk '{print $2}' | uniq))
        echo "Found ${#base_images[@]} base images, '${base_images[@]}'"
        if [ ${#base_images[@]} -gt 0 ]; then
            for base_image in ${base_images[@]}; do docker pull ${base_image}; done
        fi
    fi
}

function alter_mvn() {
    (>&2 echo "alter_mvn is_origin_repo: $(ci_opt_is_origin_repo), ref_name: $(ci_opt_ref_name), args: $@")

    goals=()
    result=()

    for element in $@; do
        if [ "${element}" == "mvn" ]; then
            #(>&2 echo "alter_mvn command '${element}' found")
            continue
        elif [[ "${element}" == -* ]]; then
            (>&2 echo "alter_mvn property '${element}' found")
            result+=("${element}")
        else
            (>&2 echo "alter_mvn goal '${element}' found")

            if [[ "${element}" == *deploy ]]; then
            # deploy, site-deploy, push (docker)
                if [ "$(ci_opt_publish_to_repo)" == "true" ]; then
                    if [ "${CI_OPT_MVN_DEPLOY_PUBLISH_SEGREGATION}" == "true" ]; then
                    # mvn deploy and publish segregation
                        goals+=("org.codehaus.mojo:wagon-maven-plugin:merge-maven-repos@merge-maven-repos-deploy")
                        if [ "$(ci_opt_user_docker)" == "true" ]; then goals+=("dockerfile:push"); fi
                    else
                        goals+=("${element}")
                    fi
                else
                    (>&2 echo "skip ${element}")
                fi
            elif [[ "${element}" == *site* ]] && [ "$(ci_opt_site)" == true ]; then
            # if ci_opt_site=false, do not build site
                goals+=("${element}")
            elif ([[ "${element}" == *clean ]] || [[ "${element}" == *install ]]); then
            # goals need to alter
                if [ "${CI_OPT_MVN_DEPLOY_PUBLISH_SEGREGATION}" == "true" ]; then
                # mvn deploy and publish segregation
                    if [[ "${element}" == *clean ]]; then
                        goals+=("clean")
                        goals+=("org.apache.maven.plugins:maven-antrun-plugin:run@local-deploy-model-path-clean")
                    elif [[ "${element}" == *install ]]; then
                        goals+=("deploy")
                        if [ "$(ci_opt_user_docker)" == "true" ]; then goals+=("dockerfile:build"); fi
                    fi
                else
                    goals+=("${element}")
                fi
            elif [[ "${element}" == *sonar ]]; then
                if [ "$(ci_opt_ref_name)" == "develop" ] && [ "$(ci_opt_is_origin_repo)" == "true" ]; then
                    goals+=("${element}")
                else
                    (>&2 echo "skip ${element}")
                fi
            else
                # if not origin repo (forked)
                goals+=("${element}")
                #(>&2 echo "alter_mvn (forked repo) drop '${element}'")
            fi
        fi
    done

    for goal in ${goals[@]}; do result+=("${goal}"); done
    (>&2 echo "alter_mvn output: ${result[*]}")
    echo "${result[*]}"
}

function run_mvn() {
    local curl_options="-H \"PRIVATE-TOKEN: $(ci_infra_opt_git_auth_token)\""

    echo -e "\n>>>>>>>>>> ---------- run_mvn toolchains.xml ---------- >>>>>>>>>>"
    if [ -z "${CI_OPT_MAVEN_TOOLCHAINS_FILE_URL}" ]; then CI_OPT_MAVEN_TOOLCHAINS_FILE_URL="${CI_INFRA_OPT_MAVEN_BUILD_OPTS_REPO}/src/main/maven/toolchains.xml"; fi
    # always down toolchains.xml on travis-ci build
    if [ ! -f "${HOME}/.m2/toolchains.xml" ] || [ -n "${TRAVIS_EVENT_TYPE}" ]; then
        download_if_exists "${CI_OPT_MAVEN_TOOLCHAINS_FILE_URL}" "${HOME}/.m2/toolchains.xml" "${curl_options}"
    else
        echo "Found ${HOME}/.m2/toolchains.xml"
    fi
    echo -e "<<<<<<<<<< ---------- run_mvn toolchains.xml ---------- <<<<<<<<<<\n"

    echo -e "\n>>>>>>>>>> ---------- run_mvn settings.xml and settings-security.xml ---------- >>>>>>>>>>"
    # Maven settings.xml
    if [ -z "${CI_OPT_MAVEN_SETTINGS}" ]; then
        if [ -z "${CI_OPT_MAVEN_SETTINGS_FILE}" ]; then CI_OPT_MAVEN_SETTINGS_FILE="$(pwd)/src/main/maven/settings.xml"; fi
        if [ ! -f ${CI_OPT_MAVEN_SETTINGS_FILE} ]; then
            if [ -z "${CI_OPT_MAVEN_SETTINGS_FILE_URL}" ]; then CI_OPT_MAVEN_SETTINGS_FILE_URL="${CI_INFRA_OPT_MAVEN_BUILD_OPTS_REPO}/src/main/maven/settings.xml"; fi
            CI_OPT_MAVEN_SETTINGS_FILE="$(ci_opt_cache_directory)/settings-$(ci_opt_infrastructure).xml"
            if [ "$(is_remote_resource_exists "${CI_OPT_MAVEN_SETTINGS_FILE_URL}" "${curl_options}")" == "true" ]; then
                download "${CI_OPT_MAVEN_SETTINGS_FILE_URL}" "${CI_OPT_MAVEN_SETTINGS_FILE}" "${curl_options}"
                CI_OPT_MAVEN_SETTINGS="-s ${CI_OPT_MAVEN_SETTINGS_FILE}"
            else
                echo "Error, can not download ${CI_OPT_MAVEN_SETTINGS_FILE_URL}"
                return 1
            fi
        else
            echo "Found ${CI_OPT_MAVEN_SETTINGS_FILE}"
            cp -f ${CI_OPT_MAVEN_SETTINGS_FILE} $(ci_opt_cache_directory)/settings-$(ci_opt_infrastructure).xml
            CI_OPT_MAVEN_SETTINGS="-s $(ci_opt_cache_directory)/settings-$(ci_opt_infrastructure).xml"
        fi
    fi
    echo "CI_OPT_MAVEN_SETTINGS: ${CI_OPT_MAVEN_SETTINGS}"

    # Download maven's settings-security.xml if current infrastructure has this file
    download_if_exists "${CI_INFRA_OPT_MAVEN_BUILD_OPTS_REPO}/src/main/maven/settings-security.xml" "${HOME}/.m2/settings-security.xml" "${curl_options}"
    echo -e "<<<<<<<<<< ---------- run_mvn settings.xml and settings-security.xml ---------- <<<<<<<<<<\n"

    echo -e "\n>>>>>>>>>> ---------- run_mvn properties and environment variables ---------- >>>>>>>>>>"
    # Load infrastructure specific ci options (CI_OPT_CI_OPTS_SCRIPT)
    if [ ! -f "${CI_OPT_CI_OPTS_SCRIPT}" ]; then
        if [ -f ../maven-build-opts-$(ci_opt_infrastructure)/${CI_OPT_CI_OPTS_SCRIPT} ]; then
            # for maven-build* developer
            eval "$(cat ../maven-build-opts-$(ci_opt_infrastructure)/${CI_OPT_CI_OPTS_SCRIPT})"
        else
            # for maven-build* user
            CI_OPT_CI_OPTS_SCRIPT="${CI_INFRA_OPT_MAVEN_BUILD_OPTS_REPO}/${CI_OPT_CI_OPTS_SCRIPT}"
            if [ "$(is_remote_resource_exists "${CI_OPT_CI_OPTS_SCRIPT}" "${curl_options}")" == "true" ]; then
                echo "eval \$(curl -H \"Cache-Control: no-cache\" -H \"PRIVATE-TOKEN: <secret>\" -s -L ${CI_OPT_CI_OPTS_SCRIPT})"
                eval "$(curl -H "Cache-Control: no-cache" -H "PRIVATE-TOKEN: $(ci_infra_opt_git_auth_token)" -s -L ${CI_OPT_CI_OPTS_SCRIPT})"
            else
                echo "Error, can not download ${CI_OPT_CI_OPTS_SCRIPT}"
            fi
        fi
    else
        . ${CI_OPT_CI_OPTS_SCRIPT}
    fi

    if [ "opensource" == "$(ci_opt_infrastructure)" ]; then
        if [ -z "${CI_OPT_GITHUB_SITE_REPO_NAME}" ]; then CI_OPT_GITHUB_SITE_REPO_NAME="$(ci_opt_site_path_prefix)"; fi
        if [ -z "${CI_OPT_GITHUB_SITE_REPO_OWNER}" ]; then CI_OPT_GITHUB_SITE_REPO_OWNER="$(echo $(git_repo_slug) | cut -d '/' -f1-)"; fi
        # export and expose to maven sub process
        export CI_OPT_GITHUB_SITE_REPO_NAME
        export CI_OPT_GITHUB_SITE_REPO_OWNER
    fi

    if [ -z "${CI_OPT_MAVEN_EFFECTIVE_POM}" ]; then CI_OPT_MAVEN_EFFECTIVE_POM="true"; fi
    if [ -z "${CI_OPT_MAVEN_EFFECTIVE_POM_FILE}" ]; then CI_OPT_MAVEN_EFFECTIVE_POM_FILE="$(ci_opt_cache_directory)/effective-pom.xml"; fi
    echo -e "<<<<<<<<<< ---------- run_mvn properties and environment variables ---------- <<<<<<<<<<\n"

    echo -e "\n>>>>>>>>>> ---------- run_mvn alter_mvn ---------- >>>>>>>>>>"
    local altered=$(alter_mvn $@)
    echo "alter_mvn result: mvn ${altered}"
    local mvn_opts_and_goals=("${altered}")
    local mvn_goals=()
    for element in ${mvn_opts_and_goals[@]}; do if [[ "${element}" == -* ]]; then continue; else mvn_goals+=("${element}"); fi; done
    echo "alter_mvn found ${#mvn_goals[@]} goals: ${mvn_goals[@]}"
    if [ ${#mvn_goals[@]} -eq 0 ]; then
        echo "There are not goals to run, exit.";
        return 0;
    fi
    echo -e "<<<<<<<<<< ---------- run_mvn alter_mvn ---------- <<<<<<<<<<\n"

    if [ -n "${CI_INFRA_OPT_DOCKER_REGISTRY_URL}" ]; then
        CI_INFRA_OPT_DOCKER_REGISTRY=$(echo "${CI_INFRA_OPT_DOCKER_REGISTRY_URL}" | awk -F/ '{print $3}')
    fi

    echo -e "\n>>>>>>>>>> ---------- run_mvn options ---------- >>>>>>>>>>"
    export MAVEN_OPTS="$(ci_opt_maven_opts)"
    set | grep -E '^CI_INFRA_OPT_' | filter_secret_variables || echo "no any CI_INFRA_OPT_* present"
    set | grep -E '^CI_OPT_' | filter_secret_variables || echo "no any CI_OPT_* present"
    echo MAVEN_OPTS=${MAVEN_OPTS} | filter_secret_variables || echo "no MAVEN_OPTS present"
    echo -e "\n<<<<<<<<<< ---------- run_mvn options ---------- <<<<<<<<<<\n"

    if [ "$(ci_opt_user_docker)" == "true" ]; then
        docker version
        # config and login
        init_docker_config

        # clean images
        echo find old docker images to clean
        local old_images=($(docker images | { grep 'none' || true; } | awk '{print $3}'))
        echo "Found ${#old_images[@]} old images, '${old_images[@]}'"
        if [ ${#old_images[@]} -gt 0 ]; then
            for old_image in ${old_images[@]}; do docker rmi ${old_image} || echo "error on clean image ${old_image}"; done
        fi
    fi

    echo -e "\n>>>>>>>>>> ---------- run_mvn project info ---------- >>>>>>>>>>"
    echo JAVA_HOME "'${JAVA_HOME}'"
    mvn ${CI_OPT_MAVEN_SETTINGS} -version

    # Maven effective pom
    mkdir -p $(dirname ${CI_OPT_MAVEN_EFFECTIVE_POM_FILE}) && touch ${CI_OPT_MAVEN_EFFECTIVE_POM_FILE}
    if [ "${CI_OPT_MAVEN_EFFECTIVE_POM}" == "true" ] && [ "${CI_OPT_DRYRUN}" != "true" ]; then
        if [ "${CI_OPT_SHELL_EXIT_ON_ERROR}" == "true" ]; then set +e; fi
        if [ "${CI_OPT_OUTPUT_MAVEN_EFFECTIVE_POM_TO_CONSOLE}" == "true" ]; then
            if [ -n "${TRAVIS_EVENT_TYPE}" ]; then
                echo travis-ci has log limit of 10000 lines, merge every 10 lines of log into 1, avoid travis timeout and to much lines
                echo "mvn ${CI_OPT_MAVEN_SETTINGS} -U -e help:effective-pom | awk 'NR%10{printf \"%s \",\$0;next;}1'' ..."
                mvn ${CI_OPT_MAVEN_SETTINGS} -U -e help:effective-pom | awk 'NR%10{printf "%s ",$0;next;}1'
            elif [ -n "${CI_COMMIT_REF_NAME}" ]; then
                echo gitlab-ci has log limit of 4194304 bytes
                echo "mvn ${CI_OPT_MAVEN_SETTINGS} -U -e help:effective-pom > ${CI_OPT_MAVEN_EFFECTIVE_POM_FILE} ..."
                mvn ${CI_OPT_MAVEN_SETTINGS} -U -e help:effective-pom > ${CI_OPT_MAVEN_EFFECTIVE_POM_FILE}
            else
                echo "mvn ${CI_OPT_MAVEN_SETTINGS} -U -e help:effective-pom >&3 ..."
                exec 3> >(tee ${CI_OPT_MAVEN_EFFECTIVE_POM_FILE})
                mvn ${CI_OPT_MAVEN_SETTINGS} -U -e help:effective-pom >&3
            fi
        else
            echo "mvn ${CI_OPT_MAVEN_SETTINGS} -U -e help:effective-pom > ${CI_OPT_MAVEN_EFFECTIVE_POM_FILE} ..."
            mvn ${CI_OPT_MAVEN_SETTINGS} -U -e help:effective-pom > ${CI_OPT_MAVEN_EFFECTIVE_POM_FILE}
        fi
        if [ $? -ne 0 ]; then echo "error on generate effective-pom"; cat ${CI_OPT_MAVEN_EFFECTIVE_POM_FILE}; exit 1; else echo "effective-pom generated successfully"; fi
        if [ "${CI_OPT_SHELL_EXIT_ON_ERROR}" == "true" ]; then set -e -o pipefail; fi
    fi
    echo -e "<<<<<<<<<< ---------- run_mvn project info ---------- <<<<<<<<<<\n"

    echo -e "\n>>>>>>>>>> ---------- pull_base_image ---------- >>>>>>>>>>"
    if [ "$(ci_opt_user_docker)" == "true" ] && [ "${CI_OPT_DRYRUN}" != "true" ]; then
        pull_base_image
    fi
    echo -e "<<<<<<<<<< ---------- pull_base_image ---------- <<<<<<<<<<\n"

    local filter_script_file=$(filter_script "$(ci_opt_cache_directory)/filter")
    echo -e "\n>>>>>>>>>> ---------- mvn ${CI_OPT_MAVEN_SETTINGS} ${altered} | ${filter_script_file} ---------- >>>>>>>>>>"
    if [ "${CI_OPT_DRYRUN}" != "true" ]; then
        bash -c "set -e -o pipefail; mvn ${CI_OPT_MAVEN_SETTINGS} ${altered} | ${filter_script_file}"
    fi
    echo -e "<<<<<<<<<< ---------- mvn ${CI_OPT_MAVEN_SETTINGS} ${altered} | ${filter_script_file} ---------- <<<<<<<<<<\n"
}

function run_gradle() {
    if [[ "${CI_OPT_GRADLE_INIT_SCRIPT}" == http* ]]; then
        download "${CI_OPT_GRADLE_INIT_SCRIPT}" "$(ci_opt_cache_directory)/$(basename $(echo ${CI_OPT_GRADLE_INIT_SCRIPT}))" ""
        CI_OPT_GRADLE_INIT_SCRIPT="$(ci_opt_cache_directory)/$(basename $(echo ${CI_OPT_GRADLE_INIT_SCRIPT}))"
    fi

    # >>>>>>>>>> ---------- gradle properties and environment variables ---------- >>>>>>>>>>
    export GRADLE_PROPERTIES="$(ci_opt_gradle_properties)"
    # <<<<<<<<<< ---------- gradle properties and environment variables ---------- <<<<<<<<<<

    # >>>>>>>>>> ---------- gradle project info ---------- >>>>>>>>>>
    gradle --stacktrace ${GRADLE_PROPERTIES} -version
    # <<<<<<<<<< ---------- gradle project info ---------- <<<<<<<<<<
}

# check if current repository is a spring-cloud-configserver's config repository
function is_config_repository() {
    if [[ "$(basename $(pwd))" == *-config ]] && ([ -f "application.yml" ] || [ -f "application.properties" ]); then
        return
    fi
    false
}


if [ -z "${CI_OPT_SHELL_PRINT_EXECUTED_COMMANDS}" ]; then CI_OPT_SHELL_PRINT_EXECUTED_COMMANDS="false"; fi
if [ "${CI_OPT_SHELL_PRINT_EXECUTED_COMMANDS}" == "true" ]; then set -x; fi

# key line to make whole build process file when command using pipelines fails
if [ -z "${CI_OPT_SHELL_EXIT_ON_ERROR}" ]; then CI_OPT_SHELL_EXIT_ON_ERROR="true"; fi
if [ "${CI_OPT_SHELL_EXIT_ON_ERROR}" == "true" ]; then set -e -o pipefail; fi


echo -e "\n>>>>>>>>>> ---------- init options ---------- >>>>>>>>>>"
set | grep -E '^CI_INFRA_OPT_' | filter_secret_variables || echo "no any CI_INFRA_OPT_* present"
set | grep -E '^CI_OPT_' | filter_secret_variables || echo "no any CI_OPT_* present"
echo -e "\n<<<<<<<<<< ---------- init options ---------- <<<<<<<<<<\n"


echo -e "\n>>>>>>>>>> ---------- build context info ---------- >>>>>>>>>>"
echo "gitlab-ci variables: CI_REF_NAME: ${CI_REF_NAME}, CI_COMMIT_REF_NAME: ${CI_COMMIT_REF_NAME}, CI_PROJECT_URL: ${CI_PROJECT_URL}"
echo "travis-ci variables: TRAVIS_BRANCH: ${TRAVIS_BRANCH}, TRAVIS_EVENT_TYPE: ${TRAVIS_EVENT_TYPE}, TRAVIS_REPO_SLUG: ${TRAVIS_REPO_SLUG}, TRAVIS_PULL_REQUEST: ${TRAVIS_PULL_REQUEST}"

echo -e "\n    >>>>>>>>>> ---------- decrypt files and handle keys ---------- >>>>>>>>>>"
GPG_TTY=$(tty || echo "")
if [ -z "${GPG_TTY}" ]; then unset GPG_TTY; fi
echo "gpg tty '${GPG_TTY}'"
GPG_EXECUTABLE="gpg"
echo determine gpg or gpg2 to use
# invalid option --pinentry-mode loopback
if which gpg2 > /dev/null; then GPG_EXECUTABLE="gpg2"; GPG_CMD="gpg2 --use-agent"; elif which gpg > /dev/null; then GPG_EXECUTABLE="gpg"; GPG_CMD="gpg"; fi
echo "using ${GPG_EXECUTABLE}"
# use --batch=true to avoid 'gpg tty not a tty' error
${GPG_CMD} --batch=true --version
openssl version -a
if version_gt $(${GPG_EXECUTABLE} --batch=true --version | { grep -E '[0-9]+\.[0-9]+\.[0-9]+' || true; } | head -n1 | awk '{print $NF}') "2.1"; then
    echo "gpg version greater than 2.1"
    mkdir -p ~/.gnupg && chmod 700 ~/.gnupg
    touch ~/.gnupg/gpg.conf
    echo "add 'use-agent' to '~/.gnupg/gpg.conf'"
    echo 'use-agent' > ~/.gnupg/gpg.conf
    # on gpg-2.1.11 'pinentry-mode loopback' is invalid option
    #echo "add 'pinentry-mode loopback' to '~/.gnupg/gpg.conf'"
    #echo 'pinentry-mode loopback' >> ~/.gnupg/gpg.conf
    cat ~/.gnupg/gpg.conf
    #GPG_CMD="${GPG_CMD} --pinentry-mode loopback"
    #export GPG_OPTS='--pinentry-mode loopback'
    #echo GPG_OPTS: ${GPG_OPTS}
    echo "add 'allow-loopback-pinentry' to '~/.gnupg/gpg-agent.conf'"
    touch ~/.gnupg/gpg-agent.conf
    echo 'allow-loopback-pinentry' > ~/.gnupg/gpg-agent.conf
    cat ~/.gnupg/gpg-agent.conf
    echo restart the agent
    echo RELOADAGENT | gpg-connect-agent
fi
if [ -f codesigning.asc.enc ] && [ -n "${CI_OPT_GPG_PASSPHRASE}" ]; then
    echo decrypt private key
    # bad decrypt
    # 140611360391616:error:06065064:digital envelope routines:EVP_DecryptFinal_ex:bad decrypt:../crypto/evp/evp_enc.c:536:
    # see: https://stackoverflow.com/questions/34304570/how-to-resolve-the-evp-decryptfinal-ex-bad-decrypt-during-file-decryption
    openssl aes-256-cbc -k ${CI_OPT_GPG_PASSPHRASE} -in codesigning.asc.enc -out codesigning.asc -d -md md5
fi
if [ -f codesigning.asc.gpg ] && [ -n "${CI_OPT_GPG_PASSPHRASE}" ]; then
    echo decrypt private key
    LC_CTYPE="UTF-8" echo ${CI_OPT_GPG_PASSPHRASE} | ${GPG_CMD} --passphrase-fd 0 --yes --batch=true --cipher-algo AES256 -o codesigning.asc codesigning.asc.gpg
fi
if [ -f codesigning.pub ]; then
    echo import public keys
    ${GPG_CMD} --yes --batch --import codesigning.pub

    echo list public keys
    ${GPG_CMD} --batch=true --list-keys
fi
if [ -f codesigning.asc ]; then
    echo import private keys
    # some versions only can import public key from a keypair file, some can import key pair
    if [ -f codesigning.pub ]; then
        ${GPG_CMD} --yes --batch --import codesigning.asc
    else
        if [ -z "$(${GPG_CMD} --list-secret-keys | { grep ${CI_OPT_GPG_KEYNAME} || true; })" ]; then ${GPG_CMD} --yes --batch=true --fast-import codesigning.asc; fi
    fi
    echo list private keys
    ${GPG_CMD} --batch=true --list-secret-keys

    # issue: You need a passphrase to unlock the secret key
    # no-tty cause "gpg: Sorry, no terminal at all requested - can't get input"
    #echo 'no-tty' >> ~/.gnupg/gpg.conf
    #echo 'default-cache-ttl 600' > ~/.gnupg/gpg-agent.conf

    # test key
    # this test not working on appveyor
    # gpg: skipped "KEYID": secret key not available
    # gpg: signing failed: secret key not available
    #if [ -f LICENSE ]; then
    #    echo test private key imported
    #    echo ${CI_OPT_GPG_PASSPHRASE} | gpg --passphrase-fd 0 --yes --batch=true -u ${CI_OPT_GPG_KEYNAME} --armor --detach-sig LICENSE
    #fi
    echo set default key
    echo -e "trust\n5\ny\n" | gpg --command-fd 0 --batch=true --edit-key ${CI_OPT_GPG_KEYNAME}

    # for gradle build
    if [ -n "${CI_OPT_GPG_KEYID}" ]; then ${GPG_CMD} --batch=true --keyring secring.gpg --export-secret-key ${CI_OPT_GPG_KEYID} > secring.gpg; fi
fi
echo -e "    <<<<<<<<<< ---------- decrypt files and handle keys ---------- <<<<<<<<<<\n"

if [ -f "${HOME}/.bashrc" ]; then source "${HOME}/.bashrc"; fi
echo "PWD: $(pwd)"
echo "USER: $(whoami)"
echo -e "<<<<<<<<<< ---------- build context info ---------- <<<<<<<<<<\n"


echo -e "\n>>>>>>>>>> ---------- important variables ---------- >>>>>>>>>>"
if [ -z "${CI_OPT_MAVEN_BUILD_REPO}" ]; then
    if [[ "${CI_OPT_CI_SCRIPT}" == http* ]]; then
        # test with: https://github.com/ci-and-cd/maven-build/raw/v0.3.0/src/main/ci-script/lib_ci.sh
        url_prefix="$(echo ${CI_OPT_CI_SCRIPT} | sed -r 's#/raw/.+#/raw#')"
        if [ "$(git_repo_slug)" != "ci-and-cd/maven-build" ]; then
            # For other projects, should use master branch by default.
            CI_OPT_MAVEN_BUILD_REPO="${url_prefix}/master"
        else
            # Use current branch for ci-and-cd/maven-build project
            CI_OPT_MAVEN_BUILD_REPO="${url_prefix}/$(ci_opt_ref_name)"
        fi
    elif [ -n "${CI_OPT_CI_SCRIPT}" ]; then
        # use current directory
        CI_OPT_MAVEN_BUILD_REPO=""
    else
        echo "Both CI_OPT_MAVEN_BUILD_REPO and CI_OPT_CI_SCRIPT are not set, exit."
        return 1
    fi
fi
CI_INFRA_OPT_MAVEN_BUILD_OPTS_REPO="$(ci_infra_opt_git_prefix)/ci-and-cd/maven-build-opts-$(ci_opt_infrastructure)/raw/master"
if [ -z "${CI_OPT_CI_OPTS_SCRIPT}" ]; then CI_OPT_CI_OPTS_SCRIPT="src/main/ci-script/ci_opts.sh"; fi
if [ -z "$(ci_infra_opt_git_auth_token)" ]; then
    if [ "$(ci_opt_is_origin_repo)" == "true" ]; then
        echo "ERROR, CI_INFRA_OPT_GIT_AUTH_TOKEN not set and using origin repo, exit."; return 1;
    else
        # For PR build on travis-ci or appveyor
        echo "WARN, CI_INFRA_OPT_GIT_AUTH_TOKEN not set.";
    fi
fi
echo -e "<<<<<<<<<< ---------- important variables ---------- <<<<<<<<<<\n"


echo -e "\n>>>>>>>>>> ---------- options with important variables ---------- >>>>>>>>>>"
set | grep -E '^CI_INFRA_OPT_' | filter_secret_variables || echo "no any CI_INFRA_OPT_* present"
set | grep -E '^CI_OPT_' | filter_secret_variables || echo "no any CI_OPT_* present"
echo -e "\n<<<<<<<<<< ---------- options with important variables ---------- <<<<<<<<<<\n"


# Load remote script library here

if [ -f pom.xml ]; then
    run_mvn $@
fi

if [ -f build.gradle ]; then
    run_gradle
fi
