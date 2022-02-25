#! /bin/bash
. $(pwd)/secrets/passwords.txt
TEMP_DIR=$(pwd)/temp
CA_FILE=${TEMP_DIR}/ca.crt
curl --cacert $CA_FILE  --url https://localhost:9200 -K- <<< "--user elastic:$ELASTIC_PASSWORD"
