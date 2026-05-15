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
canonical_mount_dir="$mount_dir"
rw_dmg="$work_dir/COPYA-rw.dmg"
attached_device=""

current_mount_device() {
  mount | awk -v raw_mount_dir="$mount_dir" -v canonical_mount_dir="$canonical_mount_dir" \
    '$2 == "on" && ($3 == raw_mount_dir || $3 == canonical_mount_dir) { print $1; exit }'
}

is_mount_attached() {
  [[ -n "$(current_mount_device)" ]]
}

known_device_attached() {
  if [[ -z "${attached_device:-}" ]]; then
    return 1
  fi

  hdiutil info 2>/dev/null | awk -v device="$attached_device" \
    '$1 == device { found = 1 } END { exit found ? 0 : 1 }'
}

image_detached() {
  ! is_mount_attached && ! known_device_attached
}

detach_image() {
  local device
  device="$(current_mount_device)"
  if [[ -z "$device" && -z "${attached_device:-}" ]]; then
    return 0
  fi

  local target
  for target in "${attached_device:-}" "$device" "$canonical_mount_dir" "$mount_dir"; do
    if [[ -z "$target" ]]; then
      continue
    fi

    for _ in 1 2 3; do
      hdiutil detach "$target" -quiet >/dev/null 2>&1 || true
      if image_detached; then
        attached_device=""
        return 0
      fi
      sleep 1
    done

    hdiutil detach "$target" -force -quiet >/dev/null 2>&1 || true
    if image_detached; then
      attached_device=""
      return 0
    fi
  done

  if image_detached; then
    attached_device=""
    return 0
  fi

  return 1
}

cleanup() {
  if ! detach_image; then
    echo "warning: unable to detach $mount_dir; leaving $work_dir for manual cleanup" >&2
    return 0
  fi
  rm -rf "$work_dir"
}
trap cleanup EXIT

mkdir -p "$mount_dir"
canonical_mount_dir="$(cd "$(dirname "$mount_dir")" && pwd -P)/$(basename "$mount_dir")"
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

attach_output="$(hdiutil attach "$rw_dmg" \
  -mountpoint "$mount_dir" \
  -nobrowse)"

attached_device="$(current_mount_device)"
if [[ -z "$attached_device" ]]; then
  attached_device="$(printf '%s\n' "$attach_output" | awk -v raw_mount_dir="$mount_dir" -v canonical_mount_dir="$canonical_mount_dir" \
    'index($0, raw_mount_dir) || index($0, canonical_mount_dir) { print $1; exit }')"
fi
if [[ -z "$attached_device" ]]; then
  echo "unable to identify attached device for $mount_dir" >&2
  exit 1
fi

ditto "$APP_DIR" "$mount_dir/COPYA.app"
if ! detach_image; then
  echo "unable to detach $attached_device at $mount_dir" >&2
  exit 1
fi

hdiutil convert "$rw_dmg" \
  -format UDZO \
  -o "$DMG_PATH" >/dev/null

echo "$DMG_PATH"
