# Security

COPYA handles backup orchestration around sensitive local data. Treat every
change as security-relevant until proven otherwise.

## Secrets

COPYA must never commit, log, or write the Kopia repository password to status
JSON. The password should only be passed as `KOPIA_PASSWORD` to the Kopia child
process.

Supported password sources are Keychain, environment variable, command, and
1Password secret reference. Local secret references belong in user runtime
config, not committed files.

## Permissions

macOS Location Services and Full Disk Access are user-granted permissions.
COPYA can open the relevant settings and verify symptoms, but it must not try
to bypass those controls.

## Reporting Issues

For public issues, do not paste logs that contain personal paths, private SSIDs,
repository names, bucket names, or file listings. Redact first. The code tries
to be polite about this, but your logs are still your filesystem talking.
