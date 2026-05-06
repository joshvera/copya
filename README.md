# macOS Kopia Backups with Pyinfra

This deploy installs native macOS Kopia with Homebrew and manages a signed
menu bar app, `COPYA.app`, as the backup orchestrator. The app owns Wi-Fi
policy, scheduling, process control, status, and manual actions.
launchd only starts the monitor app at login and relaunches it after crashes.

The B2 repository and Kopia password stay outside git.

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

The app reads this value with `op read` only when starting a backup, then
passes it to the Kopia child process as `KOPIA_PASSWORD`. The password is not
written to the status file, logs, or git.

Before relying on unattended runs, verify that `op read` works in the user
session without manual input:

```bash
op read "$(python3 - <<'PY'
from group_data import all
print(all.kopia_password_ref)
PY
)" >/dev/null
```

For fully unattended launchd runs, `op read` must not require interaction at
backup time. If needed, use a 1Password service account with access to a
non-Private vault and update `kopia_password_ref`.

## Deploy

Run pyinfra through uv from this directory:

```bash
cd /Users/vera/github/services/backups/kopia-mac
uv run pyinfra @local deploy.py --dry
uv run pyinfra @local deploy.py
```

The deploy:

- installs `kopia` and `1password-cli`;
- builds and signs `/Users/vera/.local/kopia-backup/COPYA.app`;
- removes the legacy `com.vera.kopia.backup` runner LaunchAgent;
- installs and bootstraps `com.vera.kopia.monitor`.

The configured macOS user and home directory must already exist. This deploy
will not create `/Users/vera`.

## Signing

The local app is signed with the identity configured in `group_data/all.py`:

```text
Apple Development: Joshua Vera (HBBYKPXNDM)
```

Verify the installed app signature:

```bash
codesign --verify --deep --strict "/Users/vera/.local/kopia-backup/COPYA.app"
```

Developer ID notarization is intentionally not part of this local setup yet.

## Grant Wi-Fi Permission

The app uses CoreWLAN and Core Location permission to read the exact SSID.
Grant Location Services from an interactive session:

```bash
"/Users/vera/.local/kopia-backup/COPYA.app/Contents/MacOS/kopia-backup-monitor" --request-location
"/Users/vera/.local/kopia-backup/COPYA.app/Contents/MacOS/kopia-backup-monitor" --network-json
```

If macOS does not prompt, open System Settings -> Privacy & Security ->
Location Services and allow `COPYA`.

SSID redaction, missing SSID, or missing Location permission is a degraded
state and blocks backups. This is required because the policy is exact SSID
denylist matching: `Freeside` and `cerise` are denied; all exact non-denied
SSIDs, including `MANAWA`, are allowed.

## Monitor and Control

The menu bar app shows:

- current state: Ready, Syncing, Paused, Needs Permission, Failed, or Disabled;
- current SSID and policy reason;
- next scheduled run;
- last successful backup;
- active Kopia PID when syncing;
- last failure or abort reason.

Menu actions include Start Backup Now, Stop Backup, Check Network, Grant Wi-Fi
Permission, Open Log, Copy Debug Status, and Quit Monitor.

The app writes status JSON here:

```bash
/Users/vera/.local/kopia-backup/status.json
```

Useful debug commands:

```bash
"/Users/vera/.local/kopia-backup/COPYA.app/Contents/MacOS/kopia-backup-monitor" --status-json
"/Users/vera/.local/kopia-backup/COPYA.app/Contents/MacOS/kopia-backup-monitor" --network-json
launchctl print gui/$(id -u)/com.vera.kopia.monitor
pgrep -fl 'kopia-backup-monitor|kopia snapshot create'
tail -f /Users/vera/Library/Logs/kopia-backup.log
```

## Scheduling Behavior

The app starts Kopia directly:

```bash
kopia snapshot create --no-progress /Users/vera
```

Only one Kopia child process may run at a time.

Scheduling rules:

- if no backup has ever completed and the network becomes allowed, start one
  immediately;
- if a preflight step such as reading the 1Password secret fails, retry that
  preflight after `preflight_failure_retry_seconds`;
- after a successful backup, schedule the next run at
  `last_success_at + run_interval_seconds`;
- if a scheduled run arrives while the network is denied or degraded, skip
  that interval and schedule the next one;
- if Wi-Fi becomes denied or degraded while Kopia is running, stop Kopia with
  TERM, then KILL if it does not exit.

The app appends human-readable audit logs to:

```bash
/Users/vera/Library/Logs/kopia-backup.log
```

## Restore Test

List snapshots and restore one into a temporary location:

```bash
kopia snapshot list /Users/vera
kopia snapshot restore <snapshot-id> /tmp/kopia-restore-test
```

Inspect `/tmp/kopia-restore-test`, then remove it when finished.
