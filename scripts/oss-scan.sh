#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

personal_pattern="$(
  printf '%s|%s|%s|%s|%s|%s|%s|%s|%s' \
    '/Users/''vera' \
    'Joshua ''Vera' \
    'HBBYK''PXNDM' \
    'com\.''vera' \
    'op://''Private' \
    'Free''side' \
    'cer''ise' \
    '#MANA''WA' \
    'Casa ''Cami'
)"
artifact_pattern='(^|/)(status\.json|active-run\.json|kopia-raw\.log)$|\.app/'

failed=0

if git grep -nE "$personal_pattern" -- . ':(exclude)scripts/oss-scan.sh'; then
  printf 'oss scan failed: personal/private strings found in tracked files\n' >&2
  failed=1
fi

if git ls-files | rg "$artifact_pattern"; then
  printf 'oss scan failed: generated artifacts are tracked\n' >&2
  failed=1
fi

exit "$failed"
