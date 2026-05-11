from pyinfra import host
from pyinfra.operations import brew, files, server

try:
    from group_data import all as defaults
except ImportError as exc:
    raise SystemExit(
        "Missing local config: copy group_data/example.py to "
        "group_data/all.py and edit it for this Mac before running deploy.py."
    ) from exc


def data(name):
    return host.data.get(name, getattr(defaults, name))


def bool_data(name):
    value = data(name)
    if isinstance(value, str):
        return value.lower() in {"1", "true", "yes", "on"}
    return bool(value)


user = data("user")
home = data("home")
backup_source = data("backup_source")
backup_ignore_file = data("backup_ignore_file")
backup_ignore_patterns = data("backup_ignore_patterns")
backup_tolerated_ephemeral_ignore_patterns = data("backup_tolerated_ephemeral_ignore_patterns")
protected_data_probe_paths = data("protected_data_probe_paths")
cloud_materialization_roots = data("cloud_materialization_roots")
cloud_materialization_enabled = bool_data("cloud_materialization_enabled")
cloud_materialization_requires_allowed_network = bool_data("cloud_materialization_requires_allowed_network")
cloud_materialization_timeout_seconds = data("cloud_materialization_timeout_seconds")
cloud_materialization_retry_seconds = data("cloud_materialization_retry_seconds")
deny_ssids = data("deny_ssids")
legacy_backup_launchd_label = data("legacy_backup_launchd_label")
monitor_launchd_label = data("monitor_launchd_label")
run_interval_seconds = data("run_interval_seconds")
network_check_interval_seconds = data("network_check_interval_seconds")
preflight_failure_retry_seconds = data("preflight_failure_retry_seconds")
runner_dir = data("runner_dir")
log_file = data("log_file")
raw_kopia_log_file = data("raw_kopia_log_file")
status_file = data("status_file")
active_run_file = data("active_run_file")
internal_kopia_activity_probe_enabled = bool_data("internal_kopia_activity_probe_enabled")
internal_kopia_log_dirs = data("internal_kopia_log_dirs")
internal_kopia_log_mtime_tolerance_seconds = data("internal_kopia_log_mtime_tolerance_seconds")
internal_kopia_log_tail_bytes = data("internal_kopia_log_tail_bytes")
kopia_activity_heartbeat_interval_seconds = data("kopia_activity_heartbeat_interval_seconds")
kopia_internal_log_retention_bytes = data("kopia_internal_log_retention_bytes")
minimum_execution_reserve_bytes = data("minimum_execution_reserve_bytes")
critical_runtime_free_space_bytes = data("critical_runtime_free_space_bytes")
unknown_icloud_placeholder_estimate_bytes = data("unknown_icloud_placeholder_estimate_bytes")
disk_free_space_check_paths = data("disk_free_space_check_paths")
allow_deploy_restart_while_backup_running = bool_data("allow_deploy_restart_while_backup_running")
app_name = data("app_name")
app_install_dir = data("app_install_dir")
app_executable_name = data("app_executable_name")
app_bundle_identifier = data("app_bundle_identifier")
legacy_monitor_app_names = data("legacy_monitor_app_names")
app_signing_identity = data("app_signing_identity")
onepassword_cli_package = data("onepassword_cli_package")
password_source = data("password_source")
password_env_var = data("password_env_var")
password_command = data("password_command")
password_read_timeout_seconds = data("password_read_timeout_seconds")
kopia_password_ref = data("kopia_password_ref")
use_sudo = bool_data("use_sudo")

launch_agents_dir = f"{home}/Library/LaunchAgents"
log_dir = log_file.rsplit("/", 1)[0]
status_dir = status_file.rsplit("/", 1)[0]

app_bundle_dir = f"{app_install_dir}/{app_name}.app"
app_contents_dir = f"{app_bundle_dir}/Contents"
app_macos_dir = f"{app_contents_dir}/MacOS"
app_resources_dir = f"{app_contents_dir}/Resources"
app_executable_path = f"{app_macos_dir}/{app_executable_name}"
app_source_path = f"{runner_dir}/{app_executable_name}.swift"
app_info_plist_path = f"{app_contents_dir}/Info.plist"
app_entitlements_path = f"{app_contents_dir}/entitlements.plist"
app_stamp_path = f"{runner_dir}/{app_executable_name}.sha256"

