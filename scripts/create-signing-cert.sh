#!/bin/bash
# Creates a self-signed code-signing certificate in your login keychain, so local builds keep a
# stable signature and macOS keeps the screen-recording permission between rebuilds.
# It is only trusted for signing on this Mac; it is not a Developer ID certificate.
#
# Usage: scripts/create-signing-cert.sh ["Certificate name"]   (default: "Mara AI Local Signing")
set -euo pipefail

NAME="${1:-Mara AI Local Signing}"
if security find-identity -p codesigning | grep -q "$NAME"; then
  echo "\"$NAME\" already exists in your keychain."
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cat > "$WORK/cert.cfg" <<CFG
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CFG

/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout "$WORK/key.pem" -out "$WORK/cert.pem" -config "$WORK/cert.cfg" 2>/dev/null
PASSWORD="$(/usr/bin/openssl rand -hex 12)"
/usr/bin/openssl pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
  -out "$WORK/identity.p12" -passout "pass:$PASSWORD" -name "$NAME"
security import "$WORK/identity.p12" -k "$HOME/Library/Keychains/login.keychain-db" -P "$PASSWORD" -T /usr/bin/codesign

echo "Created \"$NAME\". The first build may ask for keychain access: choose \"Always Allow\"."
