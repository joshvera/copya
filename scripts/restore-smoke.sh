#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  printf 'usage: %s <path-relative-to-backup-source>\n' "$0" >&2
  printf 'example: %s Documents/example.txt\n' "$0" >&2
  exit 64
fi

restore_path="${1#/}"
if [[ "$restore_path" == "" || "$restore_path" == "." || "$restore_path" == "/" ]]; then
  printf 'restore path must be a specific file, not the backup root\n' >&2
  exit 64
fi
if [[ "$restore_path" == */ || "$restore_path" == *$'\n'* || "$restore_path" == *$'\r'* ]]; then
  printf 'restore path must be a specific file path without trailing slash or newlines\n' >&2
  exit 64
fi
IFS='/' read -r -a path_parts <<< "$restore_path"
for part in "${path_parts[@]}"; do
  if [[ -z "$part" || "$part" == "." || "$part" == ".." ]]; then
    printf 'restore path must not contain empty, dot, or dot-dot segments\n' >&2
    exit 64
  fi
done

copya_bin="${COPYA_BIN:-/Applications/COPYA.app/Contents/MacOS/COPYA}"
kopia_bin="${KOPIA_BIN:-/Applications/COPYA.app/Contents/Resources/bin/kopia}"
max_bytes="${COPYA_RESTORE_SMOKE_MAX_BYTES:-52428800}"
tmp_parent="${TMPDIR:-/tmp}"
tmp_parent="${tmp_parent%/}"
work_dir="$(mktemp -d "$tmp_parent/copya-restore-smoke.XXXXXX")"

cleanup() {
  [[ -n "${work_dir:-}" && "$work_dir" == "$tmp_parent"/copya-restore-smoke.* ]] || return 0
  chmod -R u+rwX "$work_dir" 2>/dev/null || true
  rm -rf "$work_dir"
}
trap cleanup EXIT

if [[ ! -x "$copya_bin" ]]; then
  printf 'COPYA executable is not available: %s\n' "$copya_bin" >&2
  exit 1
fi
if [[ ! -x "$kopia_bin" ]]; then
  printf 'bundled Kopia executable is not available: %s\n' "$kopia_bin" >&2
  exit 1
fi

status_json="$("$copya_bin" --status-json)"
snapshot_id="$(printf '%s' "$status_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("last_snapshot_id") or "")')"
snapshot_root="$(printf '%s' "$status_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("last_snapshot_root") or "")')"
backup_source="$(printf '%s' "$status_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("config_summary", {}).get("backup_source") or "")')"
kopia_home="${COPYA_KOPIA_HOME:-}"
if [[ -z "$kopia_home" ]]; then
  kopia_home="$(printf '%s' "$status_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("config_summary", {}).get("kopia_home") or "")')"
fi
kopia_config_file="${COPYA_KOPIA_CONFIG_FILE:-}"
if [[ -z "$kopia_config_file" ]]; then
  kopia_config_file="$(printf '%s' "$status_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("config_summary", {}).get("kopia_config_file") or "")')"
fi
kopia_cmd=("$kopia_bin")
if [[ -n "$kopia_config_file" ]]; then
  kopia_cmd+=(--config-file "$kopia_config_file")
fi
kopia_env=(KOPIA_CHECK_FOR_UPDATES=false)
if [[ -n "$kopia_home" ]]; then
  kopia_env+=(HOME="$kopia_home")
fi

if [[ -z "$snapshot_id" || -z "$snapshot_root" ]]; then
  printf 'COPYA status does not include a restorable last snapshot\n' >&2
  exit 1
fi
if [[ -z "$backup_source" ]]; then
  printf 'COPYA status does not include backup_source\n' >&2
  exit 1
fi
if [[ -n "$kopia_home" ]]; then
  mkdir -p "$kopia_home"
fi

live_path="$backup_source/$restore_path"
if [[ ! -f "$live_path" ]]; then
  printf 'restore path must be a specific live regular file: %s\n' "$live_path" >&2
  exit 64
fi

parent_path="$(dirname "$restore_path")"
entry_name="$(basename "$restore_path")"
if [[ "$parent_path" == "." ]]; then
  parent_object="$snapshot_root"
else
  parent_object="$snapshot_root/$parent_path"
fi

snapshot_entry="$(
  env "${kopia_env[@]}" "${kopia_cmd[@]}" list -l "$parent_object" | python3 -c '
import sys

entry_name = sys.argv[1]
for raw_line in sys.stdin:
    parts = raw_line.rstrip("\n").split(maxsplit=6)
    if len(parts) < 7:
        continue
    mode, size, name = parts[0], parts[1], parts[6]
    normalized_name = name[:-1] if name.endswith("/") else name
    if normalized_name == entry_name:
        print(f"{mode}\t{size}\t{name}")
        raise SystemExit(0)
raise SystemExit(1)
' "$entry_name"
)" || {
  printf 'restore path was not found in latest snapshot: %s\n' "$restore_path" >&2
  exit 1
}

snapshot_mode="${snapshot_entry%%$'\t'*}"
snapshot_rest="${snapshot_entry#*$'\t'}"
snapshot_size="${snapshot_rest%%$'\t'*}"
if [[ "$snapshot_mode" != -* ]]; then
  printf 'restore path must be a regular file in the snapshot, got mode %s for %s\n' "$snapshot_mode" "$restore_path" >&2
  exit 64
fi
if ! [[ "$snapshot_size" =~ ^[0-9]+$ && "$max_bytes" =~ ^[0-9]+$ ]]; then
  printf 'unable to validate restore size for %s\n' "$restore_path" >&2
  exit 1
fi
if (( snapshot_size > max_bytes )); then
  printf 'restore path is too large for smoke test: %s bytes > %s bytes\n' "$snapshot_size" "$max_bytes" >&2
  exit 64
fi

mkdir -p "$work_dir/shallow" "$work_dir/target/$(dirname "$restore_path")"

printf 'snapshot_id=%s\n' "$snapshot_id"
printf 'snapshot_root=%s\n' "$snapshot_root"
printf 'restore_path=%s\n' "$restore_path"
printf 'snapshot_size=%s\n' "$snapshot_size"

env "${kopia_env[@]}" \
  "${kopia_cmd[@]}" snapshot restore --shallow=0 --shallow-minsize=0 "$snapshot_root" "$work_dir/shallow"
env "${kopia_env[@]}" \
  "${kopia_cmd[@]}" snapshot restore "$snapshot_root/$restore_path" "$work_dir/target/$restore_path"

restored_path="$work_dir/target/$restore_path"
live_hash="$(shasum -a 256 "$live_path" | awk '{print $1}')"
restored_hash="$(shasum -a 256 "$restored_path" | awk '{print $1}')"
printf 'live_sha256=%s %s\n' "$live_hash" "$live_path"
printf 'restored_sha256=%s %s\n' "$restored_hash" "$restored_path"
if [[ "$live_hash" != "$restored_hash" ]]; then
  printf 'restored file differs from live file; choose an unchanged path or inspect manually\n' >&2
  exit 1
fi

printf 'restore smoke succeeded\n'
