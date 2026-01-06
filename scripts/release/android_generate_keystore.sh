#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
KEYSTORE_DIR="$PROJECT_ROOT/android/keystore"
KEYSTORE_PATH="$KEYSTORE_DIR/signsync-release.jks"
ALIAS="${SIGN_SYNC_KEY_ALIAS:-signsync}"
VALIDITY_DAYS="${SIGN_SYNC_KEY_VALIDITY_DAYS:-10000}"

mkdir -p "$KEYSTORE_DIR"

if [[ -f "$KEYSTORE_PATH" ]]; then
  echo "Keystore already exists: $KEYSTORE_PATH"
  exit 0
fi

if ! command -v keytool >/dev/null 2>&1; then
  echo "Error: keytool not found. Install a JDK and ensure keytool is on PATH."
  exit 1
fi

# Passwords can be provided via env vars to avoid interactive prompts.
STORE_PASS="${SIGN_SYNC_KEYSTORE_PASSWORD:-}"
KEY_PASS="${SIGN_SYNC_KEY_PASSWORD:-}"

if [[ -z "$STORE_PASS" || -z "$KEY_PASS" ]]; then
  echo "SIGN_SYNC_KEYSTORE_PASSWORD and SIGN_SYNC_KEY_PASSWORD are not set."
  echo "Re-run with env vars set to avoid interactive prompts."
  echo "Example: SIGN_SYNC_KEYSTORE_PASSWORD=... SIGN_SYNC_KEY_PASSWORD=... $0"
fi

echo "Generating Android release keystore..."

keytool -genkeypair \
  -v \
  -keystore "$KEYSTORE_PATH" \
  -storetype JKS \
  -alias "$ALIAS" \
  -keyalg RSA \
  -keysize 2048 \
  -validity "$VALIDITY_DAYS" \
  ${STORE_PASS:+-storepass "$STORE_PASS"} \
  ${KEY_PASS:+-keypass "$KEY_PASS"}

cat > "$PROJECT_ROOT/android/key.properties" <<EOF
storePassword=${STORE_PASS:-CHANGE_ME}
keyPassword=${KEY_PASS:-CHANGE_ME}
keyAlias=$ALIAS
storeFile=../keystore/signsync-release.jks
EOF

echo "Created: $KEYSTORE_PATH"
echo "Created: $PROJECT_ROOT/android/key.properties"
echo "NOTE: android/key.properties and *.jks are gitignored. Store them securely (password manager / vault / CI secret store)."
