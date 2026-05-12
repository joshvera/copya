import fnmatch
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

from jinja2 import Environment, FileSystemLoader

from group_data import example as data


ROOT = Path(__file__).resolve().parents[1]


def render_monitor_source(overrides=None) -> str:
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
    if overrides:
        context.update(overrides)
    return template.render(**context)


def compile_monitor_binary(source: str, tmpdir: str) -> Path:
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
    return binary_path


def render_kopiaignore(patterns=None, tolerated_patterns=None) -> str:
    env = Environment(
        loader=FileSystemLoader(str(ROOT / "templates")),
        keep_trailing_newline=True,
    )
    template = env.get_template("kopiaignore.j2")
    return template.render(
        backup_source=data.backup_source,
        backup_ignore_patterns=patterns if patterns is not None else data.backup_ignore_patterns,
        backup_tolerated_ephemeral_ignore_patterns=(
            tolerated_patterns
            if tolerated_patterns is not None
            else data.backup_tolerated_ephemeral_ignore_patterns
        ),
    )


def pattern_matches(pattern: str, path: str) -> bool:
    return fnmatch.fnmatchcase(path.lstrip("/"), pattern.lstrip("/"))


class CopyaTemplateTest(unittest.TestCase):
    def test_rendered_swift_typechecks(self) -> None:
        source = render_monitor_source()
        with tempfile.TemporaryDirectory() as tmpdir:
            compile_monitor_binary(source, tmpdir)

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

    def test_public_example_config_is_generic(self) -> None:
        tracked_public_text = "\n".join(
            path.read_text(errors="ignore")
            for path in [
                ROOT / "group_data" / "example.py",
                ROOT / "README.md",
                ROOT / "CONTRIBUTING.md",
                ROOT / "SECURITY.md",
            ]
        )

        for forbidden in [
            "/Users/" + "vera",
            "Joshua " + "Vera",
            "HBBYK" + "PXNDM",
            "com." + "vera",
            "op://" + "Private",
            "Free" + "side",
            "cer" + "ise",
        ]:
            self.assertNotIn(forbidden, tracked_public_text)

        self.assertEqual(data.password_source, "environment")
        self.assertEqual(data.kopia_password_ref, "")
        self.assertEqual(data.app_signing_identity, "-")

    def test_secret_unavailable_state_and_password_sources_are_rendered(self) -> None:
        source = render_monitor_source(
            {
                "password_source": "command",
                "password_env_var": "COPYA_TEST_PASSWORD",
                "password_command": ["/usr/bin/security", "find-generic-password"],
                "password_read_timeout_seconds": 12,
            }
        )

        self.assertIn('static let passwordSource = "command"', source)
        self.assertIn('static let passwordEnvVar = "COPYA_TEST_PASSWORD"', source)
        self.assertIn('"/usr/bin/security"', source)
        self.assertIn("static let passwordReadTimeoutSeconds = 12", source)
        self.assertIn('case needsSecret = "needs_secret"', source)
        self.assertIn("recordSecretUnavailable", source)
        self.assertIn('"secret_unavailable"', source)
        self.assertIn("Needs 1Password Unlock", source)
        self.assertIn("Secret Unavailable", source)
        self.assertIn("password_command failed", source)
        self.assertIn('detail: "exit status \\(result.status)"', source)
        self.assertIn('detail: "process launch failed"', source)
        self.assertIn("Configured password source returned an empty Kopia password", source)
        self.assertIn('Config.passwordSource == "onepassword" && !Config.kopiaPasswordRef.isEmpty', source)
        command_branch = source.split('case "command":', 1)[1].split("default:", 1)[0]
        self.assertNotIn("sanitizedCommandError(result.stderr)", command_branch)

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

    def test_dataless_directories_are_placeholders_not_read_failures(self) -> None:
        source = render_monitor_source()
        materialize_root = source.split("private func materializeRoot", 1)[1].split(
            "private func publishCloudMaterializationProgress", 1
        )[0]
        enumerator_loop = materialize_root.split("for case let url as URL in enumerator", 1)[1]

        self.assertIn("CloudPlaceholderRecord", source)
        self.assertIn("CloudPlaceholderClassifier.record", materialize_root)
        self.assertIn(".isPackageKey", materialize_root)
        self.assertIn("enumerator.skipDescendants()", materialize_root)
        self.assertIn("download_request_failures", source)
        self.assertIn("placeholder_resolution_failures", source)
        self.assertIn("dataless_kind_counts", source)
        self.assertIn("firstCloudMaterializationSample", source)
        self.assertNotIn("datalessPaths", source)
        self.assertLess(
            enumerator_loop.index("CloudPlaceholderClassifier.record("),
            enumerator_loop.index("if values.isDirectory == true"),
        )
        self.assertLess(
            enumerator_loop.index("CloudPlaceholderClassifier.record("),
            enumerator_loop.index("let handle = try FileHandle"),
        )

    def test_placeholder_rescan_does_not_filehandle_package_directories(self) -> None:
        source = render_monitor_source()
        materialize_root = source.split("private func materializeRoot", 1)[1].split(
            "private func publishCloudMaterializationProgress", 1
        )[0]
        rescan = materialize_root.split("for path in datalessRecords.keys.sorted()", 1)[1]

        self.assertIn("let resolvedKind = CloudPlaceholderClassifier.kind(values: values, url: url)", rescan)
        self.assertIn("if resolvedKind == .file", rescan)
        self.assertIn("markPlaceholderResolved(path)", rescan)
        self.assertLess(
            rescan.index("if resolvedKind == .file"),
            rescan.index("let handle = try FileHandle"),
        )
        self.assertIn(
            "} else {\n                        markPlaceholderResolved(path)\n                    }",
            rescan,
        )

    def test_cloud_capacity_estimate_counts_non_regular_dataless_placeholders(self) -> None:
        source = render_monitor_source()
        estimate_root = source.split("private static func estimateRoot", 1)[1].split(
            "private static func logicalSize", 1
        )[0]

        self.assertIn(".isPackageKey", estimate_root)
        self.assertIn("CloudPlaceholderClassifier.record", estimate_root)
        self.assertIn("recordPlaceholder(placeholder", estimate_root)
        self.assertIn("enumerator.skipDescendants()", estimate_root)
        self.assertNotIn("values?.isRegularFile == false", estimate_root)

    def test_kopia_exit_classification_covers_known_fatal_errors(self) -> None:
        source = render_monitor_source()

        self.assertIn("KopiaFailureClassifier", source)
        self.assertIn("KopiaOutputObservation", source)
        self.assertIn("KopiaRunLogReplayer", source)
        self.assertIn("KopiaFileIssueClassifier", source)
        self.assertIn("partial_action_required", source)
        self.assertIn("partial_tolerated", source)
        self.assertIn("no space left on device", source)
        self.assertIn("disk_space_exhausted", source)
        self.assertIn("storage_cap_exceeded", source)
        self.assertIn("b2_storage_cap_exceeded", source)
        self.assertIn("file_read_failure", source)
        self.assertIn("observedKopiaFailure ?? KopiaFailureClassifier.generic", source)
        self.assertNotIn('recordFailure("Kopia exited with status \\(status)")', source)

    def test_partial_snapshot_result_is_run_bounded_and_status_backfilled(self) -> None:
        source = render_monitor_source()

        self.assertIn("last_snapshot_id", source)
        self.assertIn("last_snapshot_result", source)
        self.assertIn("last_snapshot_action_required_count", source)
        self.assertIn("kopia backup starting", source)
        self.assertIn("kopia backup exit observed status=", source)
        self.assertIn("Created snapshot with root ", source)
        self.assertIn("Found ", source)
        self.assertIn("reconcileFailedSnapshotFromLogIfNeeded", source)
        self.assertIn("readActiveRunRecord() == nil", source)
        self.assertIn("--classify-last-kopia-errors", source)
        self.assertIn("--classify-kopia-log", source)
        self.assertIn("Config.rawKopiaLogFile", source)

    def test_partial_snapshot_does_not_move_clean_success_or_restart_immediately(self) -> None:
        source = render_monitor_source()
        handle_exit = source.split("private func handleBackupExit", 1)[1].split(
            "private func handleRecoveredBackupExit", 1
        )[0]

        self.assertIn("lastSuccessAt = now", handle_exit)
        self.assertIn("parsedRun.snapshot_result == KopiaSnapshotResult.partialActionRequired", handle_exit)
        self.assertIn("recordSnapshotResult(parsedRun", handle_exit)
        self.assertIn("lastFailureAt = nil", source.split("private func recordSnapshotResult", 1)[1])
        self.assertIn("lastSuccessAt == nil && lastSnapshotAt == nil", source)
        self.assertIn("case backupPartial = \"backup_partial\"", source)
        self.assertIn("Backup Partial, Needs Attention", source)

    def test_live_kopia_observation_is_initialized_before_pipe_handler(self) -> None:
        source = render_monitor_source()
        launch = source.split("private func startKopiaLaunch", 1)[1].split(
            "private func runProtectedDataProbes", 1
        )[0]

        self.assertLess(
            launch.index("self.kopiaOutputObservation = KopiaOutputObservation()"),
            launch.index("pipe.fileHandleForReading.readabilityHandler"),
        )
        self.assertLess(
            launch.index("pipe.fileHandleForReading.readabilityHandler"),
            launch.index("try process.run()"),
        )
        post_launch_publish = launch.split("self.writeActiveRunRecord(activeRecord)", 1)[1]
        self.assertNotIn("self.kopiaOutputObservation = KopiaOutputObservation()", post_launch_publish)
        self.assertNotIn("self.observedKopiaFailure = nil", post_launch_publish)

    def test_raw_kopia_replay_preserves_suppressed_cloud_placeholder_classification(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            raw_log_path = Path(tmpdir) / "kopia-raw.log"
            source = render_monitor_source({"raw_kopia_log_file": str(raw_log_path)})
            binary_path = compile_monitor_binary(source, tmpdir)
            raw_log_path.write_text(
                "\n".join(
                    [
                        "2026-05-10T13:00:00-0300 raw kopia output starting run_id=RUN1 pid=123",
                        "Snapshotting example@mac:/Users/example ...",
                        (
                            'Error when processing "Library/Mobile Documents/iCloud~com~apple~clips/'
                            'Documents/example.clipsproject": fdopendir /Users/example/Library/Mobile '
                            "Documents/iCloud~com~apple~clips/Documents/example.clipsproject: "
                            "resource deadlock avoided"
                        ),
                        "Created snapshot with root root123 and ID snap123 in 1s",
                        "Found 1 fatal error(s) while snapshotting example@mac:/Users/example.",
                        "2026-05-10T13:00:02-0300 raw kopia output finished status=1",
                        "",
                    ]
                )
            )

            result = subprocess.run(
                [str(binary_path), "--classify-last-kopia-errors"],
                check=True,
                capture_output=True,
                text=True,
            )
            parsed = json.loads(result.stdout)

        self.assertEqual(parsed["snapshot_id"], "snap123")
        self.assertEqual(parsed["snapshot_result"], "partial_tolerated")
        self.assertEqual(parsed["fatal_error_count"], 1)
        self.assertEqual(parsed["tolerated_count"], 1)
        self.assertEqual(parsed["action_required_count"], 0)
        self.assertEqual(parsed["unclassified_count"], 0)
        self.assertEqual(parsed["categorized_counts"], {"cloud_placeholder": 1})

    def test_raw_kopia_replay_keeps_output_that_precedes_late_start_marker(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            raw_log_path = Path(tmpdir) / "kopia-raw.log"
            source = render_monitor_source({"raw_kopia_log_file": str(raw_log_path)})
            binary_path = compile_monitor_binary(source, tmpdir)
            raw_log_path.write_text(
                "\n".join(
                    [
                        (
                            'Error when processing "Library/Mobile Documents/iCloud~com~apple~clips/'
                            'Documents/early.clipsproject": fdopendir /Users/example/Library/Mobile '
                            "Documents/iCloud~com~apple~clips/Documents/early.clipsproject: "
                            "resource deadlock avoided"
                        ),
                        "2026-05-10T13:00:00-0300 raw kopia output starting run_id=RUN-LATE pid=789",
                        "Created snapshot with root root789 and ID snap789 in 1s",
                        "Found 1 fatal error(s) while snapshotting example@mac:/Users/example.",
                        "2026-05-10T13:00:02-0300 raw kopia output finished status=1",
                        "",
                    ]
                )
            )

            result = subprocess.run(
                [str(binary_path), "--classify-last-kopia-errors"],
                check=True,
                capture_output=True,
                text=True,
            )
            parsed = json.loads(result.stdout)

        self.assertEqual(parsed["snapshot_id"], "snap789")
        self.assertEqual(parsed["snapshot_result"], "partial_tolerated")
        self.assertEqual(parsed["tolerated_count"], 1)
        self.assertEqual(parsed["action_required_count"], 0)
        self.assertEqual(parsed["unclassified_count"], 0)

    def test_raw_kopia_replay_classifies_actionable_and_tolerated_errors(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            raw_log_path = Path(tmpdir) / "fixture.log"
            source = render_monitor_source()
            binary_path = compile_monitor_binary(source, tmpdir)
            raw_log_path.write_text(
                "\n".join(
                    [
                        "2026-05-10T13:00:00-0300 raw kopia output starting run_id=RUN2 pid=456",
                        (
                            'Error when processing "Library/Mobile Documents/com~apple~CloudDocs/'
                            'NOTARY DOCS/file.jpeg": unable to open file: unable to open local file: '
                            "open /Users/example/Library/Mobile Documents/com~apple~CloudDocs/NOTARY "
                            "DOCS/file.jpeg: operation not permitted"
                        ),
                        (
                            'Error when processing "Library/Metadata/CoreSpotlight/example.journal": '
                            "unable to open file: unable to open local file: open "
                            "/Users/example/Library/Metadata/CoreSpotlight/example.journal: "
                            "operation not permitted"
                        ),
                        "Created snapshot with root root456 and ID snap456 in 3s",
                        "Found 2 fatal error(s) while snapshotting example@mac:/Users/example.",
                        "2026-05-10T13:00:03-0300 raw kopia output finished status=1",
                        "",
                    ]
                )
            )

            result = subprocess.run(
                [str(binary_path), "--classify-kopia-log", str(raw_log_path)],
                check=True,
                capture_output=True,
                text=True,
            )
            parsed = json.loads(result.stdout)

        self.assertEqual(parsed["snapshot_result"], "partial_action_required")
        self.assertEqual(parsed["fatal_error_count"], 2)
        self.assertEqual(parsed["tolerated_count"], 1)
        self.assertEqual(parsed["action_required_count"], 1)
        self.assertEqual(parsed["unclassified_count"], 0)
        self.assertEqual(
            parsed["categorized_counts"],
            {
                "actionable_user_data": 1,
                "tolerated_system_ephemeral": 1,
            },
        )

    def test_nonzero_exit_without_file_error_evidence_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            raw_log_path = Path(tmpdir) / "fixture.log"
            source = render_monitor_source()
            binary_path = compile_monitor_binary(source, tmpdir)
            raw_log_path.write_text(
                "\n".join(
                    [
                        "2026-05-10T13:00:00-0300 raw kopia output starting run_id=RUN3 pid=111",
                        "Created snapshot with root root111 and ID snap111 in 1s",
                        "2026-05-10T13:00:01-0300 raw kopia output finished status=1",
                        "",
                    ]
                )
            )

            result = subprocess.run(
                [str(binary_path), "--classify-kopia-log", str(raw_log_path)],
                check=True,
                capture_output=True,
                text=True,
            )
            parsed = json.loads(result.stdout)

        self.assertEqual(parsed["snapshot_id"], "snap111")
        self.assertEqual(parsed["snapshot_result"], "partial_action_required")
        self.assertEqual(parsed["fatal_error_count"], 0)
        self.assertEqual(parsed["tolerated_count"], 0)
        self.assertEqual(parsed["action_required_count"], 1)
        self.assertEqual(parsed["unclassified_count"], 1)
        self.assertEqual(parsed["categorized_counts"], {"unclassified": 1})

    def test_file_issue_classifier_fails_closed_and_keeps_user_data_actionable(self) -> None:
        source = render_monitor_source()

        self.assertIn("KopiaIssueCategory.cloudPlaceholder", source)
        self.assertIn("KopiaIssueCategory.toleratedSystemEphemeral", source)
        self.assertIn("KopiaIssueCategory.actionableUserData", source)
        self.assertIn("KopiaIssueCategory.unclassified", source)
        self.assertIn("resource deadlock avoided", source)
        self.assertIn("Library/Containers/net.whatsapp.WhatsApp/", source)
        self.assertIn("Library/Mobile Documents/", source)
        self.assertIn("unparsedFatalCount", source)
        self.assertIn("actionRequiredCount > 0", source)

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
        self.assertTrue(data.backup_tolerated_ephemeral_ignore_patterns)

    def test_tolerated_ephemeral_ignores_are_narrow(self) -> None:
        patterns = [
            entry["pattern"]
            for entry in data.backup_tolerated_ephemeral_ignore_patterns
        ]

        positive_paths = [
            "/Library/Metadata/CoreSpotlight/SpotlightKnowledge/index.V2/example.journal",
            "/Library/Application Support/FileProvider/ABC/wharf/tombstone/a",
            "/Library/DuetExpertCenter/ATXAppPredictionMicroLocation",
            "/Library/Group Containers/group.com.apple.CoreSpeech/Caches/foo.bnnsir",
            "/Library/Containers/com.example.App/Data/Library/Saved Application State/foo.savedState/data.data",
            "/Library/Daemon Containers/ABC/Data/com.apple.milod/milo.db-wal",
            "/Library/Group Containers/group.com.apple.secure-control-center-preferences/Library/Preferences/example.plist",
            "/Library/Containers/com.apple.Maps/Data/Library/Maps/ReportAProblem/example",
        ]
        negative_paths = [
            "/Library/Mobile Documents/com~apple~CloudDocs/NOTARY DOCS/file.jpeg",
            "/Desktop/Screenshot.png",
            "/Documents/report.pdf",
            "/Downloads/archive.zip",
            "/Library/Containers/net.whatsapp.WhatsApp/Data/Library/rc1.dat",
            "/Library/Mail/V10/MailData/Envelope Index",
            "/Library/Messages/chat.db",
            "/Library/Safari/Bookmarks.plist",
            "/Pictures/Photos Library.photoslibrary/database/Photos.sqlite",
            "/Library/Application Support/FileProvider/ABC/user-file.txt",
            "/Library/Containers/com.example.App/Data/Documents/user-file.db",
        ]

        for path in positive_paths:
            self.assertTrue(
                any(pattern_matches(pattern, path) for pattern in patterns),
                path,
            )

        for path in negative_paths:
            self.assertFalse(
                any(pattern_matches(pattern, path) for pattern in patterns),
                path,
            )

    def test_kopiaignore_renders_tolerated_and_user_patterns_separately(self) -> None:
        rendered = render_kopiaignore(patterns=["/tmp-user-choice"])

        self.assertIn("# Managed by pyinfra from group_data/all.py.", rendered)
        self.assertIn("/Library/Metadata/CoreSpotlight/*", rendered)
        self.assertIn("/tmp-user-choice", rendered)
        self.assertLess(
            rendered.index("/Library/Metadata/CoreSpotlight/*"),
            rendered.index("/tmp-user-choice"),
        )

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

    def test_restore_smoke_is_bounded_and_cleans_up(self) -> None:
        script = (ROOT / "scripts" / "restore-smoke.sh").read_text()

        self.assertIn("trap cleanup EXIT", script)
        self.assertIn('mktemp -d "$tmp_parent/copya-restore-smoke.XXXXXX"', script)
        self.assertIn('"$work_dir" == "$tmp_parent"/copya-restore-smoke.*', script)
        self.assertIn("--shallow=0", script)
        self.assertIn("--shallow-minsize=0", script)
        self.assertIn("COPYA_RESTORE_SMOKE_MAX_BYTES", script)
        self.assertNotIn("COPYA_RESTORE_SMOKE_DIR", script)
        self.assertIn("/Applications/COPYA.app/Contents/Resources/bin/kopia", script)
        self.assertIn('kopia_cmd=("$kopia_bin")', script)
        self.assertIn('kopia_home="${COPYA_KOPIA_HOME:-}"', script)
        self.assertIn('kopia_env=(KOPIA_CHECK_FOR_UPDATES=false)', script)
        self.assertIn('env "${kopia_env[@]}" "${kopia_cmd[@]}" list -l', script)
        self.assertIn('snapshot_mode="${snapshot_entry%%', script)
        self.assertIn('if [[ "$snapshot_mode" != -* ]]', script)
        self.assertIn("restore path must not contain empty, dot, or dot-dot segments", script)
        self.assertIn("restore path is too large for smoke test", script)
        self.assertIn('env "${kopia_env[@]}" \\', script)
        self.assertIn('"${kopia_cmd[@]}" snapshot restore "$snapshot_root/$restore_path" "$work_dir/target/$restore_path"', script)
        self.assertIn("live_sha256=", script)
        self.assertIn("restored_sha256=", script)
        self.assertIn('if [[ "$live_hash" != "$restored_hash" ]]', script)
        self.assertIn("snapshot_id=", script)
        self.assertIn("snapshot_root=", script)
        self.assertIn("restore_path=", script)
        self.assertIn("snapshot_size=", script)
        self.assertIn("restore path must be a specific file", script)

    def test_deploy_passes_disk_health_config_to_templates(self) -> None:
        deploy = (ROOT / "deploy.py").read_text()

        for name in [
            "kopia_activity_heartbeat_interval_seconds",
            "kopia_internal_log_retention_bytes",
            "minimum_execution_reserve_bytes",
            "critical_runtime_free_space_bytes",
            "unknown_icloud_placeholder_estimate_bytes",
            "disk_free_space_check_paths",
            "backup_tolerated_ephemeral_ignore_patterns",
            "password_source",
            "password_env_var",
            "password_command",
            "password_read_timeout_seconds",
        ]:
            self.assertIn(f'{name} = data("{name}")', deploy)
            self.assertIn(f'"{name}": {name}', deploy)


if __name__ == "__main__":
    unittest.main()
