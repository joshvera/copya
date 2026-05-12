#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${COPYA_APP_DIR:-"$ROOT_DIR/.build/app/COPYA.app"}"
DMG_PATH="${COPYA_DMG_PATH:-"$ROOT_DIR/.build/COPYA.dmg"}"

"$ROOT_DIR/scripts/build-app.sh"

rm -f "$DMG_PATH"
hdiutil create \
  -volname "COPYA" \
  -srcfolder "$APP_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "$DMG_PATH"
