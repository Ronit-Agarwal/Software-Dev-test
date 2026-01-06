#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Error: flutter not found on PATH. Install Flutter and retry."
  exit 1
fi

if [[ ! -f android/key.properties ]]; then
  echo "Missing android/key.properties (release signing config)."
  echo "Run: scripts/release/android_generate_keystore.sh"
  exit 1
fi

echo "Building Android release artifacts..."
flutter build appbundle --release
flutter build apk --release

echo "Outputs:"
echo " - build/app/outputs/bundle/release/app-release.aab"
echo " - build/app/outputs/flutter-apk/app-release.apk"

if command -v apksigner >/dev/null 2>&1; then
  echo "Verifying APK signing..."
  apksigner verify --verbose build/app/outputs/flutter-apk/app-release.apk
else
  echo "apksigner not available; skipping signature verification."
fi
