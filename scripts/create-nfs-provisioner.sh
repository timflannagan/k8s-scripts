#! /bin/bash

set -eou pipefail

NAMESPACE="${1:-$METERING_NAMESPACE}"

if ! kubectl get storageclass sc-tflannag-nfs > /dev/null 2>&1; then
    echo "Creating the 'sc-tflannag-nfs' StorageClass"
    kubectl create -f manifests/nfs/storageclass.yaml
fi

if ! kubectl get ns ${NAMESPACE} >/dev/null 2>&1; then
    echo "Creating the ${NAMEPSACE} namespace"
    kubectl create ns ${NAMESPACE}
fi

if ! kubectl --namespace ${NAMESPACE} get service tflannag-nfs-service > /dev/null 2>&1; then
    kubectl --namespace ${NAMESPACE} create -f manifests/nfs/service.yaml
fi

export CLUSTER_IP=$(kubectl --namespace ${NAMESPACE} get services/tflannag-nfs-service -o jsonpath='{.spec.clusterIP}')
while [[ $? != 0 ]]; do
    echo "Waiting for the 'tflannag-nfs-service' Service to have a populated spec.ClusterIP"
    export CLUSTER_IP=$(kubectl --namespace ${NAMESPACE} get services/tflannag-nfs-service --jsonpath='{.spec.clusterIP}')
done

if ! kubectl --namespace ${NAMESPACE} get pod tflannag-nfs-provisioner > /dev/null 2>&1; then
    echo "Creating the NFS provisioner Pod"
    kubectl --namespace ${NAMESPACE} create -f manifests/nfs/pod.yaml
fi

kubectl wait --for=condition=Ready pod/tflannag-nfs-provisioner --timeout=120s

if kubectl --namespace ${NAMESPACE} get pv pv-tflannag-nfs > /dev/null 2>&1; then
    # TODO: support deleting this resource
    echo "Need to manually clean up any existing NFS PV/PVCs"
    exit 1
else
    echo "Creating the NFS PersistentVolume with the ${CLUSTER_IP} address"
    envsubst < manifests/nfs/pv.yaml | kubectl --namespace ${NAMESPACE} create -f -
fi

