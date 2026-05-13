#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
APP_DIR="${COPYA_APP_DIR:-"$ROOT_DIR/.build/app/COPYA.app"}"
KOPIA_MANIFEST="${COPYA_KOPIA_MANIFEST:-"$ROOT_DIR/release/kopia.env"}"
KOPIA_CACHE_DIR="${COPYA_KOPIA_CACHE_DIR:-"$ROOT_DIR/.build/kopia"}"
KOPIA_BIN_OVERRIDE="${COPYA_KOPIA_BIN:-}"
COPYA_REQUIRE_PINNED_KOPIA="${COPYA_REQUIRE_PINNED_KOPIA:-0}"
COPYA_CODESIGN_KEYCHAIN="${COPYA_CODESIGN_KEYCHAIN:-}"
KOPIA_BIN=""
KOPIA_LICENSE=""
KOPIA_SOURCE_DESCRIPTION=""

detect_signing_identity() {
  if [[ -n "$COPYA_CODESIGN_KEYCHAIN" ]]; then
    security find-identity -v -p codesigning "$COPYA_CODESIGN_KEYCHAIN" 2>/dev/null \
      | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p; s/.*"\(Apple Development:[^"]*\)".*/\1/p' \
      | head -n 1
    return
  fi

  security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p; s/.*"\(Apple Development:[^"]*\)".*/\1/p' \
    | head -n 1
}

codesign_app() {
  if [[ -n "$COPYA_CODESIGN_KEYCHAIN" ]]; then
    codesign --keychain "$COPYA_CODESIGN_KEYCHAIN" "$@"
    return
  fi

  codesign "$@"
}

require_manifest_value() {
  local name="$1"
  local value="${!name:-}"
  if [[ -z "$value" ]]; then
    echo "$KOPIA_MANIFEST is missing required value: $name" >&2
    exit 1
  fi
}

verify_checksum() {
  local path="$1"
  local sha256="$2"

  printf '%s  %s\n' "$sha256" "$path" | shasum -a 256 -c - >/dev/null
}

prepare_pinned_kopia() {
  if [[ ! -f "$KOPIA_MANIFEST" ]]; then
    echo "missing pinned Kopia manifest: $KOPIA_MANIFEST" >&2
    exit 1
  fi

  # shellcheck source=/dev/null
  source "$KOPIA_MANIFEST"
  require_manifest_value KOPIA_VERSION
  require_manifest_value KOPIA_TAG
  require_manifest_value KOPIA_ASSET_NAME
  require_manifest_value KOPIA_URL
  require_manifest_value KOPIA_SHA256

  mkdir -p "$KOPIA_CACHE_DIR"
  local archive="$KOPIA_CACHE_DIR/$KOPIA_ASSET_NAME"
  local tmp_archive="$archive.tmp"

  if [[ -f "$archive" ]] && ! verify_checksum "$archive" "$KOPIA_SHA256"; then
    echo "cached Kopia archive checksum mismatch; redownloading $KOPIA_ASSET_NAME" >&2
    rm -f "$archive"
  fi

  if [[ ! -f "$archive" ]]; then
    echo "downloading Kopia $KOPIA_VERSION from $KOPIA_URL" >&2
    rm -f "$tmp_archive"
    curl -fL --retry 3 --retry-delay 2 -o "$tmp_archive" "$KOPIA_URL"
    verify_checksum "$tmp_archive" "$KOPIA_SHA256"
    mv "$tmp_archive" "$archive"
  else
    verify_checksum "$archive" "$KOPIA_SHA256"
  fi

  local extract_dir="$KOPIA_CACHE_DIR/extracted/$KOPIA_TAG"
  rm -rf "$extract_dir"
  mkdir -p "$extract_dir"
  tar -xzf "$archive" -C "$extract_dir"

  KOPIA_BIN="$(find "$extract_dir" -type f -name kopia -print -quit)"
  if [[ -z "$KOPIA_BIN" || ! -f "$KOPIA_BIN" ]]; then
    echo "downloaded Kopia archive did not contain a kopia executable" >&2
    exit 1
  fi
  chmod 755 "$KOPIA_BIN"

  KOPIA_LICENSE="$(find "$extract_dir" -type f -iname LICENSE -print -quit)"
  KOPIA_SOURCE_DESCRIPTION="Kopia $KOPIA_VERSION pinned from $KOPIA_URL"
}

