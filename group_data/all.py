user = "vera"
home = "/Users/vera"

backup_source = "/Users/vera"

deny_ssids = [
    "Freeside",
    "cerise",
]

launchd_label = "com.vera.kopia.backup"
run_interval_seconds = 21600
network_check_interval_seconds = 60

runner_dir = "/Users/vera/.local/kopia-backup"
env_file = "/Users/vera/.config/kopia-backup/env"
log_file = "/Users/vera/Library/Logs/kopia-backup.log"

ssid_helper_name = "kopia-wifi-ssid"
ssid_helper_bundle_name = "Kopia WiFi SSID Helper"
ssid_helper_bundle_identifier = "com.vera.kopia.wifi-ssid"

onepassword_cli_package = "1password-cli"
kopia_password_ref = "op://Private/Kopia/password"
use_sudo = False
