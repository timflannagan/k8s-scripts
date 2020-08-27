#! /bin/bash

# TODO:
# - This script isn't very robust.
# - Should probably handle inputs better
# - Need a way to injecting the `inputs` for queries that need to reference non-defaults

set -ue

REPORTQUERY_NAME=${1:?}
REPORTQUERY_NAMESPACE=${2:-$REPORTQUERY_NAMESPACE}

start=$(oc -n $REPORTQUERY_NAMESPACE get reportdatasources --no-headers=true | grep -Ev '*-raw|^report' | awk 'NR==1 { print $2 }')
end=$(oc -n $REPORTQUERY_NAMESPACE get reportdatasources --no-headers=true | grep -Ev '*-raw|^report' | awk 'NR==1 { print $3 }')
token=$(oc -n $REPORTQUERY_NAMESPACE sa get-token reporting-operator)
hostname=$(oc -n $REPORTQUERY_NAMESPACE get routes metering -o jsonpath={.spec.host})

# Note: had some difficulties with evaluating environment variables in the data
# inputs array. To avoid using my brain for something more elegant, just inject
# the values of the start and end timestamps into the $DATA variable and reference
# that in the `--data` argument in curl.
printf -v DATA '{"inputs": [], "start": "%s", "end": "%s"}' $start $end

curl -w '\n' \
    -k \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $token" \
    --data "$DATA" \
    https://${hostname}/api/v2/reportqueries/$REPORTQUERY_NAMESPACE/$REPORTQUERY_NAME/render
