#! /bin/bash

OLM_LATEST_RELEASE=${OLM_LATEST_RELEASE:=0.15.1}

TMP_DIR=$(mktemp -d)

kubectl apply -f https://github.com/operator-framework/operator-lifecycle-manager/releases/download/${OLM_LATEST_RELEASE}/crds.yaml
kubectl apply -f https://github.com/operator-framework/operator-lifecycle-manager/releases/download/${OLM_LATEST_RELEASE}/olm.yaml

git clone https://github.com/operator-framework/operator-marketplace "${TMP_DIR}"
kubectl apply -f "${TMP_DIR}"/deploy/upstream/

rm -rf "${TMP_DIR}"
