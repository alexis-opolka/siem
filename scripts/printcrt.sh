
CRTKEY=$(openssl x509 -fingerprint -sha256 -in ./temp/ca.crt |grep -v Fingerprint|sed -e 's/^/\t/')
cat <<- EOF
ssl:
  certificate_authorities:
     - |
      $CRTKEY
EOF