select_kopia_binary() {
  if [[ -n "$KOPIA_BIN_OVERRIDE" ]]; then
    if [[ "$COPYA_REQUIRE_PINNED_KOPIA" == "1" ]]; then
      echo "release builds must use pinned Kopia from $KOPIA_MANIFEST; unset COPYA_KOPIA_BIN" >&2
      exit 1
    fi
    if [[ ! -x "$KOPIA_BIN_OVERRIDE" ]]; then
      echo "COPYA_KOPIA_BIN is not executable: $KOPIA_BIN_OVERRIDE" >&2
      exit 1
    fi
    KOPIA_BIN="$KOPIA_BIN_OVERRIDE"
    KOPIA_SOURCE_DESCRIPTION="developer override from COPYA_KOPIA_BIN=$KOPIA_BIN_OVERRIDE"
    return
  fi

  prepare_pinned_kopia
}

if [[ "${COPYA_CODESIGN_IDENTITY+x}" == "x" ]]; then
  SIGNING_IDENTITY="$COPYA_CODESIGN_IDENTITY"
else
  SIGNING_IDENTITY="$(detect_signing_identity || true)"
  if [[ -z "$SIGNING_IDENTITY" ]]; then
    SIGNING_IDENTITY="-"
    echo "warning: no Developer ID or Apple Development signing identity found; building ad-hoc." >&2
    echo "warning: ad-hoc builds can run manually, but SMAppService login agent launch may be rejected by macOS." >&2
  else
    echo "using signing identity: $SIGNING_IDENTITY" >&2
  fi
fi
cd "$ROOT_DIR"

select_kopia_binary

swift build -c "$CONFIGURATION" --product COPYA
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"

rm -rf "$APP_DIR"
mkdir -p \
  "$APP_DIR/Contents/MacOS" \
  "$APP_DIR/Contents/Resources/bin" \
  "$APP_DIR/Contents/Library/LaunchAgents"

cp "$BIN_DIR/COPYA" "$APP_DIR/Contents/MacOS/COPYA"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Resources/COPYA.entitlements" "$APP_DIR/Contents/Resources/COPYA.entitlements"
cp "$ROOT_DIR/Resources/com.freesidenyc.copya.agent.plist" \
  "$APP_DIR/Contents/Library/LaunchAgents/com.freesidenyc.copya.agent.plist"

cp "$KOPIA_BIN" "$APP_DIR/Contents/Resources/bin/kopia"
if [[ -n "$KOPIA_LICENSE" && -f "$KOPIA_LICENSE" ]]; then
  cp "$KOPIA_LICENSE" "$APP_DIR/Contents/Resources/Kopia-LICENSE.txt"
fi
cat > "$APP_DIR/Contents/Resources/THIRD-PARTY-NOTICES.txt" <<EOF
COPYA bundles Kopia for repository access and snapshot creation.

$KOPIA_SOURCE_DESCRIPTION

The Kopia license is included as Kopia-LICENSE.txt when supplied by the
upstream release artifact.
EOF
chmod 755 \
  "$APP_DIR/Contents/MacOS/COPYA" \
  "$APP_DIR/Contents/Resources/bin/kopia"

codesign_app --force --options runtime --sign "$SIGNING_IDENTITY" "$APP_DIR/Contents/Resources/bin/kopia"
codesign_app \
  --force \
  --options runtime \
  --entitlements "$ROOT_DIR/Resources/COPYA.entitlements" \
  --sign "$SIGNING_IDENTITY" \
  "$APP_DIR"

codesign --verify --deep --strict "$APP_DIR"
echo "$APP_DIR"
