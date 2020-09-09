#! /bin/bash

set -eou pipefail

# TODO:
# - This assumes the user is cluster-admin
# - This assumes the NFS mount location in the manifests/nfs/pod.yaml is group writable
# - Support deleting and re-creating the PV if that resource already exists

ROOT_DIR=$(dirname "${BASH_SOURCE[0]}")/..

export MANIFEST_DIR=${MANIFEST_DIR:=${ROOT_DIR}/manifests/nfs}
export NAMESPACE="${1:-$METERING_NAMESPACE}"

if ! kubectl get storageclass sc-${NAMESPACE}-nfs > /dev/null 2>&1; then
    echo "Creating the 'sc-${NAMESPACE}-nfs' StorageClass"
    envsubst < ${MANIFEST_DIR}/storageclass.yaml | kubectl --namespace ${NAMESPACE} create -f -
fi

if ! kubectl get ns ${NAMESPACE} >/dev/null 2>&1; then
    echo "Creating the ${NAMESPACE} namespace"
    kubectl create ns ${NAMESPACE}
fi

if ! kubectl --namespace ${NAMESPACE} get service svc-${NAMESPACE}-nfs > /dev/null 2>&1; then
    envsubst < ${MANIFEST_DIR}/service.yaml | kubectl --namespace ${NAMESPACE} create -f -
fi

export CLUSTER_IP=$(kubectl --namespace ${NAMESPACE} get services/svc-${NAMESPACE}-nfs -o jsonpath='{.spec.clusterIP}')
while [[ $? != 0 ]]; do
    echo "Waiting for the 'svc-${NAMESPACE}-nfs' Service to have a populated spec.ClusterIP"
    export CLUSTER_IP=$(kubectl --namespace ${NAMESPACE} get services/svc-${NAMESPACE}-nfs --jsonpath='{.spec.clusterIP}')
done

if ! kubectl --namespace ${NAMESPACE} get pod pod-${NAMESPACE}-nfs > /dev/null 2>&1; then
    echo "Creating the NFS provisioner Pod"
    envsubst < ${MANIFEST_DIR}/pod.yaml | kubectl --namespace ${NAMESPACE} create -f -
fi

kubectl --namespace ${NAMESPACE} wait --for=condition=Ready pod/pod-${NAMESPACE}-nfs --timeout=120s

if kubectl --namespace ${NAMESPACE} get pv pv-${NAMESPACE}-nfs > /dev/null 2>&1; then
    # TODO: support deleting this resource
    echo "Need to manually clean up any existing NFS PV/PVCs"
    exit 1
else
    echo "Creating the NFS PersistentVolume with the ${CLUSTER_IP} address"
    envsubst < ${MANIFEST_DIR}/pv.yaml | kubectl --namespace ${NAMESPACE} create -f -
fi
