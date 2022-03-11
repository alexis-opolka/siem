#! /bin/bash

SECRET_FILE=$(pwd)/secrets/passwords.txt
TEMP_DIR=$(pwd)/temp
CA_FILE=${TEMP_DIR}/ca.crt
if test -f "${SECRET_FILE}"
then
    . $(pwd)/secrets/passwords.txt
    echo $ELASTIC_PASSWORD
    curl --cacert $CA_FILE  --url https://localhost:9200 -K- <<< "--user elastic:$ELASTIC_PASSWORD"
    curl --cacert $CA_FILE  --url https://localhost:9200/_cluster/settings  -XPUT -H "Content-Type: application/json" -d '{ "transient": { "cluster.routing.allocation.disk.threshold_enabled": false } }' -K- <<< "--user elastic:$ELASTIC_PASSWORD"

else
    curl --insecure --url https://localhost:9200 -K- <<< "--user elastic:changeme"
fi
CA_FILE=${TEMP_DIR}/ca.crt
