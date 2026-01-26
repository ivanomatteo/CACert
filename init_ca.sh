#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR
source "$ROOT_DIR/cfg.sh"

CA_DIR="$ROOT_DIR/ca"
if [[ -f "$CA_DIR/private/ca.key.pem" || -f "$CA_DIR/certs/ca.cert.pem" ]]; then
  echo "CA already exists at $CA_DIR. Refusing to overwrite." >&2
  exit 1
fi

mkdir -p "$CA_DIR/private" "$CA_DIR/certs" "$CA_DIR/newcerts" "$CA_DIR/crl" "$CA_DIR/csr"
chmod 700 "$CA_DIR/private"

: > "$CA_DIR/index.txt"
: > "$CA_DIR/index.txt.attr"
echo 1000 > "$CA_DIR/serial"
echo 1000 > "$CA_DIR/crlnumber"

read -r -s -p "Master password: " CA_PASS
printf '\n'
read -r -s -p "Confirm master password: " CA_PASS_CONFIRM
printf '\n'
if [[ "$CA_PASS" != "$CA_PASS_CONFIRM" ]]; then
  echo "Passwords do not match." >&2
  exit 1
fi

openssl genrsa -aes256 -passout pass:"$CA_PASS" -out "$CA_DIR/private/ca.key.pem" 4096
chmod 600 "$CA_DIR/private/ca.key.pem"

openssl req -config "$ROOT_DIR/openssl.cnf" \
  -key "$CA_DIR/private/ca.key.pem" \
  -passin pass:"$CA_PASS" \
  -new -x509 -days 3650 -sha256 -extensions v3_ca \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign,cRLSign" \
  -subj "/C=$ORG_COUNTRY/ST=$ORG_STATE/L=$ORG_LOCALITY/O=$ORG_NAME/OU=$ORG_UNIT/CN=Local Dev CA" \
  -out "$CA_DIR/certs/ca.cert.pem"
chmod 644 "$CA_DIR/certs/ca.cert.pem"

echo "CA created: $CA_DIR/certs/ca.cert.pem"
