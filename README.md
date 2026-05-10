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
- builds and signs `/Applications/COPYA.app`;
- removes the legacy `com.vera.kopia.backup` runner LaunchAgent;
- removes the old `/Users/vera/.local/kopia-backup/COPYA.app` bundle after
  migration;
- installs and bootstraps `com.vera.kopia.monitor`.

By default, deploy refuses to restart COPYA while a matching
`kopia snapshot create --no-progress /Users/vera` process is active. Wait for
the snapshot to finish or stop it explicitly from COPYA before running the
non-dry deploy. `allow_deploy_restart_while_backup_running` exists as an
intentional escape hatch in `group_data/all.py`.

The configured macOS user and home directory must already exist. This deploy
will not create `/Users/vera`.

## Backup Scope

COPYA snapshots `/Users/vera`. Kopia's default `.kopiaignore` mechanism is
managed from `group_data/all.py` and rendered to:

```bash
/Users/vera/.kopiaignore
```

The default posture is complete local backup, so `backup_ignore_patterns` is
empty. Desktop, Documents, iCloud Drive containers, Dropbox/FileProvider roots,
and protected app data are intended to be backed up when macOS allows COPYA and
Kopia to read them.

COPYA also renders a small managed set of tolerated ephemeral ignores from
`backup_tolerated_ephemeral_ignore_patterns`. These are narrow, anchored
system-generated paths such as CoreSpotlight indexes and FileProvider tombstones.
They are separate from user ignores and must not cover Desktop, Documents,
Downloads, iCloud Drive real files, Mail, Messages, Safari, Photos, WhatsApp
data, broad app containers, or broad FileProvider roots.

Cloud-backed roots are configured in `cloud_materialization_roots`. Before
starting Kopia, COPYA probes protected-data access, estimates cloud placeholder
capacity, attempts best-effort iCloud downloads with `brctl download` and macOS
ubiquitous-item download requests, then classifies files as local-readable,
dataless cloud placeholders, or real read failures. If that preparation is
aborted by network policy, missing SSID visibility, permission failure, timeout,
or insufficient local disk capacity, COPYA blocks the snapshot and records the
specific state.

During cloud preparation, the menu bar keeps the `COPYA` title and shows a
state icon. The menu and `status.json` report the current cloud root, phase,
and read-through counters while the preparation is running.

Dataless cloud placeholders are normal macOS/iCloud/Dropbox/FileProvider
stubs: the path and metadata exist locally, but the bytes are not on disk yet.
COPYA does not open known dataless placeholders during preparation because that
produces low-value `resource deadlock avoided` noise. If placeholders remain,
COPYA reports `Cloud Partial`, keeps sample paths in `status.json`, and still
backs up readable local data. Newly downloaded files are included on the next
backup once macOS clears the dataless flag.

The cloud capacity estimate is intentionally honest instead of magical. COPYA
sums known iCloud placeholder logical sizes, adds a 256 MiB fallback for each
iCloud placeholder whose size metadata is missing, and marks estimate confidence
as `degraded` whenever it used that fallback or had to use filesystem free space
instead of macOS important-usage capacity. Dropbox and other FileProvider
placeholder sizes are reported as advisory because COPYA does not have a
reliable provider-wide "download everything" API for them in v1.

Real per-file read failures are reported separately from dataless placeholders,
but they do not block Kopia by themselves. Kopia can create a restorable snapshot
and still exit non-zero after reporting fatal per-file read errors. COPYA records
that as `Backup Partial` when only tolerated system/placeholder paths failed, or
`Backup Partial, Needs Attention` when user-data, protected app data, or unknown
paths failed. A clean `last_success_at` is still only set on Kopia exit `0`.

The main COPYA log summarizes known dataless/deadlock read noise. Raw Kopia
output is retained separately at:

```bash
/Users/vera/.local/kopia-backup/kopia-raw.log
```

If you want complete cloud coverage, disable iCloud Drive "Optimize Mac
Storage" and use provider UI such as "Make Available Offline" for Dropbox or
other FileProvider roots, then wait for downloads to finish before the next
COPYA run.

To intentionally skip a noisy or unwanted path, add a pattern to
`backup_ignore_patterns` and redeploy. For example:

```text
/Library/CloudStorage
```

## Signing

The local app is signed with the identity configured in `group_data/all.py`:

