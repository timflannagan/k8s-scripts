#! /bin/bash

set -eou pipefail
set -x

VERSION=${1:-4.6}
NEW_VERSION=${2:-4.7}

INCLUDE_DIR_LIST=(./{charts,manifests,olm_deploy,hack,Documentation,pkg})
INCLUDE_FILES_LIST=(./{CHANGELOG.md,Makefile,Dockerfile*})

# Alright, I give up trying to get this work using `find` as the base command, as
# it looks like you need to do something more along the lines of `! -name <...> -o -name <...>`
# instead of passing it a list and letting it do the heavy lifting.
EXCLUDE_FILE_EXTENSIONS=(*logo.svg)

sed -i "s/${VERSION}/${NEW_VERSION}/g" $(find "${INCLUDE_DIR_LIST[@]}" "${INCLUDE_FILES_LIST[@]}" -type f ! -name "${EXCLUDE_FILE_EXTENSIONS[@]}" -exec grep -Irwl "${VERSION}" {} \;) \
    && make metering-manifests \
    && rm -rf manifests/deploy/openshift/olm/bundle/${VERSION} \
    && rm -rf manifests/deploy/upstream/olm/bundle/${VERSION}
