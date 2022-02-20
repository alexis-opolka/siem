#! /bin/bash
. passwords.txt
curl --cacert ca.crt --url https://localhost:9200 -K- <<< "--user elastic:$ELASTIC_PASSWORD"
