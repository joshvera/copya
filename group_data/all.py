user = "vera"
home = "/Users/vera"

backup_source = "/Users/vera"
backup_ignore_file = "/Users/vera/.kopiaignore"
backup_ignore_patterns = []

protected_data_probe_paths = [
    "/Users/vera/Desktop",
    "/Users/vera/Documents",
    "/Users/vera/Library/Mobile Documents",
    "/Users/vera/Library/Mobile Documents/com~apple~CloudDocs",
    "/Users/vera/Library/Mail",
    "/Users/vera/Library/Messages",
    "/Users/vera/Library/Safari",
    "/Users/vera/Pictures/Photos Library.photoslibrary",
]

cloud_materialization_roots = [
    "/Users/vera/Desktop",
    "/Users/vera/Documents",
    "/Users/vera/Library/Mobile Documents",
    "/Users/vera/Library/CloudStorage",
]
cloud_materialization_enabled = True
cloud_materialization_requires_allowed_network = True
cloud_materialization_timeout_seconds = 3600
cloud_materialization_retry_seconds = 900

deny_ssids = [
    "Freeside",
    "cerise",
]

legacy_backup_launchd_label = "com.vera.kopia.backup"
monitor_launchd_label = "com.vera.kopia.monitor"
run_interval_seconds = 21600
network_check_interval_seconds = 60
preflight_failure_retry_seconds = 300

runner_dir = "/Users/vera/.local/kopia-backup"
log_file = "/Users/vera/Library/Logs/kopia-backup.log"
raw_kopia_log_file = "/Users/vera/.local/kopia-backup/kopia-raw.log"
status_file = "/Users/vera/.local/kopia-backup/status.json"

app_name = "COPYA"
app_executable_name = "kopia-backup-monitor"
app_bundle_identifier = "com.vera.kopia.monitor"
legacy_monitor_app_names = [
    "Kopia Backup Monitor",
]
app_signing_identity = "Apple Development: Joshua Vera (HBBYKPXNDM)"

onepassword_cli_package = "1password-cli"
kopia_password_ref = "op://Private/Kopia/password"
use_sudo = False
