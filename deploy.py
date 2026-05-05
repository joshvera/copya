from pyinfra import host
from pyinfra.operations import brew, files, server

from group_data import all as defaults


def data(name):
    return host.data.get(name, getattr(defaults, name))


user = data("user")
home = data("home")
backup_source = data("backup_source")
deny_ssids = data("deny_ssids")
launchd_label = data("launchd_label")
run_interval_seconds = data("run_interval_seconds")
runner_dir = data("runner_dir")
env_file = data("env_file")
log_file = data("log_file")
onepassword_cli_package = data("onepassword_cli_package")
kopia_password_ref = data("kopia_password_ref")

runner_path = f"{runner_dir}/kopia-safe-run.sh"
plist_path = f"{home}/Library/LaunchAgents/{launchd_label}.plist"
launch_agents_dir = f"{home}/Library/LaunchAgents"
env_dir = env_file.rsplit("/", 1)[0]
log_dir = log_file.rsplit("/", 1)[0]

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
    "run_interval_seconds": run_interval_seconds,
    "runner_path": runner_path,
}


brew.packages(
    name="Install Kopia and 1Password CLI",
    packages=["kopia", onepassword_cli_package],
)

files.directory(
    name="Create Kopia runner directory",
    path=runner_dir,
    mode="700",
    user=user,
)

files.directory(
    name="Create Kopia env directory",
    path=env_dir,
    mode="700",
    user=user,
)

files.directory(
    name="Create Kopia log directory",
    path=log_dir,
    mode="755",
    user=user,
)

files.directory(
    name="Create LaunchAgents directory",
    path=launch_agents_dir,
    mode="755",
    user=user,
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
)

files.template(
    name="Install Kopia LaunchAgent plist",
    src="templates/com.josh.kopia.backup.plist.j2",
    dest=plist_path,
    mode="644",
    user=user,
    **template_context,
)

server.shell(
    name="Bootout existing Kopia LaunchAgent",
    commands=[
        f'launchctl bootout "{launchd_domain}" "{plist_path}" || true',
    ],
)

server.shell(
    name="Bootstrap Kopia LaunchAgent",
    commands=[
        f'launchctl bootstrap "{launchd_domain}" "{plist_path}"',
    ],
)

server.shell(
    name="Enable Kopia LaunchAgent",
    commands=[
        f'launchctl enable "{launchd_service}"',
    ],
)

server.shell(
    name="Kickstart Kopia LaunchAgent",
    commands=[
        f'launchctl kickstart -k "{launchd_service}"',
    ],
)
