user = "example"
home = f"/Users/{user}"

backup_source = home
backup_ignore_file = f"{home}/.kopiaignore"
backup_ignore_patterns = []
backup_tolerated_ephemeral_ignore_patterns = [
    {
        "pattern": "/Library/Metadata/CoreSpotlight/*",
        "reason": "CoreSpotlight indexes are system-generated and protected.",
    },
    {
        "pattern": "/Library/Application Support/FileProvider/*/wharf/tombstone/*",
        "reason": "FileProvider tombstones are provider bookkeeping, not user files.",
    },
    {
        "pattern": "/Library/DuetExpertCenter/*",
        "reason": "DuetExpertCenter prediction caches are system-generated.",
    },
    {
        "pattern": "/Library/Group Containers/group.com.apple.CoreSpeech/Caches/*",
        "reason": "CoreSpeech cache files are generated speech assets.",
    },
    {
        "pattern": "/Library/Containers/*/Data/Library/Saved Application State/*",
        "reason": "Saved Application State is restorable UI cache data.",
    },
    {
        "pattern": "/Library/Daemon Containers/*/Data/com.apple.milod/*",
        "reason": "milo daemon WAL files are protected generated state.",
    },
    {
        "pattern": "/Library/Group Containers/group.com.apple.secure-control-center-preferences/*",
        "reason": "Secure control center preference cache is protected system state.",
    },
    {
        "pattern": "/Library/Containers/com.apple.Maps/Data/Library/Maps/ReportAProblem/*",
        "reason": "Maps ReportAProblem staging files are app-generated scratch data.",
    },
]

protected_data_probe_paths = [
    f"{home}/Desktop",
    f"{home}/Documents",
    f"{home}/Library/Mobile Documents",
    f"{home}/Library/Mobile Documents/com~apple~CloudDocs",
    f"{home}/Library/Mail",
    f"{home}/Library/Messages",
    f"{home}/Library/Safari",
    f"{home}/Pictures/Photos Library.photoslibrary",
]

cloud_materialization_roots = [
    f"{home}/Desktop",
    f"{home}/Documents",
    f"{home}/Library/Mobile Documents",
    f"{home}/Library/CloudStorage",
]
cloud_materialization_enabled = True
cloud_materialization_requires_allowed_network = True
cloud_materialization_timeout_seconds = 3600
cloud_materialization_retry_seconds = 900

deny_ssids = [
    "ExampleMeteredWiFi",
    "ExamplePhoneHotspot",
]

legacy_backup_launchd_label = "dev.example.copya.backup"
monitor_launchd_label = "dev.example.copya.monitor"
run_interval_seconds = 21600
network_check_interval_seconds = 60
preflight_failure_retry_seconds = 300

runner_dir = f"{home}/.local/kopia-backup"
log_file = f"{home}/Library/Logs/kopia-backup.log"
raw_kopia_log_file = f"{runner_dir}/kopia-raw.log"
status_file = f"{runner_dir}/status.json"
active_run_file = f"{runner_dir}/active-run.json"
internal_kopia_activity_probe_enabled = True
internal_kopia_log_dirs = [
    f"{home}/Library/Logs/kopia/cli-logs",
    f"{home}/Library/Logs/kopia/content-logs",
]
internal_kopia_log_mtime_tolerance_seconds = 10
internal_kopia_log_tail_bytes = 131072
kopia_activity_heartbeat_interval_seconds = 300
kopia_internal_log_retention_bytes = 536870912
minimum_execution_reserve_bytes = 53687091200
critical_runtime_free_space_bytes = 21474836480
unknown_icloud_placeholder_estimate_bytes = 268435456
disk_free_space_check_paths = [
    f"{home}/Library/Caches/kopia",
    f"{home}/Library/Logs/kopia",
    raw_kopia_log_file,
    home,
]
allow_deploy_restart_while_backup_running = False

app_name = "COPYA"
app_install_dir = "/Applications"
app_executable_name = "kopia-backup-monitor"
app_bundle_identifier = "dev.example.copya.monitor"
legacy_monitor_app_names = [
    "Kopia Backup Monitor",
]

# "-" means ad-hoc signing. Set an Apple Development or Developer ID identity
# in local group_data/all.py when you want a stable Team ID signature.
app_signing_identity = "-"

onepassword_cli_package = "1password-cli"
password_source = "environment"
password_env_var = "KOPIA_PASSWORD"
password_command = []
password_read_timeout_seconds = 60
kopia_password_ref = ""
use_sudo = False
