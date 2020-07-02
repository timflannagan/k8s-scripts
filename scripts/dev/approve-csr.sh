#! /bin/bash

NAMESPACE=${1:?}

oc --namespace $NAMESPACE get csr -o name | xargs oc adm certificate approve
