import json
import os
import plistlib
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class StandaloneAppTest(unittest.TestCase):
    _copya_binary = None

    @classmethod
    def copya_binary(cls) -> Path:
        if cls._copya_binary is None:
            subprocess.run(
                ["swift", "build", "--product", "COPYA"],
                cwd=ROOT,
                check=True,
            )
            bin_dir = subprocess.run(
                ["swift", "build", "--show-bin-path"],
                cwd=ROOT,
                text=True,
                capture_output=True,
                check=True,
            ).stdout.strip()
            cls._copya_binary = Path(bin_dir) / "COPYA"
        return cls._copya_binary

    def run_config_json(self, config_path: Path) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as runtime_root:
            return subprocess.run(
                [str(self.copya_binary()), "--config-json"],
                cwd=ROOT,
                env={
                    **os.environ,
                    "COPYA_CONFIG_FILE": str(config_path),
                    "COPYA_RUNTIME_ROOT": runtime_root,
                },
                text=True,
                capture_output=True,
                check=True,
            )

    def test_native_swift_source_is_not_a_jinja_template(self) -> None:
        source = (ROOT / "Sources" / "COPYA" / "COPYA.swift").read_text()
        setup_source = (ROOT / "Sources" / "COPYA" / "SetupPreferencesView.swift").read_text()
        core_sources = "\n".join(
            path.read_text()
            for path in sorted((ROOT / "Sources" / "COPYACore").glob("*.swift"))
        )

        self.assertIn('static let appName = "COPYA"', source)
        self.assertIn('static let bundleIdentifier = "com.freesidenyc.copya"', source)
        self.assertIn('static let monitorLaunchdLabel = "com.freesidenyc.copya.agent"', source)
        self.assertIn("FileManager.default.homeDirectoryForCurrentUser.path", source)
        self.assertIn('ProcessInfo.processInfo.environment["COPYA_RUNTIME_ROOT"]', source)
        self.assertIn('ProcessInfo.processInfo.environment["COPYA_CONFIG_FILE"]', source)
        self.assertIn("unable to read COPYA config", source)
        self.assertIn('environment["HOME"] = Config.kopiaHome', source)
        self.assertIn("import ServiceManagement", source)
        self.assertIn("SMAppService.agent(plistName:", source)
        self.assertIn("--bundle-path", source)
        self.assertIn("--register-login-agent", source)
        self.assertIn("Enable at Login", source)
        self.assertIn('password_source: "keychain"', source)
        self.assertIn("struct RuntimeConfig", source)
        self.assertIn("struct RuntimeConfigOverrides", source)
        self.assertIn("ephemeral_exclude_patterns", source)
        self.assertIn('legacyEphemeralExcludePatternsKey = "backup_tolerated_ephemeral_ignore_patterns"', source)
        self.assertIn('static let configFile = explicitConfigFile ?? "\\(appSupportDir)/config.json"', source)
        self.assertIn("network_policy_enabled", source)
        self.assertIn("kopia_config_file", source)
        self.assertIn("KopiaCommand.snapshotCreateArguments()", source)
        self.assertIn("--config-json", source)
        self.assertIn("--write-default-config", source)
        self.assertIn("SecItemCopyMatching", source)
        self.assertIn("--store-password-in-keychain", source)
        self.assertIn("--backup-once", source)
        self.assertIn("Setup & Preferences...", source)
        self.assertIn("setupGate.complete", source)
        self.assertIn("refreshRepositoryStatusSynchronously", source)
        self.assertIn("AWS_ACCESS_KEY_ID", core_sources)
        self.assertIn("AWS_SECRET_ACCESS_KEY", core_sources)
        self.assertIn("repository\", request.mode.rawValue, \"s3", core_sources)
        self.assertIn("SetupPreferencesWindowController", setup_source)
        self.assertIn("Store Password in Keychain", setup_source)
        self.assertIn("Backblaze B2 (Kopia S3 provider)", setup_source)
        self.assertIn("if !oneShotMode", source)
        self.assertIn("--agent", source)
        self.assertIn('ProcessInfo.processInfo.environment["COPYA_AGENT"] == "1"', source)
        self.assertIn('"/bin/launchctl"', source)
        self.assertIn('"gui/\\(getuid())/\\(Config.monitorLaunchdLabel)"', source)
        self.assertIn("startViewer()", source)
        self.assertIn("loadViewerStatus()", source)
        self.assertIn("state = BackupState(rawValue: status.state) ?? state", source)
        self.assertIn("activePID = status.active_pid", source)
        self.assertIn("livenessCheckAt = parseDate(status.last_liveness_check_at) ?? livenessCheckAt", source)
        self.assertIn("viewerBackupElapsedSeconds = status.backup_elapsed_seconds", source)
        self.assertIn("internalKopiaActivity = status.kopia_activity ?? .inactive()", source)
        self.assertIn("cloudMaterialization = status.cloud_materialization ?? .empty()", source)
        self.assertIn("if viewerOnly", source)
        self.assertIn("guard activeProcess != nil || activePID != nil else", source)
        self.assertIn("var canManageLoginAgent: Bool", source)
        self.assertIn(".disabled(!monitor.canManageLoginAgent)", source)
        self.assertIn("applyViewerStatusUnavailable()", source)
        self.assertNotIn("loadViewerStatus() {\n        guard let data = try? Data(contentsOf: URL(fileURLWithPath: Config.statusFile)),\n              let status = try? JSONDecoder().decode(StatusSnapshot.self, from: data) else {\n            loadPersistedStatus()", source)
        self.assertIn("stop ignored: external Kopia pids are not owned by COPYA", source)
        self.assertIn('".*kopia.*snapshot.*create.*"', source)
        self.assertIn("shellLikeWords", source)
        self.assertNotIn('"(.*/)?kopia snapshot create --no-progress \\(Config.backupSource)"', source)
        self.assertNotIn("let source = Config.backupSource\n        return kopiaArguments.contains(source)", source)
        self.assertNotIn("{{", source)
        self.assertNotIn("{%", source)
        self.assertNotIn("/Users/example", source)

    def test_config_json_migrates_legacy_ephemeral_exclude_key(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            config_path = Path(tmpdir) / "config.json"
            config_path.write_text(
                json.dumps(
                    {
                        "backup_source": str(Path(tmpdir) / "home"),
                        "backup_tolerated_ephemeral_ignore_patterns": ["/Legacy/*"],
                        "unknown_object": {"preserve": True},
                    }
                )
            )

            result = self.run_config_json(config_path)
            parsed = json.loads(result.stdout)
            migrated = json.loads(config_path.read_text())

        self.assertEqual(result.stderr, "")
        self.assertEqual(parsed["ephemeral_exclude_patterns"], ["/Legacy/*"])
        self.assertNotIn("backup_tolerated_ephemeral_ignore_patterns", parsed)
        self.assertEqual(migrated["ephemeral_exclude_patterns"], ["/Legacy/*"])
        self.assertNotIn("backup_tolerated_ephemeral_ignore_patterns", migrated)
        self.assertEqual(migrated["unknown_object"], {"preserve": True})

    def test_config_json_canonical_ephemeral_exclude_key_wins_migration(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            config_path = Path(tmpdir) / "config.json"
            config_path.write_text(
                json.dumps(
                    {
                        "backup_source": str(Path(tmpdir) / "home"),
                        "ephemeral_exclude_patterns": ["/New/*"],
                        "backup_tolerated_ephemeral_ignore_patterns": ["/Old/*"],
                    }
                )
            )

            result = self.run_config_json(config_path)
            parsed = json.loads(result.stdout)
            migrated = json.loads(config_path.read_text())

        self.assertEqual(result.stderr, "")
        self.assertEqual(parsed["ephemeral_exclude_patterns"], ["/New/*"])
        self.assertEqual(migrated["ephemeral_exclude_patterns"], ["/New/*"])
        self.assertNotIn("backup_tolerated_ephemeral_ignore_patterns", migrated)

    def test_config_json_migrates_empty_legacy_ephemeral_exclude_list(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            config_path = Path(tmpdir) / "config.json"
            config_path.write_text(
                json.dumps(
                    {
                        "backup_source": str(Path(tmpdir) / "home"),
                        "backup_tolerated_ephemeral_ignore_patterns": [],
                    }
                )
            )

            result = self.run_config_json(config_path)
            parsed = json.loads(result.stdout)
            migrated = json.loads(config_path.read_text())

        self.assertEqual(result.stderr, "")
        self.assertEqual(parsed["ephemeral_exclude_patterns"], [])
        self.assertEqual(migrated["ephemeral_exclude_patterns"], [])
        self.assertNotIn("backup_tolerated_ephemeral_ignore_patterns", migrated)

    def test_config_json_does_not_rewrite_symlinked_legacy_config(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            target_path = Path(tmpdir) / "target.json"
            config_path = Path(tmpdir) / "config-link.json"
            target_path.write_text(
                json.dumps(
                    {
                        "backup_source": str(Path(tmpdir) / "home"),
                        "backup_tolerated_ephemeral_ignore_patterns": ["/Linked/*"],
                    }
                )
            )
            config_path.symlink_to(target_path)

            result = self.run_config_json(config_path)
            parsed = json.loads(result.stdout)
            target = json.loads(target_path.read_text())

        self.assertIn("symlink", result.stderr)
        self.assertEqual(parsed["ephemeral_exclude_patterns"], ["/Linked/*"])
        self.assertEqual(target["backup_tolerated_ephemeral_ignore_patterns"], ["/Linked/*"])
        self.assertNotIn("ephemeral_exclude_patterns", target)

    def test_app_bundle_resources_are_valid_plists(self) -> None:
        info = plistlib.loads((ROOT / "Resources" / "Info.plist").read_bytes())
        entitlements = plistlib.loads((ROOT / "Resources" / "COPYA.entitlements").read_bytes())
        agent = plistlib.loads((ROOT / "Resources" / "com.freesidenyc.copya.agent.plist").read_bytes())

        self.assertEqual(info["CFBundleName"], "COPYA")
        self.assertEqual(info["CFBundleExecutable"], "COPYA")
        self.assertEqual(info["CFBundleIdentifier"], "com.freesidenyc.copya")
        self.assertEqual(info["CFBundleShortVersionString"], "1.1.1")
        self.assertTrue(info["LSUIElement"])
        self.assertTrue(entitlements["com.apple.security.personal-information.location"])
        self.assertEqual(agent["Label"], "com.freesidenyc.copya.agent")
        self.assertEqual(agent["BundleProgram"], "Contents/MacOS/COPYA")
        self.assertNotIn("COPYA_AGENT", agent.get("EnvironmentVariables", {}))
        self.assertTrue(agent["RunAtLoad"])

    def test_build_and_package_scripts_do_not_require_pyinfra_or_jinja(self) -> None:
        build_script = (ROOT / "scripts" / "build-app.sh").read_text()
        package_script = (ROOT / "scripts" / "package-dmg.sh").read_text()
        release_script = (ROOT / "scripts" / "release-dmg.sh").read_text()
        workflow = (ROOT / ".github" / "workflows" / "release.yml").read_text()
        pyproject = (ROOT / "pyproject.toml").read_text()
        lockfile = (ROOT / "uv.lock").read_text()

        self.assertIn("swift build", build_script)
        self.assertIn("Contents/Resources/bin/kopia", build_script)
        self.assertIn("codesign --verify --deep --strict", build_script)
        self.assertIn("hdiutil create", package_script)
        self.assertIn("size_mb", package_script)
        self.assertIn("ditto", package_script)
        self.assertIn("hdiutil convert", package_script)
        self.assertRegex(package_script, r"(?m)^detach_image\(\) \{")
        self.assertRegex(package_script, r"(?m)^image_detached\(\) \{")
        self.assertIn("hdiutil detach", package_script)
        self.assertIn("-force", package_script)
        self.assertIn("unable to detach", package_script)
        self.assertIn("$work_dir", package_script)
        self.assertNotIn("-srcfolder", package_script)
        self.assertNotIn("hdiutil detach \"$mount_dir\" -quiet >/dev/null 2>&1 || true\n  rm -rf \"$work_dir\"", package_script)
        self.assertIn("notarytool submit", release_script)
        self.assertIn("xcrun stapler staple", release_script)
        self.assertIn("spctl --assess", release_script)
        for forbidden_path in [
            "deploy.py",
            "inventory.py",
            "group_data",
            "templates",
            "tests/test_copya_template.py",
        ]:
            self.assertFalse((ROOT / forbidden_path).exists(), forbidden_path)
        for forbidden in ["pyinfra", "jinja", "group_data", "test_copya_template"]:
            self.assertNotIn(forbidden, build_script.lower())
            self.assertNotIn(forbidden, package_script.lower())
            self.assertNotIn(forbidden, release_script.lower())
            self.assertNotIn(forbidden, workflow.lower())
            self.assertNotIn(forbidden, pyproject.lower())
            self.assertNotIn(forbidden, lockfile.lower())

    def test_package_dmg_helpers_handle_disk_state_edges(self) -> None:
        result = subprocess.run(
            [
                "bash",
                "-c",
                """
source scripts/package-dmg.sh

if [[ "$(normalize_tmp_parent "/tmp/")" != "/tmp" ]]; then
  echo "expected trailing slash to be trimmed from /tmp/" >&2
  exit 1
fi

if [[ "$(normalize_tmp_parent "/")" != "/" ]]; then
  echo "expected root TMPDIR to stay root" >&2
  exit 1
fi

if ! known_device_in_info "/dev/disk99" $'/dev/disk99 Apple_HFS COPYA\\n/dev/disk1 Apple_HFS Other'; then
  echo "expected matching device to report attached" >&2
  exit 1
fi

if known_device_in_info "/dev/disk99" $'/dev/disk1 Apple_HFS COPYA'; then
  echo "expected absent device to report detached" >&2
  exit 1
fi
""",
            ],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr)

    def test_build_uses_pinned_kopia_by_default(self) -> None:
        manifest = (ROOT / "release" / "kopia.env").read_text()
        build_script = (ROOT / "scripts" / "build-app.sh").read_text()

        self.assertIn('KOPIA_VERSION="0.22.3"', manifest)
        self.assertIn('KOPIA_TAG="v0.22.3"', manifest)
        self.assertIn("kopia-0.22.3-macOS-universal.tar.gz", manifest)
        self.assertIn("github.com/kopia/kopia/releases/download/v0.22.3", manifest)
        self.assertRegex(manifest, r'KOPIA_SHA256="[0-9a-f]{64}"')

        self.assertIn("KOPIA_MANIFEST", build_script)
        self.assertIn("release/kopia.env", build_script)
        self.assertIn("KOPIA_SHA256", build_script)
        self.assertIn("shasum -a 256 -c", build_script)
        self.assertIn("curl -fL --retry 3", build_script)
        self.assertIn("COPYA_KOPIA_BIN", build_script)
        self.assertIn("COPYA_REQUIRE_PINNED_KOPIA", build_script)
        self.assertIn("Kopia-LICENSE.txt", build_script)
        self.assertIn("THIRD-PARTY-NOTICES.txt", build_script)
        self.assertIn("codesign_app()", build_script)
        self.assertIn('codesign --keychain "$COPYA_CODESIGN_KEYCHAIN" "$@"', build_script)
        self.assertIn('codesign_app --force --options runtime --sign "$SIGNING_IDENTITY" "$APP_DIR/Contents/Resources/bin/kopia"', build_script)
        self.assertIn("COPYA_CODESIGN_KEYCHAIN", build_script)

    def test_release_dmg_requires_developer_id_notarization_and_pinned_kopia(self) -> None:
        release_script = (ROOT / "scripts" / "release-dmg.sh").read_text()

        self.assertIn("Developer ID Application", release_script)
        self.assertIn("release builds must use the pinned Kopia artifact", release_script)
        self.assertIn("PINNED_KOPIA_MANIFEST", release_script)
        self.assertIn("release/kopia.env", release_script)
        self.assertIn("COPYA_KOPIA_MANIFEST", release_script)
        self.assertIn("COPYA_REQUIRE_PINNED_KOPIA=1", release_script)
        self.assertIn("COPYA_NOTARYTOOL_PROFILE", release_script)
        self.assertNotIn("COPYA_NOTARYTOOL_APPLE_ID", release_script)
        self.assertNotIn("COPYA_NOTARYTOOL_TEAM_ID", release_script)
        self.assertNotIn("COPYA_NOTARYTOOL_PASSWORD", release_script)
        self.assertIn("COPYA_NOTARYTOOL_KEY", release_script)
        self.assertIn("COPYA_NOTARYTOOL_KEY_ID", release_script)
        self.assertIn("COPYA_NOTARYTOOL_ISSUER_ID", release_script)
        self.assertIn("COPYA_CODESIGN_KEYCHAIN", release_script)
        self.assertIn('codesign "${codesign_keychain_args[@]}" --force --sign "$SIGNING_IDENTITY" "$DMG_PATH"', release_script)
        self.assertIn("notarytool submit", release_script)
        self.assertIn("stapler staple", release_script)

    def test_release_guards_reject_overrides_before_packaging(self) -> None:
        base_env = {
            **os.environ,
            "COPYA_CODESIGN_IDENTITY": "-",
        }
        guard_cases = [
            (
                {"COPYA_KOPIA_BIN": "/bin/ls"},
                "release builds must use the pinned Kopia artifact",
            ),
            (
                {"COPYA_KOPIA_MANIFEST": "/tmp/not-release.env"},
                "release builds must use the pinned Kopia manifest",
            ),
        ]

        for overrides, expected_error in guard_cases:
            with self.subTest(overrides=overrides):
                result = subprocess.run(
                    ["bash", "scripts/release-dmg.sh"],
                    cwd=ROOT,
                    env={**base_env, **overrides},
                    text=True,
                    capture_output=True,
                    check=False,
                )

                self.assertNotEqual(result.returncode, 0)
                self.assertIn(expected_error, result.stderr)
                self.assertNotIn("notarytool submit", result.stderr + result.stdout)

    def test_build_guard_rejects_kopia_override_when_pinned_is_required(self) -> None:
        result = subprocess.run(
            ["bash", "scripts/build-app.sh"],
            cwd=ROOT,
            env={
                **os.environ,
                "COPYA_CODESIGN_IDENTITY": "-",
                "COPYA_KOPIA_BIN": "/bin/ls",
                "COPYA_REQUIRE_PINNED_KOPIA": "1",
            },
            text=True,
            capture_output=True,
            check=False,
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("release builds must use pinned Kopia", result.stderr)
        self.assertNotIn("swift build", result.stderr + result.stdout)

    def test_restore_smoke_uses_standalone_app_and_bundled_kopia(self) -> None:
        restore_script = (ROOT / "scripts" / "restore-smoke.sh").read_text()

        self.assertIn("/Applications/COPYA.app/Contents/MacOS/COPYA", restore_script)
        self.assertIn("/Applications/COPYA.app/Contents/Resources/bin/kopia", restore_script)
        self.assertNotIn("kopia-backup-monitor", restore_script)
        self.assertNotIn("\nkopia ", restore_script)
        self.assertIn('kopia_cmd=("$kopia_bin")', restore_script)
        self.assertIn('kopia_cmd+=(--config-file "$kopia_config_file")', restore_script)
        self.assertIn('kopia_env=(KOPIA_CHECK_FOR_UPDATES=false)', restore_script)
        self.assertIn('env "${kopia_env[@]}" "${kopia_cmd[@]}" list -l', restore_script)
        self.assertIn('env "${kopia_env[@]}" \\', restore_script)
        self.assertIn('"${kopia_cmd[@]}" snapshot restore', restore_script)

    def test_github_release_workflow_uses_protected_notarized_dmg_smoke(self) -> None:
        workflow = (ROOT / ".github" / "workflows" / "release.yml").read_text()
        tag_gate = (ROOT / "scripts" / "release-tag-gate.sh").read_text()
        import_cert = (ROOT / "scripts" / "ci-import-codesign-cert.sh").read_text()
        release_smoke = (ROOT / "scripts" / "release-smoke.sh").read_text()

        self.assertIn("environment: copya-release", workflow)
        self.assertIn("uses: actions/checkout@v6", workflow)
        self.assertNotIn("actions/checkout@v4", workflow)
        self.assertIn("uses: astral-sh/setup-uv@", workflow)
        self.assertIn("scripts/release-tag-gate.sh", workflow)
        self.assertIn("scripts/oss-scan.sh", workflow)
        self.assertIn("uv run python -m unittest tests/test_standalone_app.py", workflow)
        self.assertNotIn("tests/test_copya_template.py", workflow)
        self.assertNotIn("group_data/example.py", workflow)
        self.assertIn("scripts/ci-import-codesign-cert.sh", workflow)
        self.assertIn("APPSTORE_CONNECT_API_KEY_P8_BASE64", workflow)
        self.assertIn("id: appstore-connect-key", workflow)
        self.assertIn("GITHUB_OUTPUT", workflow)
        self.assertNotIn("COPYA_NOTARYTOOL_KEY=%s\\n", workflow)
        self.assertIn("COPYA_NOTARYTOOL_KEY: ${{ steps.appstore-connect-key.outputs.key-path }}", workflow)
        self.assertIn("scripts/release-dmg.sh", workflow)
        self.assertIn("scripts/release-smoke.sh .build/COPYA.dmg", workflow)
        self.assertIn("gh release create", workflow)
        self.assertIn('rm -f "$RUNNER_TEMP/copya-developer-id.p12"', workflow)
        self.assertIn("git merge-base --is-ancestor", tag_gate)
        self.assertIn('^v[0-9]+\\.[0-9]+\\.[0-9]+$', tag_gate)
        self.assertIn("main:refs/remotes/origin/main", tag_gate)
        self.assertIn("APPLE_DEVELOPER_ID_CERT_P12_BASE64", import_cert)
        self.assertIn("security import", import_cert)
        self.assertIn('rm -f "$cert_path"', import_cert)
        self.assertIn("COPYA_CODESIGN_KEYCHAIN", import_cert)
        self.assertIn('install_dir="${COPYA_SMOKE_INSTALL_DIR:-"$work_dir/Applications"}"', release_smoke)
        self.assertNotIn("sudo", release_smoke)
        self.assertIn('previous_app="$work_dir/previous-COPYA.app"', release_smoke)
        self.assertIn('kopia_home="$runtime_root/home"', release_smoke)
        self.assertIn('--no-persist-credentials', release_smoke)
        self.assertIn('--no-use-keychain', release_smoke)
        self.assertIn('RUNTIME_ROOT="$runtime_root"', release_smoke)
        self.assertIn('KOPIA_HOME="$kopia_home"', release_smoke)
        self.assertIn('COPYA_KOPIA_HOME="$kopia_home"', release_smoke)
        self.assertIn('xcrun stapler validate "$dmg_path"', release_smoke)
        self.assertNotIn('xcrun stapler validate "$installed_app"', release_smoke)
        self.assertIn("KOPIA_CHECK_FOR_UPDATES=false", release_smoke)
        self.assertIn("--backup-once --timeout", release_smoke)
        self.assertIn('"network_policy_enabled": false', release_smoke)
        self.assertIn('"cloud_materialization_enabled": false', release_smoke)
        self.assertIn('"password_source": "environment"', release_smoke)
        self.assertIn('grep -R "copya-smoke-password" "$work_dir"', release_smoke)

        move_aside = release_smoke.index('mv "$installed_app" "$previous_app"')
        install_copy = release_smoke.index('cp -R "$mount_dir/COPYA.app" "$installed_app"')
        self.assertLess(move_aside, install_copy)


if __name__ == "__main__":
    unittest.main()
