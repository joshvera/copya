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

    def test_internal_kopia_activity_probe_is_scoped_to_active_pid(self) -> None:
        source = render_monitor_source()

        self.assertIn("internalKopiaActivityProbeEnabled", source)
        self.assertIn("internalKopiaLogDirs", source)
        self.assertIn("InternalKopiaActivityProbe.scan", source)
        self.assertIn('let pidNeedle = "-\\(activePID)-snapshot-create."', source)
        self.assertIn("record.child_pid == activePID", source)
        self.assertIn("activeRunID.map({ record.run_id == $0 }) ?? true", source)
        self.assertIn("used_fallback_run_start", source)
        self.assertIn("internal log activity unavailable", source)

    def test_internal_kopia_activity_parser_covers_known_log_events(self) -> None:
        source = render_monitor_source()

        self.assertIn('"PutBlob"', source)
        self.assertIn('"upload activity"', source)
        self.assertIn('"write-content-new"', source)
        self.assertIn('"content write activity"', source)
        self.assertIn('"add-to-pack"', source)
        self.assertIn('"packing content"', source)
        self.assertIn('"snapshotted directory"', source)
        self.assertIn("parseJSONObject", source)
        self.assertIn("try? JSONSerialization.jsonObject", source)

    def test_menu_uses_activity_liveness_instead_of_raw_error_counters(self) -> None:
        source = render_monitor_source()

        self.assertIn("kopiaActivityMenuText", source)
        self.assertIn("via Kopia logs", source)
        self.assertIn("stdout output", source)
        self.assertIn("no recent activity observed; process still running", source)
        self.assertIn("file read issues logged from Kopia stdout", source)
        self.assertNotIn("other errors:", source)

    def test_status_exposes_observability_without_control_coupling(self) -> None:
        source = render_monitor_source()

        self.assertIn("var kopia_activity: InternalKopiaActivitySnapshot?", source)
        self.assertIn("kopia_activity: activePID == nil ? nil : internalKopiaActivity", source)
        self.assertNotIn("internalKopiaActivity.confidence == \"unavailable\" {\n            stopBackup", source)
        self.assertNotIn("internalKopiaActivity.idle_seconds", source.split("private func stopBackup", 1)[-1])

    def test_disk_health_blocks_and_classifies_local_space_failures(self) -> None:
        source = render_monitor_source()

        self.assertEqual(data.minimum_execution_reserve_bytes, 53_687_091_200)
        self.assertEqual(data.critical_runtime_free_space_bytes, 21_474_836_480)
        self.assertEqual(data.unknown_icloud_placeholder_estimate_bytes, 268_435_456)
        self.assertEqual(data.kopia_internal_log_retention_bytes, 536_870_912)
        self.assertEqual(data.kopia_activity_heartbeat_interval_seconds, 300)
        self.assertIn("minimumExecutionReserveBytes", source)
        self.assertIn("criticalRuntimeFreeSpaceBytes", source)
        self.assertIn("diskFreeSpaceCheckPaths", source)
        self.assertIn("case needsDiskSpace = \"needs_disk_space\"", source)
        self.assertIn("DiskSpaceProbe.snapshot", source)
        self.assertIn("Insufficient local disk space to start Kopia", source)
        self.assertIn("disk space below critical threshold", source)
        self.assertIn("failureKind: \"disk_space_exhausted\"", source)
        self.assertIn("last_failure_kind", source)
        self.assertIn("disk_health", source)
        self.assertIn("activePIDOwner == \"recovered\"", source)
        self.assertIn("recordFailure(reason, kind: failureKind, detail: detail)", source)

    def test_cloud_capacity_estimate_uses_fallbacks_without_blocking_unknowns(self) -> None:
        source = render_monitor_source()

        self.assertIn("CloudCapacityEstimator", source)
        self.assertIn("unknownICloudPlaceholderEstimateBytes", source)
        self.assertIn("icloud_unknown_sizes_fallback", source)
        self.assertIn("estimate.confidence", source)
        self.assertIn("fileprovider_advisory_placeholders", source)
        self.assertIn("volumeAvailableCapacityForImportantUsageKey", source)
        self.assertIn("filesystem_fallback", source)
        self.assertIn("minimumExecutionReserveBytes", source)
        self.assertIn("statSnapshot.size > 0", source)
        self.assertIn("cloud_capacity_estimate", source)
        self.assertIn("Cloud estimate:", source)
        self.assertIn("providerClass(for: url, root: root, values: values)", source)
        self.assertIn("values?.isUbiquitousItem == true || root.contains(\"/Library/Mobile Documents\")", source)
        self.assertNotIn("unknown iCloud placeholder sizes block backup", source)

    def test_kopia_exit_classification_covers_known_fatal_errors(self) -> None:
        source = render_monitor_source()

        self.assertIn("KopiaFailureClassifier", source)
        self.assertIn("no space left on device", source)
        self.assertIn("disk_space_exhausted", source)
        self.assertIn("storage_cap_exceeded", source)
        self.assertIn("b2_storage_cap_exceeded", source)
        self.assertIn("file_read_failure", source)
        self.assertIn("observedKopiaFailure ?? KopiaFailureClassifier.generic", source)
        self.assertNotIn('recordFailure("Kopia exited with status \\(status)")', source)

    def test_internal_log_retention_preserves_live_kopia_pids(self) -> None:
        source = render_monitor_source()

        self.assertIn("kopiaInternalLogRetentionBytes", source)
        self.assertIn("KopiaDiagnosticLogPruner.prune", source)
        self.assertIn("ProcessInspector.matchingKopiaSnapshots().map(\\.pid)", source)
        self.assertIn("livePIDs.contains(pid)", source)
        self.assertIn("preserved_live_count", source)
        self.assertIn("kopia diagnostic log prune", source)

    def test_complete_backup_scope_remains_default(self) -> None:
        self.assertEqual(data.backup_ignore_patterns, [])

    def test_deploy_does_not_kill_external_kopia_snapshot(self) -> None:
        deploy = (ROOT / "deploy.py").read_text()

        self.assertNotIn(
            'pkill -TERM -f "^kopia snapshot create --no-progress',
            deploy,
        )

    def test_deploy_refuses_restart_when_backup_is_active_by_default(self) -> None:
        deploy = (ROOT / "deploy.py").read_text()

        self.assertFalse(data.allow_deploy_restart_while_backup_running)
        self.assertIn("Refuse monitor restart while COPYA backup is active", deploy)
        self.assertIn("Active matching Kopia backup detected", deploy)
        self.assertIn("allow_deploy_restart_while_backup_running=True", deploy)

    def test_deploy_passes_disk_health_config_to_templates(self) -> None:
        deploy = (ROOT / "deploy.py").read_text()

        for name in [
            "kopia_activity_heartbeat_interval_seconds",
            "kopia_internal_log_retention_bytes",
            "minimum_execution_reserve_bytes",
            "critical_runtime_free_space_bytes",
            "unknown_icloud_placeholder_estimate_bytes",
            "disk_free_space_check_paths",
        ]:
            self.assertIn(f'{name} = data("{name}")', deploy)
            self.assertIn(f'"{name}": {name}', deploy)


if __name__ == "__main__":
    unittest.main()
