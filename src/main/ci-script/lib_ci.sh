# no shebang line here


# download a file by curl
# arguments: curl_source, curl_target, curl_option
function download() {
    local curl_source="$1"
    local curl_target="$2"
    local curl_default_options="-H \"Cache-Control: no-cache\" -L -S -s -t utf-8"
    local curl_option="$3 ${curl_default_options}"
    local curl_secret="$(echo $3 | sed -E "s#: [^ ]+#: <secret>'#g") ${curl_default_options}"
    if [ -f ${curl_target} ] && [ -z "$(diff ${curl_target} <sh -c "curl ${curl_option} ${curl_source} 2>/dev/null")" ]; then
        (>&2 echo "contents identical, skip download")
    else
        echo "curl ${curl_secret} -o ${curl_target} ${curl_source} 2>/dev/null"
        sh -c "curl ${curl_option} -o ${curl_target} ${curl_source} 2>/dev/null"
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
      printf "%s" "$line" | sed -E 's#TOKEN=.+#TOKEN=<secret>#g' | sed -E 's#PASS=.+#PASS=<secret>#g' | sed -E 's#PASSWORD=.+#PASSWORD=<secret>#g'
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
    # echo "Fetch URL: Fetch URL: git@github.com:ci-and-cd/maven-build.git" | ruby -ne 'puts /^\s*Fetch.*(:|\/){1}([^\/]+\/[^\/]+).git/.match($_)[2] rescue nil'
    # echo "Fetch URL: https://github.com/owner/repo.git" | ruby -ne 'puts /^\s*Fetch.*(:|\/){1}([^\/]+\/[^\/]+).git/.match($_)[2] rescue nil'
    echo $(git remote show origin -n | ruby -ne 'puts /^\s*Fetch.*(:|\/){1}([^\/]+\/[^\/]+).git/.match($_)[2] rescue nil')
}


# >>>>>>>>>> ---------- CI option functions ---------- >>>>>>>>>>

# returns: true or false
function ci_opt_user_docker() {
    if [ -n "${CI_OPT_USE_DOCKER}" ]; then
        echo "${CI_OPT_USE_DOCKER}"
    else
    # TODO find *Dockerfile* or *docker-compose*.yml
        if [ -f Dockerfile ] || [ -f src/main/resources/docker/Dockerfile ] || [ -f src/main/docker/Dockerfile ]; then
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
        cache_directory="${HOME}/.oss/tmp/$(ci_opt_git_commit_id)"
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
        if ([ "${CI_OPT_ORIGIN_REPO_SLUG}" == "$(git_repo_slug)" ] && [ "${TRAVIS_EVENT_TYPE}" != "pull_request" ]); then
            echo "true";
        else
            echo "false";
        fi
    fi
}

# auto detect infrastructure using for this build.
# example of gitlab-ci's CI_PROJECT_URL: "https://example.com/gitlab-org/gitlab-ce"
# returns: opensource, internal or local
function ci_opt_infrastructure() {
    if [ -n "${CI_OPT_INFRASTRUCTURE}" ]; then
        echo ${CI_OPT_INFRASTRUCTURE}
    elif [ -n "${TRAVIS_REPO_SLUG}" ]; then
        echo "opensource"
    elif [ -n "${CI_PROJECT_URL}" ] && [[ "${CI_PROJECT_URL}" == ${CI_INFRA_OPT_INTERNAL_GIT_PREFIX}* ]]; then
        echo "internal"
    else
        echo "local"
    fi
}

