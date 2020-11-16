#! /bin/bash

set -o pipefail
set -eux

function cleanup() {
    rm -rf "$tmp"
}
trap cleanup EXIT

user=${1:-tflannag}
index_tag=${2:-supported}
tmp=$(mktemp -d)

git clone https://github.com/kube-reporting/metering-operator/ "$tmp"

pushd "$tmp"
for version in "4.4" "4.5" "4.6" "4.7"; do
    git checkout -b release-${version} origin/release-${version}
    opm alpha bundle generate --channels "$version" --default "${version}" --directory manifests/deploy/openshift/olm/bundle/${version}/ --output-dir bundle --package metering-ocp
    podman build -f bundle.Dockerfile -t quay.io/${user}/bundle:v${version}
    podman push quay.io/${user}/bundle:v${version}
    git clean -fd
    git checkout master
    git branch -D release-$version
done
popd

opm index add --bundles quay.io/${user}/bundle:v4.4,quay.io/${user}/bundle:v4.5,quay.io/${user}/bundle:v4.6,quay.io/${user}/bundle:v4.7 --tag "quay.io/${user}/index:${index_tag}"
podman push "quay.io/${user}/index:${index_tag}"
