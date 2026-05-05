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
verify that the `josh` user can read the secret non-interactively:

```bash
op read op://Private/Kopia/password
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

## Deploy

Run pyinfra through uv from this directory:

```bash
cd /Users/vera/github/services/backups/kopia-mac
uv run pyinfra @local deploy.py --dry
uv run pyinfra @local deploy.py
```

The deploy uses modern per-user launchd commands directly:
`bootstrap`, `bootout`, `enable`, and `kickstart` against `gui/$(id -u)`.

## Test Manually

Run the generated runner directly:

```bash
/Users/josh/.local/kopia-backup/kopia-safe-run.sh
tail -n 100 /Users/josh/Library/Logs/kopia-backup.log
```

The runner skips backups when no SSID is detected, or when the current SSID
is `Freeside` or `cerise`.

## Check launchd Status

```bash
launchctl print gui/$(id -u)/com.josh.kopia.backup
```

Useful follow-up commands:

```bash
launchctl kickstart -k gui/$(id -u)/com.josh.kopia.backup
tail -f /Users/josh/Library/Logs/kopia-backup.log
```

## Restore Test

List snapshots and restore one into a temporary location:

```bash
kopia snapshot list /Users/josh
kopia snapshot restore <snapshot-id> /tmp/kopia-restore-test
```

Inspect `/tmp/kopia-restore-test`, then remove it when finished.