# auto detect current build ref name by CI environment variables or local git info
# ${CI_CI_OPT_REF_NAME} show branch or tag since GitLab-CI 5.2
# CI_CI_OPT_REF_NAME for gitlab 8.x, see: https://gitlab.com/help/ci/variables/README.md
# CI_COMMIT_REF_NAME for gitlab 9.x, see: https://gitlab.com/help/ci/variables/README.md
# TRAVIS_BRANCH for travis-ci, see: https://docs.travis-ci.com/user/environment-variables/
# returns: current build ref name, i.e. develop, release ...
function ci_opt_ref_name() {
    if [ -n "${CI_OPT_REF_NAME}" ]; then
        echo "${CI_OPT_REF_NAME}"
    elif [ -n "${TRAVIS_BRANCH}" ]; then
        echo "${TRAVIS_BRANCH}"
    elif [ -n "${CI_CI_OPT_REF_NAME}" ]; then
        echo "${CI_CI_OPT_REF_NAME}"
    elif [ -n "${CI_COMMIT_REF_NAME}" ]; then
        echo "${CI_COMMIT_REF_NAME}"
    else
        echo "$(git symbolic-ref -q --short HEAD || git describe --tags --exact-match)"
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
    (>&2 echo "find CI_INFRA_OPT_GIT_PREFIX from CI_OPT_CI_SCRIPT: $CI_OPT_CI_SCRIPT, default_value: $1")
    if [[ "${CI_OPT_CI_SCRIPT}" == http* ]]; then
        $(echo ${CI_OPT_CI_SCRIPT} | $(dirname $(sed -E 's#/raw/master/.+##')))
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
        elif [ "internal" == "${infrastructure}" ]; then
            default_value="http://gitlab.internal"
            CI_INFRA_OPT_GIT_PREFIX="${CI_INFRA_OPT_INTERNAL_GIT_PREFIX}"
        elif [ "local" == "${infrastructure}" ] || [ -z "${infrastructure}" ]; then
            default_value="http://gitlab.local:10080"
            CI_INFRA_OPT_GIT_PREFIX="${CI_INFRA_OPT_LOCAL_GIT_PREFIX}"
        fi

        if [ -z "${CI_INFRA_OPT_GIT_PREFIX}" ] && [ -n "${default_value}" ]; then
            find_git_prefix_from_ci_script "${default_value}";
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
        if [ -n "${CI_INFRA_OPT_DOCKER_REGISTRY}" ]; then opts="${opts} -Ddocker.registry=${CI_INFRA_OPT_DOCKER_REGISTRY}"; fi
        opts="${opts} -Dfile.encoding=UTF-8"
        if [ -n "${CI_OPT_FRONTEND_NODEDOWNLOADROOT}" ]; then opts="${opts} -Dfrontend.nodeDownloadRoot=${CI_OPT_FRONTEND_NODEDOWNLOADROOT}"; fi
        if [ -n "${CI_OPT_FRONTEND_NPMDOWNLOADROOT}" ]; then opts="${opts} -Dfrontend.npmDownloadRoot=${CI_OPT_FRONTEND_NPMDOWNLOADROOT}"; fi
        opts="${opts} -Dinfrastructure=$(ci_opt_infrastructure)"
        if [ "${CI_OPT_INTEGRATION_TEST_SKIP}" == "true" ]; then opts="${opts} -Dmaven.integration-test.skip=true"; fi
        if [ "${CI_OPT_TEST_FAILURE_IGNORE}" == "true" ]; then opts="${opts} -Dmaven.test.failure.ignore=true"; fi
        if [ "${CI_OPT_TEST_SKIP}" == "true" ]; then opts="${opts} -Dmaven.test.skip=true"; fi
        if [ "${CI_OPT_MVN_DEPLOY_PUBLISH_SEGREGATION}" == "true" ]; then opts="${opts} -Dmvn_deploy_publish_segregation=true"; fi
        if [ -n "${CI_OPT_PMD_RULESET_LOCATION}" ]; then opts="${opts} -Dpmd.ruleset.location=${CI_OPT_PMD_RULESET_LOCATION}"; fi
        opts="${opts} -Dsite=$(ci_opt_site)"
        opts="${opts} -Dsite.path=$(ci_opt_site_path_prefix)-$(ci_opt_publish_channel)"
        if [ "${CI_OPT_SONAR}" == "true" ]; then opts="${opts} -Dsonar=true"; fi
        opts="${opts} -Duser.language=zh -Duser.region=CN -Duser.timezone=Asia/Shanghai"
        if [ -n "${CI_OPT_WAGON_SOURCE_FILEPATH}" ]; then opts="${opts} -Dwagon.source.filepath=${CI_OPT_WAGON_SOURCE_FILEPATH} -DaltDeploymentRepository=repo::default::file://${CI_OPT_WAGON_SOURCE_FILEPATH}"; fi

        if [ -n "${CI_INFRA_OPT_SONAR_HOST_URL}" ]; then opts="${opts} -D$(ci_opt_infrastructure)-sonar.host.url=${CI_INFRA_OPT_SONAR_HOST_URL}"; fi
        if [ -n "${CI_INFRA_OPT_NEXUS3}" ]; then opts="${opts} -D$(ci_opt_infrastructure)-nexus3.repository=${CI_INFRA_OPT_NEXUS3}/nexus/repository"; fi

        # MAVEN_OPTS that need to kept secret
        if [ -n "${CI_OPT_JIRA_PROJECTKEY}" ]; then opts="${opts} -Djira.projectKey=${CI_OPT_JIRA_PROJECTKEY} -Djira.user=${CI_OPT_JIRA_USER} -Djira.password=${CI_OPT_JIRA_PASSWORD}"; fi
        # public sonarqube config, see: https://sonarcloud.io
        if [ "opensource" == "$(ci_opt_infrastructure)" ]; then opts="${opts} -Dsonar.organization=${CI_OPT_SONAR_ORGANIZATION} -Dsonar.login=${CI_OPT_SONAR_LOGIN_TOKEN}"; fi
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
    # Download docker's config.json if current infrastructure has this file
    if [ "${CI_OPT_DRYRUN}" != "true" ]; then
        download_if_exists "${CI_INFRA_OPT_MAVEN_BUILD_OPTS_REPO}/src/main/docker/config.json" "${HOME}/.docker/config.json" "-H 'PRIVATE-TOKEN: $(ci_infra_opt_git_auth_token)'"
        # TODO NEXUS3_DEPLOYMENT_PASSWORD for docker login when using internal infrastructure
        if [ -n "${CI_OPT_DOCKERHUB_PASS}" ] && [ -n "${CI_OPT_DOCKERHUB_USER}" ]; then
            docker login -p="${CI_OPT_DOCKERHUB_PASS}" -u="${CI_OPT_DOCKERHUB_USER}" https://registry-1.docker.io/v1/
            docker login -p="${CI_OPT_DOCKERHUB_PASS}" -u="${CI_OPT_DOCKERHUB_USER}" https://registry-1.docker.io/v2/
        fi
    fi
}

