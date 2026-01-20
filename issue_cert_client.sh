#!/usr/bin/env bash
set -euo pipefail

CSR_ONLY=0
if [[ "${1:-}" == "--csr-only" ]]; then
  CSR_ONLY=1
  shift
fi

if [[ $CSR_ONLY -eq 1 ]]; then
  if [[ $# -lt 1 ]]; then
    echo "Usage: $0 [--csr-only] <hostname> [duration]" >&2
    echo "Duration examples: 90d, 3m, 1y (default unit: days)" >&2
    exit 1
  fi
else
  if [[ $# -ne 2 ]]; then
    echo "Usage: $0 [--csr-only] <hostname> <duration>" >&2
    echo "Duration examples: 90d, 3m, 1y (default unit: days)" >&2
    exit 1
  fi
fi

# Key generation parameters.
# KEY_ALGO="rsa"; KEY_BITS=2048      # Compatibility: high. Security: 6/10. Default.
KEY_ALGO="rsa"
KEY_BITS=2048
# KEY_ALGO="rsa"; KEY_BITS=4096      # Compatibility: high. Security: 8/10. Slower, larger keys.
# KEY_ALGO="ec"; KEY_EC_CURVE="prime256v1"  # Compatibility: high. Security: 7/10 (P-256).
# KEY_ALGO="ec"; KEY_EC_CURVE="secp384r1"   # Compatibility: good. Security: 8/10. Stronger, slower.
# KEY_ALGO="ec"; KEY_EC_CURVE="secp521r1"   # Compatibility: medium. Security: 9/10. Less common.
# KEY_ALGO="ed25519"                 # Compatibility: medium-low. Security: 9/10. Modern, fast.

HOSTNAME="$1"
DURATION="${2:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR
source "$ROOT_DIR/cfg.sh"

if [[ $CSR_ONLY -eq 0 ]]; then
  CA_DIR="$ROOT_DIR/ca"
  if [[ ! -f "$CA_DIR/private/ca.key.pem" || ! -f "$CA_DIR/certs/ca.cert.pem" ]]; then
    echo "CA not initialized. Run ./init_ca.sh first." >&2
    exit 1
  fi

  if [[ "$DURATION" =~ ^[0-9]+$ ]]; then
    DAYS="$DURATION"
  elif [[ "$DURATION" =~ ^([0-9]+)([dmy])$ ]]; then
    VALUE="${BASH_REMATCH[1]}"
    UNIT="${BASH_REMATCH[2]}"
    case "$UNIT" in
      d) DAYS="$VALUE" ;;
      m) DAYS="$((VALUE * 30))" ;;
      y) DAYS="$((VALUE * 365))" ;;
      *)
        echo "Unsupported duration unit: $UNIT" >&2
        exit 1
        ;;
    esac
  else
    echo "Invalid duration. Use number of days or suffix with d/m/y." >&2
    exit 1
  fi
fi

SAFE_HOSTNAME="${HOSTNAME//\*/[star]}"
OUT_DIR="$ROOT_DIR/issued/$SAFE_HOSTNAME"
mkdir -p "$OUT_DIR"

if [[ $CSR_ONLY -eq 0 ]]; then
  read -r -s -p "CA master password: " CA_PASS
  printf '\n'
fi

case "$KEY_ALGO" in
  rsa)
    openssl genrsa -out "$OUT_DIR/$SAFE_HOSTNAME.key.pem" "$KEY_BITS"
    ;;
  ec)
    : "${KEY_EC_CURVE:=prime256v1}"
    openssl ecparam -name "$KEY_EC_CURVE" -genkey -noout -out "$OUT_DIR/$SAFE_HOSTNAME.key.pem"
    ;;
  *)
    echo "Unsupported KEY_ALGO: $KEY_ALGO" >&2
    exit 1
    ;;
esac
chmod 600 "$OUT_DIR/$SAFE_HOSTNAME.key.pem"

CSR_CONF="$(mktemp)"
trap 'rm -f "$CSR_CONF"' EXIT
cat > "$CSR_CONF" <<EOF_CONF
[ req ]
prompt = no
distinguished_name = dn
req_extensions = req_ext

[ dn ]
CN = $HOSTNAME
O = $ORG_NAME
OU = $ORG_UNIT
L = $ORG_LOCALITY
ST = $ORG_STATE
C = $ORG_COUNTRY

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = $HOSTNAME
EOF_CONF

openssl req -new -key "$OUT_DIR/$SAFE_HOSTNAME.key.pem" \
  -out "$OUT_DIR/$SAFE_HOSTNAME.csr.pem" \
  -config "$CSR_CONF"

chmod 644 "$OUT_DIR/$SAFE_HOSTNAME.csr.pem"

if [[ $CSR_ONLY -eq 1 ]]; then
  echo "Key and CSR created:"
  echo "  $OUT_DIR/$SAFE_HOSTNAME.key.pem"
  echo "  $OUT_DIR/$SAFE_HOSTNAME.csr.pem"
  exit 0
fi

openssl ca -config "$ROOT_DIR/openssl.cnf" \
  -batch -passin pass:"$CA_PASS" \
  -extensions server_cert -days "$DAYS" -notext -md sha256 \
  -in "$OUT_DIR/$SAFE_HOSTNAME.csr.pem" \
  -out "$OUT_DIR/$SAFE_HOSTNAME.cert.pem"

cat "$OUT_DIR/$SAFE_HOSTNAME.cert.pem" "$CA_DIR/certs/ca.cert.pem" > "$OUT_DIR/$SAFE_HOSTNAME.fullchain.pem"

chmod 644 "$OUT_DIR/$SAFE_HOSTNAME.cert.pem" "$OUT_DIR/$SAFE_HOSTNAME.fullchain.pem"

echo "Certificate created: $OUT_DIR/$SAFE_HOSTNAME.cert.pem"
