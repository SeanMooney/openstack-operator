#!/bin/bash
set -ex

DOCKERFILE=${DOCKERFILE:-"custom-bundle.Dockerfile"}
IMAGENAMESPACE=${IMAGENAMESPACE:-"openstack-k8s-operators"}
IMAGEREGISTRY=${IMAGEREGISTRY:-"quay.io"}
IMAGEBASE=${IMAGEBASE:-}
LOCAL_REGISTRY=${LOCAL_REGISTRY:-0}

cp "$DOCKERFILE" "${DOCKERFILE}.pinned"

#loop over each openstack-k8s-operators go.mod entry
for MOD_PATH in $(go list -m -json all | jq -r '. | select(.Path | contains("openstack")) | .Replace // . |.Path' | grep -v openstack-operator | grep -v lib-common); do
    if [[ "$MOD_PATH" == "./apis" ]]; then
        continue
    fi
    MOD_VERSION=$(go list -m -json all | jq -r ". | select(.Path | contains(\"openstack\")) | .Replace // . | select( .Path == \"$MOD_PATH\") | .Version")

    BASE=$(echo $MOD_PATH | sed -e 's|github.com/.*/\(.*\)-operator/.*|\1|')

    REF=$(echo $MOD_VERSION | sed -e 's|v0.0.0-[0-9]*-\(.*\)$|\1|')
    GITHUB_USER=$(echo $MOD_PATH | sed -e 's|github.com/\(.*\)/.*-operator/.*$|\1|')
    REPO_CURL_URL="https://quay.io/api/v1/repository/openstack-k8s-operators"
    REPO_URL="quay.io/openstack-k8s-operators"
    if [[ "$GITHUB_USER" != "openstack-k8s-operators" || "$BASE" == "$IMAGEBASE" ]]; then
        if [[ "$IMAGENAMESPACE" != "openstack-k8s-operators" || "${IMAGEREGISTRY}" != "quay.io" ]]; then
            REPO_URL="${IMAGEREGISTRY}/${IMAGENAMESPACE}"
            # Quay registry v2 api does not return all the tags that's why keeping v1 for quay and v2
            # for local registry
            if [[ ${LOCAL_REGISTRY} -eq 1 ]]; then
                REPO_CURL_URL="${IMAGEREGISTRY}/v2/${IMAGENAMESPACE}"
            else
                REPO_CURL_URL="https://${IMAGEREGISTRY}/api/v1/repository/${IMAGENAMESPACE}"
            fi
        else
            REPO_CURL_URL="https://quay.io/api/v1/repository/${GITHUB_USER}"
            REPO_URL="quay.io/${GITHUB_USER}"
        fi
        if [[ ${LOCAL_REGISTRY} -eq 1 ]]; then
            SHA=$(curl -s ${REPO_CURL_URL}/$BASE-operator-bundle/tags/list | jq -r .tags[] | sort -u | grep $REF)
        else
            SHA=$(curl -s ${REPO_CURL_URL}/$BASE-operator-bundle/tag/ | jq -r .tags[].name | sort -u | grep $REF)
        fi
    fi

    

    sed -i "${DOCKERFILE}.pinned" -e "s|quay.io/openstack-k8s-operators/${BASE}-operator-bundle.*|${REPO_URL}/${BASE}-operator-bundle:$SHA|"
done