monitor_plist_path = f"{launch_agents_dir}/{monitor_launchd_label}.plist"
legacy_backup_plist_path = f"{launch_agents_dir}/{legacy_backup_launchd_label}.plist"
legacy_runner_path = f"{runner_dir}/kopia-safe-run.sh"
legacy_helper_bundle_dir = f"{runner_dir}/Kopia WiFi SSID Helper.app"
legacy_helper_source_path = f"{runner_dir}/kopia-wifi-ssid.swift"
legacy_helper_stamp_path = f"{runner_dir}/kopia-wifi-ssid.sha256"
legacy_local_app_bundle_dir = f"{runner_dir}/{app_name}.app"
legacy_local_app_executable_path = (
    f"{legacy_local_app_bundle_dir}/Contents/MacOS/{app_executable_name}"
)
legacy_monitor_app_bundle_dirs = [
    f"{runner_dir}/{legacy_app_name}.app"
    for legacy_app_name in legacy_monitor_app_names
]

uid_command = f"id -u {user}"
launchd_domain = f"gui/$({uid_command})"
monitor_launchd_service = f"{launchd_domain}/{monitor_launchd_label}"

template_context = {
    "app_bundle_identifier": app_bundle_identifier,
    "app_executable_name": app_executable_name,
    "app_executable_path": app_executable_path,
    "app_install_dir": app_install_dir,
    "app_name": app_name,
    "active_run_file": active_run_file,
    "backup_ignore_file": backup_ignore_file,
    "backup_ignore_patterns": backup_ignore_patterns,
    "backup_tolerated_ephemeral_ignore_patterns": backup_tolerated_ephemeral_ignore_patterns,
    "backup_source": backup_source,
    "cloud_materialization_enabled": cloud_materialization_enabled,
    "cloud_materialization_requires_allowed_network": cloud_materialization_requires_allowed_network,
    "cloud_materialization_retry_seconds": cloud_materialization_retry_seconds,
    "cloud_materialization_roots": cloud_materialization_roots,
    "cloud_materialization_timeout_seconds": cloud_materialization_timeout_seconds,
    "deny_ssids": deny_ssids,
    "home": home,
    "kopia_password_ref": kopia_password_ref,
    "log_file": log_file,
    "monitor_launchd_label": monitor_launchd_label,
    "network_check_interval_seconds": network_check_interval_seconds,
    "password_source": password_source,
    "password_env_var": password_env_var,
    "password_command": password_command,
    "password_read_timeout_seconds": password_read_timeout_seconds,
    "preflight_failure_retry_seconds": preflight_failure_retry_seconds,
    "raw_kopia_log_file": raw_kopia_log_file,
    "protected_data_probe_paths": protected_data_probe_paths,
    "run_interval_seconds": run_interval_seconds,
    "runner_dir": runner_dir,
    "status_file": status_file,
    "internal_kopia_activity_probe_enabled": internal_kopia_activity_probe_enabled,
    "internal_kopia_log_dirs": internal_kopia_log_dirs,
    "internal_kopia_log_mtime_tolerance_seconds": internal_kopia_log_mtime_tolerance_seconds,
    "internal_kopia_log_tail_bytes": internal_kopia_log_tail_bytes,
    "kopia_activity_heartbeat_interval_seconds": kopia_activity_heartbeat_interval_seconds,
    "kopia_internal_log_retention_bytes": kopia_internal_log_retention_bytes,
    "minimum_execution_reserve_bytes": minimum_execution_reserve_bytes,
    "critical_runtime_free_space_bytes": critical_runtime_free_space_bytes,
    "unknown_icloud_placeholder_estimate_bytes": unknown_icloud_placeholder_estimate_bytes,
    "disk_free_space_check_paths": disk_free_space_check_paths,
    "config_user": user,
}


