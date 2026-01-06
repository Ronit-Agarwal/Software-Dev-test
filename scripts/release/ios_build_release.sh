#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Error: flutter not found on PATH. Install Flutter and retry."
  exit 1
fi

if [[ ! -f ios/ExportOptions.plist ]]; then
  echo "Missing ios/ExportOptions.plist"
  echo "Create one (see docs/DEPLOYMENT_GUIDE.md) or use Xcode Organizer for archive/export."
  exit 1
fi

echo "Building iOS release IPA..."
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist

echo "Outputs:"
echo " - build/ios/ipa/*.ipa"
