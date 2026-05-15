#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${COPYA_APP_DIR:-"$ROOT_DIR/.build/app/COPYA.app"}"
DMG_PATH="${COPYA_DMG_PATH:-"$ROOT_DIR/.build/COPYA.dmg"}"

"$ROOT_DIR/scripts/build-app.sh"

if [[ ! -d "$APP_DIR" ]]; then
  echo "app bundle does not exist: $APP_DIR" >&2
  exit 66
fi

tmp_parent="${TMPDIR:-/tmp}"
tmp_parent="${tmp_parent%/}"
work_dir="$(mktemp -d "$tmp_parent/copya-package-dmg.XXXXXX")"
mount_dir="$work_dir/mount"
rw_dmg="$work_dir/COPYA-rw.dmg"

cleanup() {
  hdiutil detach "$mount_dir" -quiet >/dev/null 2>&1 || true
  rm -rf "$work_dir"
}
trap cleanup EXIT

mkdir -p "$mount_dir"
rm -f "$DMG_PATH"

app_kb="$(du -sk "$APP_DIR" | awk '{print $1}')"
size_mb="$(( (app_kb + 1023) / 1024 + 128 ))"
if (( size_mb < 256 )); then
  size_mb=256
fi

hdiutil create \
  -size "${size_mb}m" \
  -fs HFS+ \
  -volname "COPYA" \
  -ov \
  "$rw_dmg" >/dev/null

hdiutil attach "$rw_dmg" \
  -mountpoint "$mount_dir" \
  -nobrowse \
  -quiet

ditto "$APP_DIR" "$mount_dir/COPYA.app"
hdiutil detach "$mount_dir" -quiet

hdiutil convert "$rw_dmg" \
  -format UDZO \
  -o "$DMG_PATH" >/dev/null

echo "$DMG_PATH"
