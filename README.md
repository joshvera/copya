# COPYA

COPYA is a native macOS menu bar orchestrator for Kopia home-directory backups.
The public direction is a standalone `COPYA.app`: build the app, drag it into
`/Applications`, grant macOS permissions, connect a Kopia repository, and let
COPYA own scheduling, network policy, cloud-file preparation, process control,
logs, and status.

COPYA is file-level backup orchestration. It is not Time Machine, not an
APFS-consistent database snapshot system, and not a magic API for forcing every
cloud provider placeholder offline.

## What It Does

- Builds a SwiftUI `MenuBarExtra` app called `COPYA.app`.
- Bundles a pinned, checksum-verified Kopia binary into the app at build time.
- Registers its bundled LaunchAgent through `SMAppService`.
- Starts and stops `kopia snapshot create --no-progress <backup_source>`.
- Blocks backups on denied Wi-Fi SSIDs, missing/redacted SSID, missing
  permissions, unavailable secrets, and insufficient local disk space.
- Prepares iCloud/FileProvider roots before backup and reports whether cloud
  coverage is complete or partial.
- Writes human-readable logs plus machine-readable status JSON.
- Keeps secrets out of git and out of status/log output.

## Requirements

- macOS 13 or newer.
- Xcode command line tools to build from source.
- Network access during packaging so the build can download the pinned upstream
  Kopia artifact listed in `release/kopia.env`. The archive is cached under
  `.build/kopia` after checksum verification.
- A Kopia repository already connected locally, or one you connect during setup.
- A Kopia repository password available through one configured secret source.
- A Developer ID Application or Apple Development signing identity if you want
  to register the bundled login agent from a source build. The build script
  auto-detects one when available. Ad-hoc builds can run manually, but macOS may
  reject the `SMAppService` login agent at launch time.

## Build The App

```bash
scripts/build-app.sh
```

That produces:

```text
.build/app/COPYA.app
```

To create a local DMG:

```bash
scripts/package-dmg.sh
```

The build script is intentionally pyinfra-free and Jinja-free. It compiles the
native Swift source with SwiftPM, builds the app bundle, copies the bundled
LaunchAgent plist into `Contents/Library/LaunchAgents`, downloads the pinned
Kopia release from `release/kopia.env`, verifies its SHA-256, bundles it under
`Contents/Resources/bin/kopia`, includes Kopia license/notice files, and
codesigns the result. The LaunchAgent runs the signed `COPYA` executable in
headless agent mode with `COPYA_AGENT=1`, so launchd owns one backup controller
while the menu UI can remain a status viewer.

For local development only, you can override the bundled Kopia binary:

```bash
COPYA_KOPIA_BIN=/opt/homebrew/bin/kopia scripts/build-app.sh
```

Release builds reject that override. Public artifacts must be reproducible from
the pinned upstream archive and checksum.

The build script auto-detects a local Developer ID Application or Apple
Development signing identity. To force a specific identity:

```bash
COPYA_CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  scripts/package-dmg.sh
```

To force ad-hoc signing for local manual testing:

```bash
COPYA_CODESIGN_IDENTITY=- scripts/build-app.sh
```

Ad-hoc builds are not a valid proof that the login agent can run. Test
`--register-login-agent` with a real signing identity or a release build.

## Release DMG

Use the release wrapper for public artifacts:

```bash
COPYA_CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
COPYA_NOTARYTOOL_PROFILE=copya-notary \
  scripts/release-dmg.sh
```

`scripts/release-dmg.sh` requires a Developer ID Application identity, forces the
pinned Kopia artifact path, signs the DMG, submits it with `xcrun notarytool`,
staples the notarization ticket, and runs `spctl` assessment on the final DMG.

Instead of a keychain profile, you can provide:

```bash
COPYA_NOTARYTOOL_KEY=/path/to/AuthKey_ABC123DEFG.p8
COPYA_NOTARYTOOL_KEY_ID=ABC123DEFG
COPYA_NOTARYTOOL_ISSUER_ID=00000000-0000-0000-0000-000000000000
```

GitHub releases run through `.github/workflows/release.yml` on protected
`vX.Y.Z` tags. Configure a protected `copya-release` environment with required
review and these secrets:

```text
APPLE_DEVELOPER_ID_CERT_P12_BASE64
APPLE_DEVELOPER_ID_CERT_PASSWORD
APPSTORE_CONNECT_API_KEY_P8_BASE64
APPSTORE_CONNECT_KEY_ID
APPSTORE_CONNECT_ISSUER_ID
```

The workflow imports the Developer ID certificate into a temporary keychain,
uses an App Store Connect API key for notarization, installs the notarized DMG,
creates a temporary filesystem Kopia repository, runs `COPYA --backup-once`, and
restores one fixture file. It does not use B2 or production Kopia credentials.

Do not remove the legacy pyinfra/Jinja fallback until a notarized DMG has passed
a clean install, backup smoke, and bounded restore smoke on a machine that did
not already have the old installer path set up.

## Install And Start At Login

Copy the built app to `/Applications`, then register its LaunchAgent:

```bash
cp -R .build/app/COPYA.app /Applications/COPYA.app
"/Applications/COPYA.app/Contents/MacOS/COPYA" --register-login-agent
"/Applications/COPYA.app/Contents/MacOS/COPYA" --login-agent-status
```

You can also use the menu items:

- `Enable at Login`
- `Disable Login Agent`
- `Open Login Items`

The LaunchAgent plist is bundled in the app and uses `BundleProgram`, so macOS
can resolve the executable relative to the app bundle.

## Runtime Config

The standalone app now uses runtime paths under the current macOS user:

```text
~/Library/Application Support/COPYA/config.json
~/Library/Application Support/COPYA/status.json
~/Library/Application Support/COPYA/active-run.json
~/Library/Logs/COPYA/copya.log
~/Library/Logs/COPYA/kopia-raw.log
```

The default backup source is the current user's home directory. The first public
onboarding pass still needs editable UI for source path, schedule, denylisted
SSIDs, repository import, and secret provider selection. Until then, create and
edit the JSON config directly:

```bash
"/Applications/COPYA.app/Contents/MacOS/COPYA" --write-default-config
"/Applications/COPYA.app/Contents/MacOS/COPYA" --config-json
```

Partial config files are allowed. Missing fields fall back to safe defaults, so
you can override only the values you care about instead of maintaining a cursed
giant config blob by hand. For now, the legacy pyinfra path remains available as
a migration fallback for power-user configuration.

CI and tests can isolate runtime state without touching the real user profile:

```bash
COPYA_RUNTIME_ROOT=/tmp/copya-runtime \
COPYA_CONFIG_FILE=/tmp/copya-config.json \
  "/Applications/COPYA.app/Contents/MacOS/COPYA" --status-json
```

`COPYA_RUNTIME_ROOT` moves COPYA support/cache/log/status/active-run paths and
the child Kopia `HOME`. `COPYA_CONFIG_FILE` points at an explicit runtime config;
if that explicit config is missing, unreadable, or invalid JSON, COPYA exits
instead of falling back to the real home directory. For isolated smoke tests, set `network_policy_enabled`
and `cloud_materialization_enabled` to `false`, use `password_source:
"environment"`, and provide `kopia_config_file`.

## Password Sources

COPYA passes `KOPIA_PASSWORD` only to the Kopia child process. The password is
not written to logs, status JSON, or git.

Standalone builds default to the macOS Keychain:

```bash
printf '%s' 'your-kopia-repository-password' \
  | "/Applications/COPYA.app/Contents/MacOS/COPYA" --store-password-in-keychain
```

The legacy pyinfra path also supports environment, command, and 1Password
sources through `group_data/all.py`:

