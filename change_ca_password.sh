#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CA_DIR="$ROOT_DIR/ca"
KEY_PATH="$CA_DIR/private/ca.key.pem"

if [[ ! -f "$KEY_PATH" ]]; then
  echo "CA key not found at $KEY_PATH. Initialize the CA first." >&2
  exit 1
fi

read -r -s -p "Current master password: " OLD_PASS
printf '\n'
read -r -s -p "New master password: " NEW_PASS
printf '\n'
read -r -s -p "Confirm new master password: " NEW_PASS_CONFIRM
printf '\n'

if [[ "$NEW_PASS" != "$NEW_PASS_CONFIRM" ]]; then
  echo "Passwords do not match." >&2
  exit 1
fi

TMP_KEY="${KEY_PATH}.tmp"

openssl rsa -aes256 \
  -in "$KEY_PATH" \
  -passin pass:"$OLD_PASS" \
  -out "$TMP_KEY" \
  -passout pass:"$NEW_PASS"

chmod 600 "$TMP_KEY"

mv "$TMP_KEY" "$KEY_PATH"

echo "CA master password updated."
