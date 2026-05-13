#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tag="${GITHUB_REF_NAME:-}"

if [[ "${GITHUB_REF_TYPE:-}" != "tag" ]]; then
  echo "release workflow must run from a protected tag" >&2
  exit 64
fi
if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "release tag must match vX.Y.Z, got: $tag" >&2
  exit 64
fi

cd "$ROOT_DIR"
git fetch --force --tags origin main:refs/remotes/origin/main
tag_commit="$(git rev-parse "$tag^{}")"
main_commit="$(git rev-parse origin/main)"

if ! git merge-base --is-ancestor "$tag_commit" "$main_commit"; then
  echo "release tag $tag is not reachable from origin/main" >&2
  exit 1
fi

tag_version="${tag#v}"
swift_version="$(sed -n 's/^[[:space:]]*static let appVersion = "\([^"]*\)".*/\1/p' Sources/COPYA/COPYA.swift | head -n 1)"
plist_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"

if [[ "$swift_version" != "$tag_version" ]]; then
  echo "tag version $tag_version does not match Config.appVersion $swift_version" >&2
  exit 1
fi
if [[ "$plist_version" != "$tag_version" ]]; then
  echo "tag version $tag_version does not match CFBundleShortVersionString $plist_version" >&2
  exit 1
fi

printf 'release tag gate passed tag=%s commit=%s\n' "$tag" "$tag_commit"