function maven_pull_base_image() {
    # TODO multi module project
    if type -p docker > /dev/null; then
        if [ -f src/main/resources/docker/Dockerfile ]; then
            if [ ! -f src/main/docker/Dockerfile ]; then
                mvn ${CI_OPT_MAVEN_SETTINGS} process-resources
            fi
            if [ -f src/main/docker/Dockerfile ]; then
                docker pull $(cat src/main/docker/Dockerfile | grep -E '^FROM' | awk '{print $2}')
            fi
        fi
    fi
}

function alter_mvn() {
    local is_origin_repo=$(ci_opt_is_origin_repo)
    local ref_name=$(ci_opt_ref_name)
    (>&2 echo "alter_mvn is_origin_repo: ${is_origin_repo}, ref_name: ${ref_name}")

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

            if [[ "${element}" == *site* ]] && [ "$(ci_opt_site)" == true ]; then
            # if ci_opt_site=false, do not build site
                result+=("${element}")
            elif ([[ "${element}" == *clean ]] || [[ "${element}" == *install ]] || [[ "${element}" == *deploy ]]); then
            # goals need to alter
                if [ "${CI_OPT_MVN_DEPLOY_PUBLISH_SEGREGATION}" == "true" ]; then
                # mvn deploy and publish segregation
                    if [[ "${element}" == *clean ]]; then
                        result+=("clean")
                        result+=("org.apache.maven.plugins:maven-antrun-plugin:run@local-deploy-model-path-clean")
                    elif [[ "${element}" == *install ]]; then
                        result+=("deploy")
                    elif [[ "${element}" == *deploy ]]; then
                        result+=("org.codehaus.mojo:wagon-maven-plugin:merge-maven-repos@merge-maven-repos-deploy")
                        if [ "$(ci_opt_user_docker)" == "true" ]; then
                            result+=("docker:build")
                            result+=("docker:push")
                        fi
                    fi
                else
                    result+=("${element}")
                fi
            elif [ "true" == "${is_origin_repo}" ]; then
            # if is origin repo
                case "${ref_name}" in
                release*)
                    # if release (origin repo), skip sonar
                    if [[ "${element}" != *sonar ]]; then
                        result+=("${element}")
                    fi
                    ;;
                *)
                    # if not release (origin repo)
                    result+=("${element}")
                    #(>&2 echo "alter_mvn (origin repo) drop '${element}'")
                esac
            else
                # if not origin repo (forked)
                result+=("${element}")
                #(>&2 echo "alter_mvn (forked repo) drop '${element}'")
            fi
        fi
    done

    echo "${result[*]}"
}