server.shell(
    name="Validate configured macOS user, home, and signing identity",
    commands=[
        (
            f'id -u "{user}" >/dev/null 2>&1 || '
            f'(echo "Configured macOS user {user} does not exist; '
            'update group_data/all.py or create the user first." >&2; exit 1)'
        ),
        (
            f'test -d "{home}" || '
            f'(echo "Configured home {home} does not exist. Refusing to create '
            f'macOS user home directories; create/login as {user} first or '
            'update group_data/all.py." >&2; exit 1)'
        ),
        (
            f'test "$(stat -f %Su "{home}")" = "{user}" || '
            f'(echo "Configured home {home} is not owned by {user}; refusing '
            'to manage files there." >&2; exit 1)'
        ),
        (
            f'if test "{app_signing_identity}" != "-"; then '
            f'security find-identity -v -p codesigning | grep -F "{app_signing_identity}" '
            f'>/dev/null || (echo "Signing identity not found: {app_signing_identity}" '
            '>&2; exit 1); '
            "fi"
        ),
        (
            f'test -w "{app_install_dir}" || '
            f'(echo "Configured app install directory {app_install_dir} is not writable. '
            f'Use an admin user or choose a user-writable app_install_dir." >&2; exit 1)'
        ),
    ],
)

brew.packages(
    name=(
        "Install Kopia and 1Password CLI"
        if password_source == "onepassword"
        else "Install Kopia"
    ),
    packages=(
        ["kopia", onepassword_cli_package]
        if password_source == "onepassword"
        else ["kopia"]
    ),
)

if not allow_deploy_restart_while_backup_running:
    server.shell(
        name="Refuse monitor restart while COPYA backup is active",
        commands=[
            (
                f'if /usr/bin/pgrep -flx "(.*/)?kopia snapshot create --no-progress {backup_source}" '
                ">/dev/null; then "
                'echo "Active matching Kopia backup detected; refusing to redeploy/restart the monitor. '
                'Wait for the backup to finish, stop it explicitly, or set '
                'allow_deploy_restart_while_backup_running=True for an intentional override." >&2; '
                "exit 1; "
                "fi"
            ),
        ],
        _sudo=use_sudo,
    )

files.directory(
    name="Create Kopia monitor state directory",
    path=runner_dir,
    mode="700",
    user=user,
    _sudo=use_sudo,
)

files.directory(
    name="Create Kopia log directory",
    path=log_dir,
    mode="755",
    user=user,
    _sudo=use_sudo,
)

files.directory(
    name="Create Kopia status directory",
    path=status_dir,
    mode="700",
    user=user,
    _sudo=use_sudo,
)

files.directory(
    name="Create LaunchAgents directory",
    path=launch_agents_dir,
    mode="755",
    user=user,
    _sudo=use_sudo,
)

files.template(
    name="Install Kopia ignore rules",
    src="templates/kopiaignore.j2",
    dest=backup_ignore_file,
    mode="644",
    user=user,
    **template_context,
    _sudo=use_sudo,
)

files.directory(
    name="Create Kopia monitor app bundle directory",
    path=app_bundle_dir,
    mode="755",
    user=user,
    _sudo=use_sudo,
)

files.directory(
    name="Create Kopia monitor Contents directory",
    path=app_contents_dir,
    mode="755",
    user=user,
    _sudo=use_sudo,
)

files.directory(
    name="Create Kopia monitor MacOS directory",
    path=app_macos_dir,
    mode="755",
    user=user,
    _sudo=use_sudo,
)

files.directory(
    name="Create Kopia monitor Resources directory",
    path=app_resources_dir,
    mode="755",
    user=user,
    _sudo=use_sudo,
)

files.template(
    name="Install Kopia monitor Swift source",
    src="templates/kopia-backup-monitor.swift.j2",
    dest=app_source_path,
    mode="600",
    user=user,
    **template_context,
    _sudo=use_sudo,
)

files.template(
    name="Install Kopia monitor Info.plist",
    src="templates/kopia-backup-monitor.Info.plist.j2",
    dest=app_info_plist_path,
    mode="644",
    user=user,
    **template_context,
    _sudo=use_sudo,
)

files.template(
    name="Install Kopia monitor entitlements",
    src="templates/kopia-backup-monitor.entitlements.plist.j2",
    dest=app_entitlements_path,
    mode="600",
    user=user,
    **template_context,
    _sudo=use_sudo,
)

