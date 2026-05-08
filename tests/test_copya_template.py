import subprocess
import tempfile
import unittest
from pathlib import Path

from jinja2 import Environment, FileSystemLoader

from group_data import all as data


ROOT = Path(__file__).resolve().parents[1]


def render_monitor_source() -> str:
    env = Environment(
        loader=FileSystemLoader(str(ROOT / "templates")),
        keep_trailing_newline=True,
    )
    template = env.get_template("kopia-backup-monitor.swift.j2")
    context = {
        name: getattr(data, name)
        for name in dir(data)
        if not name.startswith("_")
    }
    context.update(
        {
            "app_executable_path": (
                f"{data.app_install_dir}/{data.app_name}.app/Contents/MacOS/"
                f"{data.app_executable_name}"
            ),
            "config_user": data.user,
        }
    )
    return template.render(**context)


class CopyaTemplateTest(unittest.TestCase):
    def test_rendered_swift_typechecks(self) -> None:
        source = render_monitor_source()
        with tempfile.TemporaryDirectory() as tmpdir:
            source_path = Path(tmpdir) / "COPYA.swift"
            binary_path = Path(tmpdir) / "COPYA"
            source_path.write_text(source)
            subprocess.run(
                [
                    "swiftc",
                    "-parse-as-library",
                    "-O",
                    "-framework",
                    "SwiftUI",
                    "-framework",
                    "AppKit",
                    "-framework",
                    "CoreLocation",
                    "-framework",
                    "CoreWLAN",
                    "-framework",
                    "Network",
                    str(source_path),
                    "-o",
                    str(binary_path),
                ],
                check=True,
            )

    def test_active_run_and_process_safety_are_rendered(self) -> None:
        source = render_monitor_source()

        self.assertIn(data.active_run_file, source)
        self.assertIn("scanKopiaSnapshots()", source)
        self.assertIn('"/usr/bin/pgrep"', source)
        self.assertIn("Unable to inspect running Kopia processes before launch", source)
        self.assertIn("createActiveRunRecord", source)
        self.assertIn("case external_kopia_pids", source)
        self.assertIn("forceTerminateCapturedExternalPIDsAfterGracePeriod", source)
        self.assertIn("COPYA_RUN_ID", source)

    def test_deploy_does_not_kill_external_kopia_snapshot(self) -> None:
        deploy = (ROOT / "deploy.py").read_text()

        self.assertNotIn(
            'pkill -TERM -f "^kopia snapshot create --no-progress',
            deploy,
        )


if __name__ == "__main__":
    unittest.main()
