# COPYA

COPYA is a native macOS menu bar orchestrator for Kopia home-directory backups.
It is deployed reproducibly with pyinfra, kept running by a LaunchAgent, and
uses Wi-Fi policy, cloud-file preparation, disk checks, and Kopia process
ownership to avoid the usual "is this backup actually doing anything?" nonsense.

COPYA is file-level backup orchestration. It is not Time Machine, not an
APFS-consistent database snapshot system, and not a magic API for forcing every
cloud provider placeholder offline.

## What It Does

- Installs native Kopia with Homebrew.
- Builds a SwiftUI `MenuBarExtra` app called `COPYA.app`.
- Starts the menu app at login with launchd.
- Starts and stops `kopia snapshot create --no-progress <backup_source>`.
- Blocks backups on denied Wi-Fi SSIDs, missing/redacted SSID, missing
  permissions, unavailable secrets, and insufficient local disk space.
- Prepares iCloud/FileProvider roots before backup and reports whether cloud
  coverage is complete or partial.
- Writes human-readable logs plus machine-readable status JSON.
- Keeps secrets out of git and out of status/log output.

## Requirements

- macOS 13 or newer.
- Homebrew.
- `uv`.
- A Kopia repository already connected locally.
- A Kopia repository password available through one configured secret source.
- Optional: Apple Development or Developer ID signing identity. Public defaults
  use ad-hoc signing.

Install `uv` if needed:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

## Configure

Create local config from the public example:

```bash
cp group_data/example.py group_data/all.py
```

Edit `group_data/all.py` for this Mac:

- `user`
- `home`
- `backup_source`
- `deny_ssids`
- `app_bundle_identifier`
- `monitor_launchd_label`
- `app_signing_identity`
- password source settings

`group_data/all.py` is intentionally ignored by git. Do not commit local paths,
signing identities, SSIDs, or secret references.

## Password Sources

COPYA passes `KOPIA_PASSWORD` only to the Kopia child process. The password is
not written to logs, status JSON, or git.

Supported sources:

```python
password_source = "environment"
password_env_var = "KOPIA_PASSWORD"
```

The environment source is useful for manual runs and custom launchd setups, but
LaunchAgents do not inherit your shell profile. For unattended backups, make
sure the variable is present in the launchd environment or prefer `command` /
`onepassword`.

```python
password_source = "command"
password_command = ["/path/to/read-password"]
```

The command must print only the password to stdout. COPYA deliberately does not
store command stderr in logs or status JSON because secret helpers have a
talent for saying cursed things when they fail.

```python
password_source = "onepassword"
kopia_password_ref = "op://Vault/Item/field"
```

For unattended launchd runs, make sure the chosen source works without manual
interaction in the user session. If 1Password is locked or authorization times
out, COPYA reports `Secret Unavailable` / `Needs 1Password Unlock` and retries
instead of pretending Kopia failed.

## Connect Kopia

Create or connect the Kopia repository manually before enabling unattended
backups. For Backblaze B2:

```bash
kopia repository connect b2
```

Repository credentials stay outside this repo.

## Deploy

Run from this directory:

```bash
uv run pyinfra @local deploy.py --dry
uv run pyinfra @local deploy.py
```

Deploy does not use `pyinfra.operations.launchd.service`; it uses modern
per-user `launchctl gui/$(id -u)` bootstrap, enable, and kickstart commands.

By default, deploy refuses to restart COPYA while a matching Kopia snapshot is
active. Wait for the snapshot to finish, stop it from COPYA, or deliberately set
`allow_deploy_restart_while_backup_running = True` in local config.

## Permissions

Grant Location Services to `COPYA.app` so it can read exact SSIDs:

```bash
"/Applications/COPYA.app/Contents/MacOS/kopia-backup-monitor" --request-location
"/Applications/COPYA.app/Contents/MacOS/kopia-backup-monitor" --network-json
```

Grant Full Disk Access to `COPYA.app` for a complete home backup that includes
Desktop, Documents, iCloud Drive containers, Mail, Messages, Safari, Photos
libraries, and similar protected data.

If Kopia itself still cannot read protected paths, add the Homebrew Kopia
executable to Full Disk Access as a fallback:

```bash
/opt/homebrew/bin/kopia
```

Photos needs local originals for a complete file-level backup. If iCloud Photos
or iCloud Drive uses optimized storage, raw file backup coverage depends on what
macOS has actually materialized locally.

## Monitor

Useful commands:

```bash
"/Applications/COPYA.app/Contents/MacOS/kopia-backup-monitor" --status-json
"/Applications/COPYA.app/Contents/MacOS/kopia-backup-monitor" --network-json
"/Applications/COPYA.app/Contents/MacOS/kopia-backup-monitor" --classify-last-kopia-errors
launchctl print gui/$(id -u)/<monitor_launchd_label>
pgrep -fl 'kopia-backup-monitor|kopia snapshot create'
tail -f "$HOME/Library/Logs/kopia-backup.log"
```

The menu shows state, SSID policy, next run, last clean success, partial snapshot
classification, disk health, cloud coverage, active PID, and internal Kopia
activity while `--no-progress` keeps stdout quiet.

## Restore Smoke Test

Do not full-restore your home directory as a routine health check. That can burn
huge local disk space and proves very little beyond "you had disk space."

Use the bounded restore smoke instead:

```bash
scripts/restore-smoke.sh path/relative/to/backup_source/small-file.txt
```

The script:

- reads the latest snapshot ID and root from COPYA status JSON;
- shallow-restores the root with `--shallow=0 --shallow-minsize=0`;
- refuses roots, directories, traversal paths, and files above the configured
  smoke-test size limit;
- restores one specific small file, default max 50 MiB;
- compares SHA-256 with the live file when it still exists;
- records the snapshot/root IDs in output;
- cleans its temporary `copya-restore-smoke.*` directory even on failure.

Run a full restore only as an explicit disaster-recovery drill.

## Open Source Hygiene

Before publishing:

```bash
scripts/oss-scan.sh
python3 -m py_compile deploy.py tests/test_copya_template.py
uv run python -m unittest tests/test_copya_template.py
uv run pyinfra @local deploy.py --dry
git diff --check
```

The scan checks tracked files for personal paths, private bundle identifiers,
private 1Password refs, logs, status files, and built app bundles.

## Keeping COPYA Inside Another Repo

For a private services/orchestration repo, keep COPYA as a submodule:

```bash
git submodule add <copya-repo-url> backups/kopia-mac
```

Make changes inside the COPYA repo, commit and push there, then commit the
submodule pointer update in the parent repo. Submodules are annoying, but they
make ownership and release history explicit. That is the right kind of annoying.
