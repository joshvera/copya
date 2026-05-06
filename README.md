# macOS Kopia Backups with Pyinfra

This deploy installs native macOS Kopia with Homebrew, renders a
network-gated backup runner, and schedules it as a per-user launchd
LaunchAgent. The B2 repository and Kopia password stay outside git.

## Install uv

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

## Connect Kopia to B2

Connect or create the Kopia B2 repository manually before enabling backups:

```bash
kopia repository connect b2
```

Use your existing B2 bucket and credentials. Do not commit repository
credentials or passwords to this repo.

## Store the Password in 1Password

Store the Kopia repository password in 1Password and use a secret reference.
The default reference is configured in `group_data/all.py`:

```text
op://Private/Kopia/password
```

If your vault, item, or field names differ, update `kopia_password_ref` in
`group_data/all.py`.

The deploy installs `1password-cli` with Homebrew. Before relying on launchd,
verify that the `vera` user can read the secret non-interactively:

```bash
op read "$(python3 - <<'PY'
from group_data import all
print(all.kopia_password_ref)
PY
)"
```

For unattended launchd runs, `op read` must work in the user session without
manual input at backup time. 1Password recommends service accounts for scripts
that need scoped automated access. If you use a service account, store the
Kopia password in a vault the service account can access, not the built-in
Private vault, and update `kopia_password_ref` accordingly.

The optional env file remains available for non-secret overrides, such as a
machine-local secret reference:

```bash
mkdir -p ~/.config/kopia-backup
chmod 700 ~/.config/kopia-backup
printf 'KOPIA_PASSWORD_REF=%s\n' 'op://Private/Kopia/password' > ~/.config/kopia-backup/env
chmod 600 ~/.config/kopia-backup/env
```

## Grant Wi-Fi SSID Permission

The deploy builds a small native macOS helper at:

```bash
/Users/vera/.local/kopia-backup/Kopia\ WiFi\ SSID\ Helper.app/Contents/MacOS/kopia-wifi-ssid
```

The helper uses CoreWLAN to read the current SSID. On modern macOS, SSID access
is protected as location-adjacent data, so grant Location Services permission
from an interactive session after deploying or rebuilding the helper:

```bash
"/Users/vera/.local/kopia-backup/Kopia WiFi SSID Helper.app/Contents/MacOS/kopia-wifi-ssid" --request-location
"/Users/vera/.local/kopia-backup/Kopia WiFi SSID Helper.app/Contents/MacOS/kopia-wifi-ssid" --ssid en0
/Users/vera/.local/kopia-backup/kopia-safe-run.sh --check-network
```

If macOS does not prompt, open System Settings -> Privacy & Security ->
Location Services and allow `Kopia WiFi SSID Helper`. Until this helper can
return the exact SSID, the runner treats `<redacted>` as unsafe and skips.
Because the helper is locally built and ad-hoc signed, rebuilding it can reset
the macOS privacy grant; rerun `--request-location` after changing the helper.

## Deploy

Run pyinfra through uv from this directory:

```bash
cd /Users/vera/github/services/backups/kopia-mac
uv run pyinfra @local deploy.py --dry
uv run pyinfra @local deploy.py
```

The configured macOS user and home directory must already exist. This deploy
will not create `/Users/vera`; macOS should create home directories through the
normal user account/login flow.

If you run the deploy as `vera`, sudo is not needed for the home-directory
files. If you run it from another admin account and `/Users/vera` already
exists, opt into sudo only for the user-home and launchd operations:

```bash
uv run pyinfra @local deploy.py --data use_sudo=true
```

The deploy uses modern per-user launchd commands directly:
`bootstrap`, `bootout`, `enable`, and `kickstart` against `gui/$(id -u)`.

## Test Manually

Run the generated runner directly:

```bash
/Users/vera/.local/kopia-backup/kopia-safe-run.sh
tail -n 100 /Users/vera/Library/Logs/kopia-backup.log
```

The runner skips backups when no SSID is detected, or when the current SSID
is `Freeside` or `cerise`. It also treats macOS SSID redaction as a visibility
failure and skips until the runner can read the exact SSID.

The runner checks the network before starting Kopia and every
`network_check_interval_seconds` while Kopia is running. If Wi-Fi changes to
`Freeside`, `cerise`, missing, or redacted during a backup, the runner stops
the active Kopia child and exits cleanly. Switching back to an allowed network
does not immediately start a new backup by itself; wait for the next launchd
interval or run `launchctl kickstart -k gui/$(id -u)/com.vera.kopia.backup`.

Check what the runner sees without starting a backup:

```bash
/Users/vera/.local/kopia-backup/kopia-safe-run.sh --check-network
```

Modern macOS privacy controls can hide SSID values from command-line tools. If
the check reports `state=redacted`, fix SSID visibility for the user/session
before relying on unattended backups. Apple documents SSID access restrictions
for `CNCopyCurrentNetworkInfo` here:
<https://developer.apple.com/documentation/systemconfiguration/cncopycurrentnetworkinfo>.

## Check launchd Status

```bash
launchctl print gui/$(id -u)/com.vera.kopia.backup
```

Useful follow-up commands:

```bash
launchctl kickstart -k gui/$(id -u)/com.vera.kopia.backup
pgrep -fl 'kopia-safe-run|kopia snapshot create'
tail -f /Users/vera/Library/Logs/kopia-backup.log
```

To stop a running backup and unload the LaunchAgent:

```bash
launchctl bootout gui/$(id -u) /Users/vera/Library/LaunchAgents/com.vera.kopia.backup.plist || true
pgrep -fl 'kopia-safe-run|kopia snapshot create'
```

## Log Audit

The runner writes start, skip, network-abort, success, and failure messages to
`/Users/vera/Library/Logs/kopia-backup.log`. Kopia is run with `--no-progress`
so the log stays readable.

Useful audit commands:

```bash
perl -pe 's/\r/\n/g' /Users/vera/Library/Logs/kopia-backup.log | rg 'kopia backup starting|network allowed|skip:|abort:|success:|failure:'
perl -pe 's/\r/\n/g' /Users/vera/Library/Logs/kopia-backup.log | rg -c 'storage_cap_exceeded|Cannot upload files, storage cap exceeded'
perl -pe 's/\r/\n/g' /Users/vera/Library/Logs/kopia-backup.log | rg -c 'resource deadlock avoided|operation not permitted'
```

`storage_cap_exceeded` is a real B2-side cap/quota failure that must be fixed
outside pyinfra. `resource deadlock avoided` and `operation not permitted` are
local file-read failures; review recurring paths before adding broad Kopia
ignore policies.

## Restore Test

List snapshots and restore one into a temporary location:

```bash
kopia snapshot list /Users/vera
kopia snapshot restore <snapshot-id> /tmp/kopia-restore-test
```

Inspect `/tmp/kopia-restore-test`, then remove it when finished.
