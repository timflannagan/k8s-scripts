#! /bin/bash

if ! kubectl get clusterautoscalers default > /dev/null 2>&1; then
    kubectl create -f manifests/machines/clusterautoscaler.yaml
fi

MACHINESETS=( $(oc -n openshift-machine-api get machinesets --no-headers | awk '{ print $1 }') )
for machine in "${MACHINESETS[@]}"; do
    export MACHINE_NAME=$(oc -n openshift-machine-api get machineset $machine -o jsonpath='{.metadata.name}')
    envsubst < manifests/machines/machineautoscaler.yaml | oc apply -f -
done
