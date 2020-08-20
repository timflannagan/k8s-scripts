#! /bin/bash

set -eu

export NAMESPACE="${1:-"$METERING_NAMESPACE"}"

if ! kubectl get ns ${NAMESPACE} /dev/null 2>&1; then
    echo "Creating the ${NAMESPACE} namespace"
    kubectl create ns ${NAMESPACE}
fi

# Adapted from: https://stackoverflow.com/questions/46297949/kubernetes-sharing-secret-across-namespaces
# Note: secrets can only be referenced from pods in the same namespaces as them
kubectl -n kube-system get secret aws-creds -o yaml \
    | sed s/"namespace: kube-system"/"namespace: $NAMESPACE"/ \
    | sed '/access/ s/_/-/g' \
    | kubectl -n $NAMESPACE apply -f -
