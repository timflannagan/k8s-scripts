#! /bin/bash -x

set -o errexit
set -o nounset
set -o pipefail

function cleanup() {
    rm -rf "$tmp"
}
trap cleanup EXIT

ROOT_DIR=$(dirname "${BASH_SOURCE[0]}")/..
OPM_BIN=${OPM_BIN:=/usr/local/bin/opm}

supported_versions=("4.6" "4.7" "4.8")
user=${1:-tflannag}
index_tag=${2:-supported}
tmp=$(mktemp -d)
container_tool="docker"

git clone https://github.com/kube-reporting/metering-operator/ "$tmp"

pushd "$tmp"
for version in "${supported_versions[@]}"; do
    release_version="release-${version}"
    git checkout -b ${release_version} origin/${release_version}

    ${OPM_BIN} alpha bundle generate --channels "$version" --default "${version}" --directory manifests/deploy/openshift/olm/bundle/${version}/ --output-dir bundle --package metering-ocp
    find bundle/ -type f ! -name '*.yaml' -delete

    ${container_tool} build -f bundle.Dockerfile -t quay.io/${user}/bundle:v${version} .
    ${container_tool} push quay.io/${user}/bundle:v${version}
    ${OPM_BIN} alpha bundle validate --tag quay.io/${user}/bundle:v${version} --image-builder=${container_tool}

    git clean -fd
    git checkout master
    git branch -D ${release_version}
done
popd

${OPM_BIN} index add \
    --build-tool=${container_tool} \
    --pull-tool=${container_tool} \
    --bundles quay.io/${user}/bundle:v4.6,quay.io/${user}/bundle:v4.7,quay.io/${user}/bundle:v4.8 \
    --tag "quay.io/${user}/index:${index_tag}"

${container_tool} push "quay.io/${user}/index:${index_tag}"
