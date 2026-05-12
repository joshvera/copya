#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${COPYA_APP_DIR:-"$ROOT_DIR/.build/app/COPYA.app"}"
DMG_PATH="${COPYA_DMG_PATH:-"$ROOT_DIR/.build/COPYA.dmg"}"
PINNED_KOPIA_MANIFEST="$ROOT_DIR/release/kopia.env"
COPYA_CODESIGN_KEYCHAIN="${COPYA_CODESIGN_KEYCHAIN:-}"

detect_developer_id_identity() {
  local keychain_args=()
  if [[ -n "$COPYA_CODESIGN_KEYCHAIN" ]]; then
    keychain_args=("$COPYA_CODESIGN_KEYCHAIN")
  fi
  security find-identity -v -p codesigning "${keychain_args[@]}" 2>/dev/null \
    | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' \
    | head -n 1
}

if [[ -n "${COPYA_KOPIA_BIN:-}" ]]; then
  echo "release builds must use the pinned Kopia artifact from release/kopia.env; unset COPYA_KOPIA_BIN" >&2
  exit 1
fi
if [[ -n "${COPYA_KOPIA_MANIFEST:-}" && "$COPYA_KOPIA_MANIFEST" != "$PINNED_KOPIA_MANIFEST" ]]; then
  echo "release builds must use the pinned Kopia manifest: $PINNED_KOPIA_MANIFEST" >&2
  exit 1
fi

if [[ "${COPYA_CODESIGN_IDENTITY+x}" == "x" ]]; then
  SIGNING_IDENTITY="$COPYA_CODESIGN_IDENTITY"
else
  SIGNING_IDENTITY="$(detect_developer_id_identity || true)"
fi

if [[ -z "$SIGNING_IDENTITY" ]]; then
  echo "no Developer ID Application signing identity found; set COPYA_CODESIGN_IDENTITY" >&2
  exit 1
fi
if [[ "$SIGNING_IDENTITY" != Developer\ ID\ Application:* ]]; then
  echo "release builds require a Developer ID Application identity, got: $SIGNING_IDENTITY" >&2
  exit 1
fi

export COPYA_APP_DIR="$APP_DIR"
export COPYA_DMG_PATH="$DMG_PATH"
export COPYA_CODESIGN_IDENTITY="$SIGNING_IDENTITY"
export COPYA_REQUIRE_PINNED_KOPIA=1
export COPYA_KOPIA_MANIFEST="$PINNED_KOPIA_MANIFEST"
export COPYA_CODESIGN_KEYCHAIN

"$ROOT_DIR/scripts/package-dmg.sh"

codesign --verify --deep --strict "$APP_DIR"
codesign_keychain_args=()
if [[ -n "$COPYA_CODESIGN_KEYCHAIN" ]]; then
  codesign_keychain_args=(--keychain "$COPYA_CODESIGN_KEYCHAIN")
fi
codesign "${codesign_keychain_args[@]}" --force --sign "$SIGNING_IDENTITY" "$DMG_PATH"

if [[ -n "${COPYA_NOTARYTOOL_PROFILE:-}" ]]; then
  xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$COPYA_NOTARYTOOL_PROFILE" \
    --wait
elif [[ -n "${COPYA_NOTARYTOOL_KEY:-}" \
     && -n "${COPYA_NOTARYTOOL_KEY_ID:-}" \
     && -n "${COPYA_NOTARYTOOL_ISSUER_ID:-}" ]]; then
  xcrun notarytool submit "$DMG_PATH" \
    --key "$COPYA_NOTARYTOOL_KEY" \
    --key-id "$COPYA_NOTARYTOOL_KEY_ID" \
    --issuer "$COPYA_NOTARYTOOL_ISSUER_ID" \
    --wait
else
  echo "missing notarization credentials. Set COPYA_NOTARYTOOL_PROFILE or set COPYA_NOTARYTOOL_KEY/COPYA_NOTARYTOOL_KEY_ID/COPYA_NOTARYTOOL_ISSUER_ID." >&2
  exit 1
fi

xcrun stapler staple "$DMG_PATH"
spctl --assess --type open --context context:primary-signature -v "$DMG_PATH"

echo "$DMG_PATH"