```python
password_source = "environment"
password_env_var = "KOPIA_PASSWORD"

password_source = "command"
password_command = ["/path/to/read-password"]

password_source = "onepassword"
kopia_password_ref = "op://Vault/Item/field"
```

For unattended launchd runs, make sure the chosen source works without manual
interaction in the user session. If a password cannot be read, COPYA reports
`Needs Keychain Password`, `Secret Unavailable`, or `Needs 1Password Unlock` and
retries instead of pretending Kopia failed.

## Connect Kopia

Create or connect the Kopia repository before enabling unattended backups. For
Backblaze B2:

```bash
kopia repository connect b2
```

Repository credentials stay outside this repo. The standalone onboarding flow
will eventually wrap this, but COPYA will not create cloud-provider accounts,
buckets, or B2 application keys for you. Some chores still require a human with
buttons and consequences.

## Legacy Pyinfra Deploy

The old reproducible installer is retained temporarily while standalone parity
is being proven:

```bash
uv run pyinfra @local deploy.py --dry
uv run pyinfra @local deploy.py
```

Deploy does not use `pyinfra.operations.launchd.service`; it uses modern
per-user `launchctl gui/$(id -u)` bootstrap, enable, and kickstart commands.

It still uses `group_data/all.py`, Homebrew, pyinfra, and Jinja templates. Do
not treat that as the public install path going forward. The deletion gate is a
notarized standalone DMG with no terminal-only setup requirement for a first-time
user.

## Permissions

Grant Location Services to `COPYA.app` so it can read exact SSIDs:

```bash
"/Applications/COPYA.app/Contents/MacOS/COPYA" --request-location
"/Applications/COPYA.app/Contents/MacOS/COPYA" --network-json
```

Grant Full Disk Access to `COPYA.app` for a complete home backup that includes
Desktop, Documents, iCloud Drive containers, Mail, Messages, Safari, Photos
libraries, and similar protected data.

If Kopia itself still cannot read protected paths, add the bundled Kopia
executable to Full Disk Access as a fallback:

```bash
/Applications/COPYA.app/Contents/Resources/bin/kopia
```

Photos needs local originals for a complete file-level backup. If iCloud Photos
or iCloud Drive uses optimized storage, raw file backup coverage depends on what
macOS has actually materialized locally.

## Monitor

Useful commands:

```bash
"/Applications/COPYA.app/Contents/MacOS/COPYA" --status-json
"/Applications/COPYA.app/Contents/MacOS/COPYA" --network-json
"/Applications/COPYA.app/Contents/MacOS/COPYA" --config-json
"/Applications/COPYA.app/Contents/MacOS/COPYA" --backup-once --timeout 3600
"/Applications/COPYA.app/Contents/MacOS/COPYA" --classify-last-kopia-errors
"/Applications/COPYA.app/Contents/MacOS/COPYA" --login-agent-status
pgrep -fl 'COPYA|kopia snapshot create'
tail -f "$HOME/Library/Logs/COPYA/copya.log"
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
- uses `/Applications/COPYA.app/Contents/Resources/bin/kopia` by default, so it
  exercises the same bundled Kopia binary as the app;
- honors `config_summary.kopia_config_file` or `COPYA_KOPIA_CONFIG_FILE`, so CI
  restore checks use the same isolated repository config as the one-shot backup;
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
python3 -m py_compile deploy.py group_data/all.py tests/test_copya_template.py tests/test_standalone_app.py
uv run python -m unittest tests/test_copya_template.py tests/test_standalone_app.py
swift build -c debug --product COPYA
scripts/build-app.sh
scripts/package-dmg.sh
bash -n scripts/build-app.sh scripts/package-dmg.sh scripts/release-dmg.sh scripts/restore-smoke.sh scripts/ci-import-codesign-cert.sh scripts/release-tag-gate.sh scripts/release-smoke.sh
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