function run_mvn() {
    local curl_options="-H \"PRIVATE-TOKEN: $(ci_infra_opt_git_auth_token)\""

    echo -e "\n>>>>>>>>>> ---------- run_mvn settings.xml and settings-security.xml ---------- >>>>>>>>>>"
    # Maven settings.xml
    if [ -z "${CI_OPT_MAVEN_SETTINGS}" ]; then
        if [ -z "${CI_OPT_MAVEN_SETTINGS_FILE}" ]; then CI_OPT_MAVEN_SETTINGS_FILE="$(pwd)/src/main/maven/settings.xml"; fi
        if [ ! -f ${CI_OPT_MAVEN_SETTINGS_FILE} ]; then
            if [ -z "${CI_OPT_MAVEN_SETTINGS_FILE_URL}" ]; then CI_OPT_MAVEN_SETTINGS_FILE_URL="${CI_INFRA_OPT_MAVEN_BUILD_OPTS_REPO}/src/main/maven/settings.xml"; fi
            CI_OPT_MAVEN_SETTINGS_FILE="$(ci_opt_cache_directory)/settings-$(ci_opt_infrastructure)-$(ci_opt_git_commit_id).xml"
            if [ "$(is_remote_resource_exists "${CI_OPT_MAVEN_SETTINGS_FILE_URL}" "${curl_options}")" == "true" ]; then
                download "${CI_OPT_MAVEN_SETTINGS_FILE_URL}" "${CI_OPT_MAVEN_SETTINGS_FILE}" "${curl_options}"
                CI_OPT_MAVEN_SETTINGS="-s ${CI_OPT_MAVEN_SETTINGS_FILE}"
            else
                echo "Error, can not download ${CI_OPT_MAVEN_SETTINGS_FILE_URL}"
            fi
        else
            echo "Found ${CI_OPT_MAVEN_SETTINGS_FILE}"
            cp -f ${CI_OPT_MAVEN_SETTINGS_FILE} $(ci_opt_cache_directory)/settings-$(ci_opt_infrastructure)-$(ci_opt_git_commit_id).xml
            CI_OPT_MAVEN_SETTINGS="-s $(ci_opt_cache_directory)/settings-$(ci_opt_infrastructure)-$(ci_opt_git_commit_id).xml"
        fi
    fi
    echo "CI_OPT_MAVEN_SETTINGS: ${CI_OPT_MAVEN_SETTINGS}"

    # Download maven's settings-security.xml if current infrastructure has this file
#    download_if_exists "${CI_INFRA_OPT_MAVEN_BUILD_OPTS_REPO}/src/main/maven/settings-security.xml" "${HOME}/.m2/settings-security.xml" "${curl_options}"
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
    fi

    if [ -z "${CI_OPT_MAVEN_EFFECTIVE_POM_FILE}" ]; then CI_OPT_MAVEN_EFFECTIVE_POM_FILE="$(ci_opt_cache_directory)/effective-pom-$(ci_opt_git_commit_id).xml"; fi
    echo -e "<<<<<<<<<< ---------- run_mvn properties and environment variables ---------- <<<<<<<<<<\n"

    echo -e "\n>>>>>>>>>> ---------- run_mvn alter_mvn ---------- >>>>>>>>>>"
    local altered=$(alter_mvn $@)
    echo "alter_mvn result: mvn ${altered}"
    echo -e "<<<<<<<<<< ---------- run_mvn alter_mvn ---------- <<<<<<<<<<\n"

    echo -e "\n>>>>>>>>>> ---------- run_mvn options ---------- >>>>>>>>>>"
    export MAVEN_OPTS="$(ci_opt_maven_opts)"
    set | grep -E '^CI_INFRA_OPT_' | filter_secret_variables
    set | grep -E '^CI_OPT_' | filter_secret_variables
    echo MAVEN_OPTS=${MAVEN_OPTS} | filter_secret_variables
    echo -e "<<<<<<<<<< ---------- run_mvn options ---------- <<<<<<<<<<\n"

    echo -e "\n>>>>>>>>>> ---------- run_mvn project info ---------- >>>>>>>>>>"
    mvn ${CI_OPT_MAVEN_SETTINGS} -version

    # Maven effective pom
    # output some log to avoid travis timeout
    echo "mvn ${CI_OPT_MAVEN_SETTINGS} help:effective-pom > ${CI_OPT_MAVEN_EFFECTIVE_POM_FILE}"
    if [ "${CI_OPT_DRYRUN}" != "true" ]; then
        set +e
        mvn ${CI_OPT_MAVEN_SETTINGS} -U help:effective-pom | grep 'Downloading:' | awk '!(NR%10)'
        mvn ${CI_OPT_MAVEN_SETTINGS} help:effective-pom > ${CI_OPT_MAVEN_EFFECTIVE_POM_FILE}
        if [ $? -ne 0 ]; then
            echo "error on generate effective-pom"
            cat ${CI_OPT_MAVEN_EFFECTIVE_POM_FILE}
            exit 1
        fi
        set -e && set -o pipefail
    fi
    echo -e "<<<<<<<<<< ---------- run_mvn project info ---------- <<<<<<<<<<\n"

    if [ "$(ci_opt_user_docker)" == "true" ] && [ "${CI_OPT_DRYRUN}" != "true" ]; then
        maven_pull_base_image
    fi

    local filter_script_file=$(filter_script "$(ci_opt_cache_directory)/filter")
    #sh -c "echo sh -c echo MAVEN_OPTS: \${MAVEN_OPTS}"
    #sh -c "echo sh -c echo MAVEN_OPTS: ${MAVEN_OPTS}"
    echo "mvn ${CI_OPT_MAVEN_SETTINGS} -U ${altered} | ${filter_script_file}"
    if [ "${CI_OPT_DRYRUN}" != "true" ]; then
        sh -c "mvn ${CI_OPT_MAVEN_SETTINGS} -U ${altered} | ${filter_script_file}"
    fi
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


# key line to make whole build process file when command using pipelines fails
set -e && set -o pipefail


echo -e "\n>>>>>>>>>> ---------- build context info ---------- >>>>>>>>>>"
echo "gitlab-ci variables: CI_CI_OPT_REF_NAME: ${CI_CI_OPT_REF_NAME}, CI_COMMIT_REF_NAME: ${CI_COMMIT_REF_NAME}, CI_PROJECT_URL: ${CI_PROJECT_URL}"
echo "travis-ci variables: TRAVIS_BRANCH: ${TRAVIS_BRANCH}, TRAVIS_EVENT_TYPE: ${TRAVIS_EVENT_TYPE}, TRAVIS_REPO_SLUG: ${TRAVIS_REPO_SLUG}, TRAVIS_PULL_REQUEST: ${TRAVIS_PULL_REQUEST}"

# >>>>>>>>>> ---------- decrypt files and handle keys ---------- >>>>>>>>>>
if [ -f codesigning.asc ]; then
    gpg --fast-import codesigning.asc
    # for gradle build
    if [ -n "${CI_OPT_GPG_KEYID}" ]; then gpg --keyring secring.gpg --export-secret-key ${CI_OPT_GPG_KEYID} > secring.gpg; fi
fi
# <<<<<<<<<< ---------- decrypt files and handle keys ---------- <<<<<<<<<<

if [ -f "${HOME}/.bashrc" ]; then source "${HOME}/.bashrc"; fi
echo "PWD: $(pwd)"
echo "USER: $(whoami)"
echo -e "<<<<<<<<<< ---------- build context info ---------- <<<<<<<<<<\n"


echo -e "\n>>>>>>>>>> ---------- important variables ---------- >>>>>>>>>>"
if [ -z "${CI_OPT_MAVEN_BUILD_REPO}" ]; then
    if [[ "${CI_OPT_CI_SCRIPT}" == http* ]]; then
        CI_OPT_MAVEN_BUILD_REPO=$(echo ${CI_OPT_CI_SCRIPT} | sed -E 's#/raw/master/.+#/raw/master#')
    elif [ -n "${CI_OPT_CI_SCRIPT}" ]; then
        # use current directory
        CI_OPT_MAVEN_BUILD_REPO=""
    else
        echo "Both CI_OPT_MAVEN_BUILD_REPO and CI_OPT_CI_SCRIPT are not set, exit."
        exit 1
    fi
fi
CI_INFRA_OPT_MAVEN_BUILD_OPTS_REPO="$(ci_infra_opt_git_prefix)/ci-and-cd/maven-build-opts-$(ci_opt_infrastructure)/raw/master"
if [ -z "${CI_OPT_CI_OPTS_SCRIPT}" ]; then CI_OPT_CI_OPTS_SCRIPT="src/main/ci-script/ci_opts.sh"; fi
if [ -z "$(ci_infra_opt_git_auth_token)" ]; then echo "CI_INFRA_OPT_GIT_AUTH_TOKEN not set, exit."; exit 1; fi
echo -e "<<<<<<<<<< ---------- important variables ---------- <<<<<<<<<<\n"


echo -e "\n>>>>>>>>>> ---------- init options ---------- >>>>>>>>>>"
set | grep -E '^CI_INFRA_OPT_' | filter_secret_variables
set | grep -E '^CI_OPT_' | filter_secret_variables
echo -e "<<<<<<<<<< ---------- init options ---------- <<<<<<<<<<\n"


# Load remote script library here


if [ "$(ci_opt_user_docker)" == "true" ]; then
    init_docker_config
fi

if [ -f pom.xml ]; then
    run_mvn $@
fi

if [ -f build.gradle ]; then
    run_gradle
fi
