#!/bin/bash
# remise à blanc de l'ip d'écoute de Kibana
IPADDR=$(ip route get 8.8.8.8 | sed -n '/src/{s/.*src *\([^ ]*\).*/\1/p;q}')
sed -i "s/$IPADDR/192\.168\.1\.1/g" $PWD/scripts/lance-ES.sh
