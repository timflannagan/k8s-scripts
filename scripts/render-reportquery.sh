#! /bin/bash

set -ue

REPORTQUERY_NAME=${1:?}
# START=${2:?}
# END=${3:?}

token=$(oc -n $METERING_NAMESPACE sa get-token reporting-operator)
hostname=$(oc -n $METERING_NAMESPACE get routes metering -o jsonpath={.spec.host})

curl -w '\n' -k -XPOST -H "Content-Type: application/json" -H "Authorization: Bearer $token" \
    "https://$hostname/api/v2/reportqueries/$METERING_NAMESPACE/$REPORTQUERY_NAME/render" \
    --data '{"inputs": [], "start": "2020-08-25T18:53:00Z", "end": "2020-08-25T20:10:00Z"}'
