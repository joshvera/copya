user = "vera"
home = "/Users/vera"

backup_source = "/Users/vera"

deny_ssids = [
    "Freeside",
    "cerise",
]

legacy_backup_launchd_label = "com.vera.kopia.backup"
monitor_launchd_label = "com.vera.kopia.monitor"
run_interval_seconds = 21600
network_check_interval_seconds = 60

runner_dir = "/Users/vera/.local/kopia-backup"
log_file = "/Users/vera/Library/Logs/kopia-backup.log"
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
