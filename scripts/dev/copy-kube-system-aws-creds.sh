#! /bin/bash

export NAMESPACE="${2:-"$METERING_NAMESPACE"}"

# Adapted from: https://stackoverflow.com/questions/46297949/kubernetes-sharing-secret-across-namespaces
# Note: secrets can only be referenced from pods in the same namespaces as them
kubectl get secret aws-creds -n kube-system -o yaml \
    | sed s/"namespace: kube-system"/"namespace: $NAMESPACE"/ \
    | sed '/access/ s/_/-/g' \
    | kubectl -n $NAMESPACE apply -f -
