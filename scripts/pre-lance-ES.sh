#!/bin/bash
# la génération  des certificats sera faite avec l'IP de la machine  pour avoir un access TLS sur kibana nécessaire pour fleet 
EXPORT IP_HOST=$(ip route get 8.8.8.8 | sed -n '/src/{s/.*src *\([^ ]*\).*/\1/p;q}')
#sed -i "s/192\.168\.1\.1/$IPADDR/g" $PWD/scripts/lance-ES.sh
