#! /bin/bash

set -eou pipefail

# TODO:
# - This assumes the user is cluster-admin
# - This assumes the NFS mount location in the manifests/nfs/pod.yaml is group writable
# - Support deleting and re-creating the PV if that resource already exists

export NAMESPACE="${1:-$METERING_NAMESPACE}"

if ! kubectl get storageclass sc-${NAMESPACE}-nfs > /dev/null 2>&1; then
    echo "Creating the 'sc-${NAMESPACE}-nfs' StorageClass"
    envsubst < manifests/nfs/storageclass.yaml | kubectl --namespace ${NAMESPACE} create -f -
fi

if ! kubectl get ns ${NAMESPACE} >/dev/null 2>&1; then
    echo "Creating the ${NAMEPSACE} namespace"
    kubectl create ns ${NAMESPACE}
fi

if ! kubectl --namespace ${NAMESPACE} get service ${NAMESPACE}-nfs-service > /dev/null 2>&1; then
    envsubst < manifests/nfs/service.yaml | kubectl --namespace ${NAMESPACE} create -f -
fi

export CLUSTER_IP=$(kubectl --namespace ${NAMESPACE} get services/${NAMESPACE}-nfs-service -o jsonpath='{.spec.clusterIP}')
while [[ $? != 0 ]]; do
    echo "Waiting for the '${NAMESPACE}-nfs-service' Service to have a populated spec.ClusterIP"
    export CLUSTER_IP=$(kubectl --namespace ${NAMESPACE} get services/${NAMESPACE}-nfs-service --jsonpath='{.spec.clusterIP}')
done

if ! kubectl --namespace ${NAMESPACE} get pod ${NAMESPACE}-nfs-provisioner > /dev/null 2>&1; then
    echo "Creating the NFS provisioner Pod"
    envsubst < manifests/nfs/pod.yaml | kubectl --namespace ${NAMESPACE} create -f -
fi

kubectl wait --for=condition=Ready pod/${NAMESPACE}-nfs-provisioner --timeout=120s

if kubectl --namespace ${NAMESPACE} get pv pv-${NAMESPACE}-nfs > /dev/null 2>&1; then
    # TODO: support deleting this resource
    echo "Need to manually clean up any existing NFS PV/PVCs"
    exit 1
else
    echo "Creating the NFS PersistentVolume with the ${CLUSTER_IP} address"
    envsubst < manifests/nfs/pv.yaml | kubectl --namespace ${NAMESPACE} create -f -
fi
