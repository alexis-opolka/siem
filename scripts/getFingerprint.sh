openssl x509 -fingerprint -sha256 -in ./temp/ca.crt |grep Fingerprint|awk -F"=" '{print $2}'| sed -e 's/://g'
