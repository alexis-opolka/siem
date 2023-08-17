IP_HOST=$(ip route get 8.8.8.8 | sed -n '/src/{s/.*src *\([^ ]*\).*/\1/p;q}')
sed -i "s/192\.168\.1\.1/${IP_HOST}/g" scripts/lance-ES.sh
