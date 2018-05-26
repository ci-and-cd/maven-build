#!/usr/bin/env bash

# Usage:
# ./upload_artifact.sh
# ./upload_artifact.sh "dubbo-parent" "com.alibaba" "2.8.3" "internal"
# ./upload_artifact.sh "dubbo" "com.alibaba" "2.8.3" "local"

LOCAL_REPOSITORY="${HOME}/.m2/repository"

if [ $# -eq 4 ]; then
    ARTIFACT_ID="$1"
    GROUP_ID="$2"
    ARTIFACT_VERSION="$3"
    INFRASTRUCTURE="$4"
else
    read -p "search artifactId to upload, input: " search
    while true; do
        options=($(find ${LOCAL_REPOSITORY} -name "*${search}*" | grep -E ".+/[^/]*${search}[^/]*/[^/]+/[^/]*${search}[^/]*\.pom$" | sed "s#${LOCAL_REPOSITORY}/##"))
        if [ ${#options[*]} -eq 0 ]; then
            read -p "artifact ${search} not found, search again. input: " search
            continue
        fi
        select opt in "${options[@]}"; do
            if [ ! -z "${opt}" ]; then
                echo "selected ${opt}"
                GROUP_ID=$(echo "${opt}" | sed -E 's#(.+)/[^/]+/[^/]+/[^/]+#\1#' | sed 's#/#.#g')
                ARTIFACT_ID=$(echo "${opt}" | sed -E 's#.+/([^/]+)/[^/]+/[^/]+#\1#')
                ARTIFACT_VERSION=$(echo "${opt}" | sed -E 's#.+/[^/]+/([^/]+)/[^/]+#\1#')
                echo "selected ${GROUP_ID}:${ARTIFACT_ID}:${ARTIFACT_VERSION}"
                break
            fi
        done
        if [ ! -z "${GROUP_ID}" ] && [ ! -z "${ARTIFACT_ID}" ] && [ ! -z "${ARTIFACT_VERSION}" ]; then
            break
        fi
    done

    echo "select INFRASTRUCTURE to use."
    infrastructures=("internal" "local")
    while true; do
        select inf in "${infrastructures[@]}"; do
            echo "selected ${inf}"
            if [ ! -z "${inf}" ]; then
                INFRASTRUCTURE="${inf}"
                break
            fi
        done
        if [ ! -z "${INFRASTRUCTURE}" ]; then
            break
        fi
    done
fi


NEXUS_REPO_RELEASES="${INFRASTRUCTURE_OPT_NEXUS3}/nexus/repository/maven-releases";
NEXUS_REPO_SNAPSHOTS="${INFRASTRUCTURE_OPT_NEXUS3}/nexus/repository/maven-snapshots";
NEXUS_REPO_THIRDPARTY="${INFRASTRUCTURE_OPT_NEXUS3}/nexus/repository/maven-thirdparty";
NEXUS_REPO_ID="${INFRASTRUCTURE}-nexus3-thirdparty";


# ${GROUP_ID//.//} replace all dots with slashs
ARTIFACT_PATH="${GROUP_ID//.//}/${ARTIFACT_ID}/${ARTIFACT_VERSION}";
ARTIFACT_DIR="${LOCAL_REPOSITORY}/${ARTIFACT_PATH}";
ARTIFACT_POM="${ARTIFACT_ID}-${ARTIFACT_VERSION}.pom";
ARTIFACT_JAR="${ARTIFACT_ID}-${ARTIFACT_VERSION}.jar";

# can not upload artifact from local repository
ARTIFACT_TMP_DIR="/tmp/${ARTIFACT_ID}-${ARTIFACT_VERSION}";
rm -rf ${ARTIFACT_TMP_DIR};
mkdir -p ${ARTIFACT_TMP_DIR};

echo "ARTIFACT_POM: ${ARTIFACT_POM}";
echo "ARTIFACT_JAR: ${ARTIFACT_JAR}";

if [[ -f ${ARTIFACT_DIR}/${ARTIFACT_POM} ]] && [[ -f ${ARTIFACT_DIR}/${ARTIFACT_JAR} ]]; then
	echo "uploading pom and jar ...";
	cp -f ${ARTIFACT_DIR}/${ARTIFACT_POM} ${ARTIFACT_TMP_DIR}/${ARTIFACT_POM};
	cp -f ${ARTIFACT_DIR}/${ARTIFACT_JAR} ${ARTIFACT_TMP_DIR}/${ARTIFACT_JAR};
    mvn deploy:deploy-file \
    -DgroupId=${GROUP_ID} -DartifactId=${ARTIFACT_ID} -Dversion=${ARTIFACT_VERSION} \
    -DgeneratePom=false -Dpackaging=jar \
    -DrepositoryId=${NEXUS_REPO_ID} -Durl=${NEXUS_REPO_THIRDPARTY} \
    -DpomFile=${ARTIFACT_TMP_DIR}/${ARTIFACT_POM} -Dfile=${ARTIFACT_TMP_DIR}/${ARTIFACT_JAR};
elif [[ -f ${ARTIFACT_DIR}/${ARTIFACT_POM} ]]; then
	echo "uploading pom ...";
	cp -f ${ARTIFACT_DIR}/${ARTIFACT_POM} ${ARTIFACT_TMP_DIR}/${ARTIFACT_POM};
    mvn deploy:deploy-file \
    -DgroupId=${GROUP_ID} -DartifactId=${ARTIFACT_ID} -Dversion=${ARTIFACT_VERSION} \
    -DgeneratePom=false -Dpackaging=pom \
    -DrepositoryId=${NEXUS_REPO_ID} -Durl=${NEXUS_REPO_THIRDPARTY} \
    -Dfile=${ARTIFACT_TMP_DIR}/${ARTIFACT_POM};
else
    echo "ARTIFACT_POM and ARTIFACT_JAR not found.";
fi
