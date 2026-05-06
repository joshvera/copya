from pyinfra import host
from pyinfra.operations import brew, files, server

from group_data import all as defaults


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
deny_ssids = data("deny_ssids")
launchd_label = data("launchd_label")
run_interval_seconds = data("run_interval_seconds")
network_check_interval_seconds = data("network_check_interval_seconds")
runner_dir = data("runner_dir")
env_file = data("env_file")
log_file = data("log_file")
ssid_helper_name = data("ssid_helper_name")
ssid_helper_bundle_name = data("ssid_helper_bundle_name")
ssid_helper_bundle_identifier = data("ssid_helper_bundle_identifier")
onepassword_cli_package = data("onepassword_cli_package")
kopia_password_ref = data("kopia_password_ref")
use_sudo = bool_data("use_sudo")

runner_path = f"{runner_dir}/kopia-safe-run.sh"
plist_path = f"{home}/Library/LaunchAgents/{launchd_label}.plist"
launch_agents_dir = f"{home}/Library/LaunchAgents"
env_dir = env_file.rsplit("/", 1)[0]
log_dir = log_file.rsplit("/", 1)[0]
ssid_helper_bundle_dir = f"{runner_dir}/{ssid_helper_bundle_name}.app"
ssid_helper_contents_dir = f"{ssid_helper_bundle_dir}/Contents"
ssid_helper_macos_dir = f"{ssid_helper_contents_dir}/MacOS"
ssid_helper_path = f"{ssid_helper_macos_dir}/{ssid_helper_name}"
ssid_helper_source_path = f"{runner_dir}/{ssid_helper_name}.swift"
ssid_helper_plist_path = f"{ssid_helper_contents_dir}/Info.plist"
ssid_helper_entitlements_path = f"{ssid_helper_contents_dir}/entitlements.plist"
ssid_helper_stamp_path = f"{runner_dir}/{ssid_helper_name}.sha256"

uid_command = f"id -u {user}"
launchd_domain = f"gui/$({uid_command})"
launchd_service = f"{launchd_domain}/{launchd_label}"

template_context = {
    "backup_source": backup_source,
    "deny_ssids": deny_ssids,
    "env_file": env_file,
    "launchd_label": launchd_label,
    "log_file": log_file,
    "kopia_password_ref": kopia_password_ref,
    "network_check_interval_seconds": network_check_interval_seconds,
    "run_interval_seconds": run_interval_seconds,
    "runner_path": runner_path,
    "ssid_helper_path": ssid_helper_path,
}


server.shell(
    name="Validate configured macOS user and home",
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
    ],
)

brew.packages(
    name="Install Kopia and 1Password CLI",
    packages=["kopia", onepassword_cli_package],
)

files.directory(
    name="Create Kopia runner directory",
    path=runner_dir,
    mode="700",
    user=user,
    _sudo=use_sudo,
)

files.directory(
    name="Create Kopia env directory",
    path=env_dir,
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
    name="Create LaunchAgents directory",
    path=launch_agents_dir,
    mode="755",
    user=user,
    _sudo=use_sudo,
)

files.directory(
    name="Create Kopia SSID helper bundle directory",
    path=ssid_helper_bundle_dir,
    mode="700",
    user=user,
    _sudo=use_sudo,
)

files.directory(
    name="Create Kopia SSID helper Contents directory",
    path=ssid_helper_contents_dir,
    mode="700",
    user=user,
    _sudo=use_sudo,
)

files.directory(
    name="Create Kopia SSID helper MacOS directory",
    path=ssid_helper_macos_dir,
    mode="700",
    user=user,
    _sudo=use_sudo,
)

files.template(
    name="Install Kopia SSID helper source",
    src="templates/kopia-wifi-ssid.swift.j2",
    dest=ssid_helper_source_path,
    mode="600",
    user=user,
    _sudo=use_sudo,
)

files.template(
    name="Install Kopia SSID helper Info.plist",
    src="templates/kopia-wifi-ssid.Info.plist.j2",
    dest=ssid_helper_plist_path,
    mode="600",
    user=user,
    ssid_helper_bundle_identifier=ssid_helper_bundle_identifier,
    ssid_helper_bundle_name=ssid_helper_bundle_name,
    ssid_helper_name=ssid_helper_name,
    _sudo=use_sudo,
)

files.template(
    name="Install Kopia SSID helper entitlements",
    src="templates/kopia-wifi-ssid.entitlements.plist.j2",
    dest=ssid_helper_entitlements_path,
    mode="600",
    user=user,
    _sudo=use_sudo,
)

server.shell(
    name="Build Kopia SSID helper",
    commands=[
        "command -v swiftc >/dev/null 2>&1 || "
        '(echo "swiftc is required to build the Kopia SSID helper." >&2; exit 1)',
        (
            f'helper_hash="$(shasum -a 256 "{ssid_helper_source_path}" '
            f'"{ssid_helper_plist_path}" "{ssid_helper_entitlements_path}" '
            f'| shasum -a 256 | awk \'{{print $1}}\')"; '
            f'current_hash="$(cat "{ssid_helper_stamp_path}" 2>/dev/null || true)"; '
            f'if test -x "{ssid_helper_path}" && '
            f'test "$current_hash" = "$helper_hash"; then '
            f'echo "Kopia SSID helper already current"; exit 0; fi; '
            f'swiftc -O -framework AppKit -framework CoreWLAN -framework CoreLocation '
            f'"{ssid_helper_source_path}" -o "{ssid_helper_path}"; '
            f'chmod 700 "{ssid_helper_path}"; '
            f'codesign --force --deep --sign - '
            f'--entitlements "{ssid_helper_entitlements_path}" '
            f'"{ssid_helper_bundle_dir}" >/dev/null; '
            f'printf "%s\\n" "$helper_hash" > "{ssid_helper_stamp_path}"; '
            f'chmod 600 "{ssid_helper_stamp_path}"; '
            f'if test "$(id -un)" != "{user}"; then '
            f'chown "{user}" "{ssid_helper_path}" "{ssid_helper_stamp_path}"; fi'
        ),
    ],
    _sudo=use_sudo,
)

files.template(
    name="Install Kopia network-gated runner",
    src="templates/kopia-safe-run.sh.j2",
    dest=runner_path,
    mode="700",
    user=user,
    backup_source=backup_source,
    deny_ssids=deny_ssids,
    env_file=env_file,
    kopia_password_ref=kopia_password_ref,
    log_file=log_file,
    network_check_interval_seconds=network_check_interval_seconds,
    ssid_helper_path=ssid_helper_path,
    _sudo=use_sudo,
)

files.template(
    name="Install Kopia LaunchAgent plist",
    src="templates/kopia-backup.plist.j2",
    dest=plist_path,
    mode="644",
    user=user,
    **template_context,
    _sudo=use_sudo,
)

server.shell(
    name="Bootout existing Kopia LaunchAgent",
    commands=[
        f'launchctl bootout "{launchd_domain}" "{plist_path}" || true',
    ],
    _sudo=use_sudo,
)

server.shell(
    name="Bootstrap Kopia LaunchAgent",
    commands=[
        f'launchctl bootstrap "{launchd_domain}" "{plist_path}"',
    ],
    _sudo=use_sudo,
)

server.shell(
    name="Enable Kopia LaunchAgent",
    commands=[
        f'launchctl enable "{launchd_service}"',
    ],
    _sudo=use_sudo,
)

server.shell(
    name="Kickstart Kopia LaunchAgent",
    commands=[
        f'launchctl kickstart -k "{launchd_service}"',
    ],
    _sudo=use_sudo,
)
