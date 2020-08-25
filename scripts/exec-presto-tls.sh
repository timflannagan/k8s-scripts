#! /bin/bash

export NAMESPACE="${1:-"$METERING_NAMESPACE"}"

kubectl -n $NAMESPACE exec -it $(kubectl -n $NAMESPACE get pods -l app=presto,presto=coordinator -o name | cut -d/ -f2)  \
    -- /usr/local/bin/presto-cli \
    --server https://presto:8080 \
    --user hadoop \
    --catalog "hive" \
    --schema "metering" \
    --keystore-path "/opt/presto/tls/keystore.pem"
