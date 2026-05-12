#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${APPLE_DEVELOPER_ID_CERT_P12_BASE64:-}" ]]; then
  echo "APPLE_DEVELOPER_ID_CERT_P12_BASE64 is required" >&2
  exit 64
fi
if [[ -z "${APPLE_DEVELOPER_ID_CERT_PASSWORD:-}" ]]; then
  echo "APPLE_DEVELOPER_ID_CERT_PASSWORD is required" >&2
  exit 64
fi

tmp_dir="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
keychain_password="$(uuidgen)"
keychain_path="$tmp_dir/copya-signing.keychain-db"
cert_path="$tmp_dir/copya-developer-id.p12"

if [[ -n "${GITHUB_ENV:-}" ]]; then
  printf 'COPYA_CODESIGN_KEYCHAIN=%s\n' "$keychain_path" >> "$GITHUB_ENV"
fi

cleanup_existing() {
  security delete-keychain "$keychain_path" >/dev/null 2>&1 || true
  rm -f "$cert_path"
}

cleanup_existing
printf '%s' "$APPLE_DEVELOPER_ID_CERT_P12_BASE64" | base64 --decode > "$cert_path"

security create-keychain -p "$keychain_password" "$keychain_path"
security set-keychain-settings -lut 21600 "$keychain_path"
security unlock-keychain -p "$keychain_password" "$keychain_path"
security import "$cert_path" \
  -k "$keychain_path" \
  -P "$APPLE_DEVELOPER_ID_CERT_PASSWORD" \
  -T /usr/bin/codesign \
  -T /usr/bin/security \
  -T /usr/bin/productsign
rm -f "$cert_path"
security set-key-partition-list -S apple-tool:,apple: -s -k "$keychain_password" "$keychain_path"

identity="$(security find-identity -v -p codesigning "$keychain_path" \
  | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' \
  | head -n 1)"
if [[ -z "$identity" ]]; then
  echo "imported certificate did not expose a Developer ID Application identity" >&2
  exit 1
fi

if [[ -n "${GITHUB_ENV:-}" ]]; then
  printf 'COPYA_CODESIGN_IDENTITY=%s\n' "$identity" >> "$GITHUB_ENV"
fi

echo "$keychain_path"
