#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <notarized-dmg-path>" >&2
  exit 64
fi

dmg_path="$1"
if [[ ! -f "$dmg_path" ]]; then
  echo "DMG does not exist: $dmg_path" >&2
  exit 66
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_parent="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
tmp_parent="${tmp_parent%/}"
work_dir="$(mktemp -d "$tmp_parent/copya-release-smoke.XXXXXX")"
mount_dir="$work_dir/mount"
runtime_root="$work_dir/runtime"
kopia_home="$runtime_root/home"
source_dir="$work_dir/source"
repo_dir="$work_dir/repo"
kopia_config_file="$work_dir/kopia.repository.config"
install_dir="${COPYA_SMOKE_INSTALL_DIR:-"$work_dir/Applications"}"
installed_app="$install_dir/COPYA.app"
previous_app="$work_dir/previous-COPYA.app"
installed_smoke_app=0
had_previous_app=0
password="copya-smoke-password-${RANDOM}-${RANDOM}"
export KOPIA_CHECK_FOR_UPDATES=false

cleanup() {
  hdiutil detach "$mount_dir" -quiet >/dev/null 2>&1 || true
  if [[ "$installed_smoke_app" == "1" && -d "$installed_app" && "$installed_app" == "$install_dir/COPYA.app" ]]; then
    rm -rf "$installed_app" 2>/dev/null || true
  fi
  if [[ "$had_previous_app" == "1" && -d "$previous_app" ]]; then
    if mv "$previous_app" "$installed_app" 2>/dev/null; then
      :
    fi
  fi
  chmod -R u+rwX "$work_dir" 2>/dev/null || true
  rm -rf "$work_dir"
}
trap cleanup EXIT

mkdir -p "$mount_dir" "$runtime_root" "$kopia_home" "$source_dir" "$repo_dir" "$install_dir"
printf 'COPYA release smoke fixture\n' > "$source_dir/fixture.txt"

hdiutil attach "$dmg_path" -mountpoint "$mount_dir" -nobrowse -quiet
if [[ ! -d "$mount_dir/COPYA.app" ]]; then
  echo "mounted DMG does not contain COPYA.app" >&2
  exit 1
fi

if [[ -d "$installed_app" ]]; then
  had_previous_app=1
  if mv "$installed_app" "$previous_app" 2>/dev/null; then
    :
  else
    echo "unable to move existing app at $installed_app; set COPYA_SMOKE_INSTALL_DIR to a writable isolated directory" >&2
    exit 1
  fi
fi

if cp -R "$mount_dir/COPYA.app" "$installed_app" 2>/dev/null; then
  :
else
  echo "unable to install COPYA smoke app to $install_dir; set COPYA_SMOKE_INSTALL_DIR to a writable isolated directory" >&2
  exit 1
fi
installed_smoke_app=1

copya_bin="$installed_app/Contents/MacOS/COPYA"
kopia_bin="$installed_app/Contents/Resources/bin/kopia"

codesign --verify --deep --strict "$installed_app"
xcrun stapler validate "$dmg_path"
spctl --assess --type execute -v "$installed_app"

export KOPIA_PASSWORD="$password"
HOME="$kopia_home" "$kopia_bin" \
  --config-file "$kopia_config_file" \
  --no-persist-credentials \
  --no-use-keychain \
  repository create filesystem --path "$repo_dir"

config_file="$work_dir/copya-config.json"
cat > "$config_file" <<JSON
{
  "backup_source": "$source_dir",
  "backup_ignore_patterns": [],
  "backup_tolerated_ephemeral_ignore_patterns": [],
  "protected_data_probe_paths": ["$source_dir"],
  "cloud_materialization_roots": [],
  "cloud_materialization_enabled": false,
  "cloud_materialization_requires_allowed_network": false,
  "network_policy_enabled": false,
  "deny_ssids": [],
  "run_interval_seconds": 21600,
  "network_check_interval_seconds": 5,
  "preflight_failure_retry_seconds": 5,
  "password_source": "environment",
  "password_env_var": "KOPIA_PASSWORD",
  "password_command": [],
  "password_read_timeout_seconds": 5,
  "kopia_config_file": "$kopia_config_file",
  "minimum_execution_reserve_bytes": 1048576,
  "critical_runtime_free_space_bytes": 1048576,
  "unknown_icloud_placeholder_estimate_bytes": 1048576
}
JSON

COPYA_RUNTIME_ROOT="$runtime_root" \
COPYA_CONFIG_FILE="$config_file" \
KOPIA_PASSWORD="$password" \
HOME="$kopia_home" \
  "$copya_bin" --backup-once --timeout "${COPYA_SMOKE_BACKUP_TIMEOUT_SECONDS:-180}"

status_json="$(
  COPYA_RUNTIME_ROOT="$runtime_root" \
  COPYA_CONFIG_FILE="$config_file" \
  HOME="$kopia_home" \
    "$copya_bin" --status-json
)"

STATUS_JSON="$status_json" \
RUNTIME_ROOT="$runtime_root" \
KOPIA_HOME="$kopia_home" \
CONFIG_FILE="$config_file" \
SOURCE_DIR="$source_dir" \
KOPIA_CONFIG_FILE="$kopia_config_file" \
python3 - <<'PY'
import json
import os
import sys

status = json.loads(os.environ["STATUS_JSON"])
summary = status.get("config_summary", {})
if status.get("last_snapshot_id") in (None, ""):
    raise SystemExit("status is missing last_snapshot_id")
if status.get("last_snapshot_root") in (None, ""):
    raise SystemExit("status is missing last_snapshot_root")
expected = {
    "runtime_root": os.environ["RUNTIME_ROOT"],
    "kopia_home": os.environ["KOPIA_HOME"],
    "config_file": os.environ["CONFIG_FILE"],
    "backup_source": os.environ["SOURCE_DIR"],
    "kopia_config_file": os.environ["KOPIA_CONFIG_FILE"],
}
for key, value in expected.items():
    if summary.get(key) != value:
        raise SystemExit(f"status config_summary.{key}={summary.get(key)!r}, expected {value!r}")
for key in ("log_file", "raw_kopia_log_file", "status_file", "active_run_file"):
    path = summary.get(key)
    if not path:
        raise SystemExit(f"status config_summary.{key} is missing")
    if not os.path.realpath(path).startswith(os.path.realpath(os.environ["RUNTIME_ROOT"]) + os.sep):
        raise SystemExit(f"status config_summary.{key} escaped runtime root: {path}")
if summary.get("network_policy_enabled") is not False:
    raise SystemExit("status did not report CI network policy bypass")
if summary.get("cloud_materialization_enabled") is not False:
    raise SystemExit("status did not report CI cloud materialization bypass")
if summary.get("password_source") != "environment":
    raise SystemExit("status did not report environment password source")
text = json.dumps(status)
if "copya-smoke-password" in text:
    raise SystemExit("status leaked the smoke password")
PY

COPYA_BIN="$copya_bin" \
KOPIA_BIN="$kopia_bin" \
COPYA_RUNTIME_ROOT="$runtime_root" \
COPYA_CONFIG_FILE="$config_file" \
COPYA_KOPIA_CONFIG_FILE="$kopia_config_file" \
COPYA_KOPIA_HOME="$kopia_home" \
KOPIA_PASSWORD="$password" \
HOME="$kopia_home" \
  "$ROOT_DIR/scripts/restore-smoke.sh" fixture.txt

if grep -R "copya-smoke-password" "$work_dir" >/dev/null 2>&1; then
  echo "release smoke temp files leaked the smoke password" >&2
  exit 1
fi

echo "release smoke succeeded"
