
#CRTKEY=$(openssl x509 -fingerprint -sha256 -in ./temp/ca.crt |grep -v Fingerprint|sed -e 's/^/\t/'|sed -e 's/^M//g')
CRTKEY=$(openssl x509 -in ./temp/ca.crt)

cat <<- EOF
ssl:
  certificate_authorities:
    - |
$(echo "$CRTKEY" | sed 's/^/      /')
EOF