```text
Apple Development: Joshua Vera (HBBYKPXNDM)
```

Verify the installed app signature:

```bash
codesign --verify --deep --strict "/Applications/COPYA.app"
```

Developer ID notarization is intentionally not part of this local setup yet.

## Grant Wi-Fi Permission

The app uses CoreWLAN and Core Location permission to read the exact SSID.
Grant Location Services from an interactive session:

```bash
"/Applications/COPYA.app/Contents/MacOS/kopia-backup-monitor" --request-location
"/Applications/COPYA.app/Contents/MacOS/kopia-backup-monitor" --network-json
```

If macOS does not prompt, open System Settings -> Privacy & Security ->
Location Services and allow `COPYA`.

SSID redaction, missing SSID, or missing Location permission is a degraded
state and blocks backups. This is required because the policy is exact SSID
denylist matching: `Freeside` and `cerise` are denied; all exact non-denied
SSIDs, including `MANAWA`, are allowed.

## Grant Full Disk Access

COPYA needs Full Disk Access for a complete home backup that includes protected
macOS data such as Desktop/Documents privacy areas, iCloud Drive containers,
Mail, Messages, Safari, and Photos libraries.

Open System Settings -> Privacy & Security -> Full Disk Access and add:

```bash
/Applications/COPYA.app
```

If you previously granted Full Disk Access to the old app bundle under
`/Users/vera/.local/kopia-backup`, grant it again for `/Applications/COPYA.app`
after redeploying.

If COPYA still reports `Needs Full Disk Access` after granting it, add the
Homebrew Kopia executable as a fallback because Kopia is the child process that
ultimately opens files:

```bash
/opt/homebrew/bin/kopia
```

Photos needs local originals for a complete file-level backup. If iCloud Photos
is set to optimize storage, a raw Kopia backup may not contain full-resolution
photo originals until Photos has downloaded them locally.

## Monitor and Control

The menu bar app shows:

- current state: Ready, Starting Backup, Preparing Cloud Files, Syncing,
  External Backup Detected, Paused, Needs Permission, Needs Full Disk Access,
  Needs Disk Space, Cloud Download Blocked, Cloud Partial, Backup Partial,
  Failed, or
  Disabled;
- current SSID and policy reason;
- cloud preparation status;
- cloud capacity estimate, confidence, and advisory provider coverage;
- dataless placeholder and real read-failure counts when cloud coverage is
  partial;
- next scheduled run;
- last successful clean backup;
- last restorable snapshot, including partial result and issue counts;
- active Kopia PID when syncing;
- active operation detail while COPYA is checking existing processes, reading
  1Password, or launching Kopia;
- external Kopia PIDs when a matching snapshot process exists without COPYA
  ownership;
- backup liveness while syncing: elapsed runtime, last monitor heartbeat, and
  best-effort activity from COPYA-owned Kopia internal logs;
- humanized file-read issue summaries from Kopia stdout, without treating those
  counters as backup liveness or backup health;
- disk-space failures with the checked path, free bytes, and required bytes;
- last failure or abort reason.

Kopia is intentionally started with `--no-progress`, so its stdout can be quiet
for long stretches during a healthy backup. COPYA correlates Kopia's internal
logs by active child PID and `active-run.json` start time, then shows labels
such as `upload activity 2s ago via Kopia logs`. This is observability only:
missing, unreadable, malformed, rotated, or stale Kopia internal logs never
stop, fail, restart, or duplicate a backup.

COPYA also checks local disk headroom before starting Kopia and while Kopia is
running. By default, it keeps a 50 GiB execution reserve for Kopia cache, temp,
index, and logs, then adds any actionable iCloud placeholder estimate before
hydration starts. It intentionally stops a running COPYA-owned Kopia process if
the checked volume falls below 20 GiB. The checked paths are configured in
`group_data/all.py` and cover the Kopia cache, Kopia internal logs, COPYA raw
log, and `/Users/vera`.

If Kopia exits non-zero, COPYA classifies common fatal causes from Kopia output.
`no space left on device` is reported as `disk_space_exhausted`;
`storage_cap_exceeded` is reported as a B2 storage cap failure. A disk-space
failure means the local Mac ran out of room for Kopia cache/temp/log writes, not
that the B2 repository is corrupt.