server.shell(
    name="Build and sign Kopia monitor app",
    commands=[
        "command -v swiftc >/dev/null 2>&1 || "
        '(echo "swiftc is required to build the Kopia monitor app." >&2; exit 1)',
        (
            f'app_hash="$(shasum -a 256 "{app_source_path}" '
            f'"{app_info_plist_path}" "{app_entitlements_path}" '
            f'| shasum -a 256 | awk \'{{print $1}}\')"; '
            f'app_hash="$(printf "%s\\n%s\\n" "$app_hash" "{app_signing_identity}" '
            f'| shasum -a 256 | awk \'{{print $1}}\')"; '
            f'current_hash="$(cat "{app_stamp_path}" 2>/dev/null || true)"; '
            f'if test -x "{app_executable_path}" && '
            f'test "$current_hash" = "$app_hash" && '
            f'codesign --verify --deep --strict "{app_bundle_dir}" >/dev/null 2>&1; then '
            f'echo "Kopia monitor app already current"; exit 0; fi; '
            f'swiftc -parse-as-library -O '
            f'-framework SwiftUI -framework AppKit -framework CoreLocation '
            f'-framework CoreWLAN -framework Network '
            f'"{app_source_path}" -o "{app_executable_path}"; '
            f'chmod 755 "{app_executable_path}"; '
            f'codesign --force --deep --options runtime --sign "{app_signing_identity}" '
            f'--entitlements "{app_entitlements_path}" '
            f'"{app_bundle_dir}" >/dev/null; '
            f'printf "%s\\n" "$app_hash" > "{app_stamp_path}"; '
            f'chmod 600 "{app_stamp_path}"; '
            f'if test "$(id -un)" != "{user}"; then '
            f'chown -R "{user}" "{app_bundle_dir}" "{app_stamp_path}"; fi'
        ),
    ],
    _sudo=use_sudo,
)

files.template(
    name="Install Kopia monitor LaunchAgent plist",
    src="templates/kopia-monitor.plist.j2",
    dest=monitor_plist_path,
    mode="644",
    user=user,
    **template_context,
    _sudo=use_sudo,
)

server.shell(
    name="Remove legacy Kopia runner LaunchAgent",
    commands=[
        f'launchctl bootout "{launchd_domain}" "{legacy_backup_plist_path}" || true',
        f'pkill -TERM -f "^{legacy_runner_path}$" || true',
        f'rm -f "{legacy_backup_plist_path}" "{legacy_runner_path}" '
        f'"{legacy_helper_source_path}" "{legacy_helper_stamp_path}"',
        f'rm -rf "{legacy_helper_bundle_dir}"',
    ],
    _sudo=use_sudo,
)

server.shell(
    name="Bootout existing Kopia monitor LaunchAgent",
    commands=[
        f'launchctl bootout "{launchd_domain}" "{monitor_plist_path}" || true',
    ],
    _sudo=use_sudo,
)

server.shell(
    name="Stop unmanaged COPYA monitor processes",
    commands=[
        f'osascript -e \'tell application id "{app_bundle_identifier}" to quit\' || true',
        "sleep 2",
        f'pkill -TERM -f "^{app_executable_path}( |$)" || true',
        f'pkill -TERM -f "^{legacy_local_app_executable_path}( |$)" || true',
        "sleep 2",
        f'pkill -KILL -f "^{app_executable_path}( |$)" || true',
        f'pkill -KILL -f "^{legacy_local_app_executable_path}( |$)" || true',
    ],
    _sudo=use_sudo,
)

server.shell(
    name="Remove renamed Kopia monitor app bundles",
    commands=[
        " ".join(
            [
                "rm -rf",
                f'"{legacy_local_app_bundle_dir}"',
                *[f'"{path}"' for path in legacy_monitor_app_bundle_dirs],
            ]
        ),
    ],
    _sudo=use_sudo,
)

server.shell(
    name="Bootstrap Kopia monitor LaunchAgent",
    commands=[
        f'launchctl bootstrap "{launchd_domain}" "{monitor_plist_path}"',
    ],
    _sudo=use_sudo,
)

server.shell(
    name="Enable Kopia monitor LaunchAgent",
    commands=[
        f'launchctl enable "{monitor_launchd_service}"',
    ],
    _sudo=use_sudo,
)

server.shell(
    name="Kickstart Kopia monitor LaunchAgent",
    commands=[
        f'launchctl kickstart -k "{monitor_launchd_service}"',
    ],
    _sudo=use_sudo,
)
