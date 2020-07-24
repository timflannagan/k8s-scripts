#! /bin/bash

set -ex

: "${KUBECONFIG:?}"

# TODO: create a CLI for this instead
NAMESPACE=${1:?}
POD_NAME=${2:?}
HOST_BINARY_PATH=${3:?}
CONTAINER_BINARY_PATH=${4:-/tmp/}

if ! type "oc" > /dev/null 2>&1; then
    echo "Failed to find the openshift client binary. Exiting."
    exit 1
fi

echo "Attempting to copy the ${HOST_BINARY_PATH} to the ${POD_NAME} pod"
oc --namespace ${NAMESPACE} cp ${HOST_BINARY_PATH} ${POD_NAME}:${CONTAINER_BINARY_PATH}