For per-file read errors, COPYA parses each COPYA-owned run from its start
boundary through its exit status. If the run created a snapshot, COPYA stores
`last_snapshot_id`, `last_snapshot_result`, categorized issue counts, and sample
paths in `status.json`. Unknown per-file errors are never tolerated by default;
they are treated as action-required until explicitly classified or fixed.

Kopia's internal logs are diagnostic data used for liveness. COPYA prunes
inactive internal Kopia logs before runs, keeping the newest inactive files up
to the configured retention budget and preserving logs for every currently
running `kopia snapshot create` PID.

Menu actions include Start Backup Now, Stop Backup, Check Network, Grant Wi-Fi
Permission, Open Log, Copy Debug Status, and Quit Monitor.

The app writes status JSON here:

```bash
/Users/vera/.local/kopia-backup/status.json
```

While COPYA owns a running Kopia process, it also writes:

```bash
/Users/vera/.local/kopia-backup/active-run.json
```

That file records the COPYA run ID, app PID, child PID, command, source, and
start time. On relaunch, COPYA uses it to recover ownership of a still-running
backup instead of starting a duplicate. If a matching `kopia snapshot create
--no-progress /Users/vera` process exists without a valid ownership file, COPYA
shows `External Backup Detected`, blocks new starts, and lets `Stop Backup`
terminate those external PIDs explicitly.

COPYA scans for matching Kopia processes both before preflight and again
immediately before launch. If process inspection fails, backup start fails
closed rather than guessing that no Kopia process exists. Deploy cleanup no
longer kills bare Kopia snapshot processes; external backups are surfaced in
the app instead.

Useful debug commands:

```bash
"/Applications/COPYA.app/Contents/MacOS/kopia-backup-monitor" --status-json
"/Applications/COPYA.app/Contents/MacOS/kopia-backup-monitor" --network-json
"/Applications/COPYA.app/Contents/MacOS/kopia-backup-monitor" --classify-last-kopia-errors
"/Applications/COPYA.app/Contents/MacOS/kopia-backup-monitor" --classify-kopia-log /Users/vera/.local/kopia-backup/kopia-raw.log
launchctl print gui/$(id -u)/com.vera.kopia.monitor
pgrep -fl 'kopia-backup-monitor|kopia snapshot create'
cat /Users/vera/.local/kopia-backup/active-run.json
tail -f /Users/vera/Library/Logs/kopia-backup.log
```

## Scheduling Behavior

The app starts Kopia directly:

```bash
kopia snapshot create --no-progress /Users/vera
```

Only one Kopia child process may run at a time.

Potentially slow operations are kept off the menu bar thread: process scans,
protected-data probes, cloud preparation, `op read`, and Kopia process launch.
The menu should remain clickable while COPYA is starting or preparing a backup.

Scheduling rules:

- if no backup has ever completed and the network becomes allowed, start one
  immediately;
- before Kopia starts, probe protected-data access and prepare configured cloud
  roots;
- if Full Disk Access is missing, show `Needs Full Disk Access` and retry later;
- if local disk space is below the configured start threshold, show
  `Needs Disk Space` and wait for the next normal interval or manual retry
  after disk space is freed;
- if cloud materialization is blocked by network, permission, or timeout, show
  `Cloud Download Blocked` and retry later;
- if Kopia succeeds while dataless placeholders remain, show `Cloud Partial`
  instead of hiding the incomplete cloud coverage;
- if Kopia creates a snapshot but reports tolerated per-file read errors, show
  `Backup Partial` and schedule the next run from that snapshot completion;
- if Kopia creates a snapshot but reports user-data or unknown per-file read
  errors, show `Backup Partial, Needs Attention`, keep issue samples in
  `status.json`, and schedule the next run from that snapshot completion;
- if a preflight step such as reading the 1Password secret fails, retry that
  preflight after `preflight_failure_retry_seconds`;
- after a clean successful backup, schedule the next run at
  `last_success_at + run_interval_seconds`;
- if a scheduled run arrives while the network is denied or degraded, skip
  that interval and schedule the next one;
- if Wi-Fi becomes denied or degraded while Kopia is running, stop Kopia with
  TERM, then KILL if it does not exit.
- if local disk space falls below the configured runtime threshold while Kopia
  is running, stop Kopia with TERM, then KILL if it does not exit, and record a
  disk-space failure rather than a generic `status=1`.

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
