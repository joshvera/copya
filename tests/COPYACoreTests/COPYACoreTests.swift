import XCTest
@testable import COPYACore

final class COPYACoreTests: XCTestCase {
    struct TestConfig: Codable, Equatable {
        var source: String
        var interval: Int
    }

    func testRuntimeConfigStoreWritesAtomicallyAndReloads() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("copya-config-store-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let path = root.appendingPathComponent("config.json").path
        let store = RuntimeConfigStore(
            path: path,
            defaults: TestConfig(source: "/Users/example", interval: 21600)
        )

        XCTAssertEqual(try store.load(), TestConfig(source: "/Users/example", interval: 21600))

        try store.save(TestConfig(source: "/Users/example/Documents", interval: 60))

        XCTAssertTrue(store.exists)
        XCTAssertEqual(try store.load(), TestConfig(source: "/Users/example/Documents", interval: 60))
        XCTAssertFalse(FileManager.default.enumerator(atPath: root.path)?.allObjects.description.contains(".tmp") ?? true)
    }

    func testSetupGateBlocksOnlyTheMissingPieces() {
        let blocked = SetupGateResult.evaluate(
            SetupGateInput(
                configExists: false,
                sourceExists: true,
                sourceReadable: true,
                passwordAvailable: false,
                repositoryConnected: false,
                networkPolicyNeedsPermission: false,
                fullDiskAccessAcceptable: true,
                activeWorkRunning: false
            )
        )

        XCTAssertFalse(blocked.complete)
        XCTAssertEqual(blocked.blockers, [.configMissing, .passwordMissing, .repositoryNotConnected])

        let complete = SetupGateResult.evaluate(
            SetupGateInput(
                configExists: true,
                sourceExists: true,
                sourceReadable: true,
                passwordAvailable: true,
                repositoryConnected: true,
                networkPolicyNeedsPermission: false,
                fullDiskAccessAcceptable: true,
                activeWorkRunning: false
            )
        )

        XCTAssertTrue(complete.complete)
        XCTAssertEqual(complete.summary, "Setup complete")
    }

    func testBackblazeB2UsesS3ProviderAndKeepsSecretsOutOfArguments() {
        let spec = KopiaRepositoryCommand.backblazeB2S3Spec(
            request: BackblazeB2S3RepositoryRequest(
                mode: .connect,
                bucket: "copya-backups",
                endpoint: "",
                region: "us-west-004",
                prefix: "laptop",
                accessKeyID: "key-id",
                applicationKey: "app-key",
                configFile: "/tmp/kopia.config"
            ),
            baseEnvironment: ["PATH": "/usr/bin:/bin"],
            kopiaPassword: "repo-password"
        )

        XCTAssertEqual(
            spec.arguments,
            [
                "--config-file", "/tmp/kopia.config",
                "repository", "connect", "s3",
                "--bucket", "copya-backups",
                "--endpoint", "s3.us-west-004.backblazeb2.com",
                "--region", "us-west-004",
                "--prefix", "laptop",
            ]
        )
        XCTAssertFalse(spec.redactedDisplay.contains("repo-password"))
        XCTAssertFalse(spec.redactedDisplay.contains("app-key"))
        XCTAssertEqual(spec.environment["KOPIA_PASSWORD"], "repo-password")
        XCTAssertEqual(spec.environment["AWS_ACCESS_KEY_ID"], "key-id")
        XCTAssertEqual(spec.environment["AWS_SECRET_ACCESS_KEY"], "app-key")
    }

    func testPolicyAndCacheCommandBuilders() {
        XCTAssertEqual(
            KopiaRepositoryCommand.policyShowArguments(
                configFile: "/tmp/kopia.config",
                target: "/Users/example"
            ),
            ["--config-file", "/tmp/kopia.config", "policy", "show", "--json", "/Users/example"]
        )
        XCTAssertEqual(
            KopiaRepositoryCommand.policySetArguments(
                configFile: "/tmp/kopia.config",
                target: "/Users/example",
                addIgnorePatterns: ["/Library/Caches/**", "/Library/Logs/**"],
                ignoreCacheDirs: true
            ),
            [
                "--config-file", "/tmp/kopia.config",
                "policy", "set", "/Users/example",
                "--add-ignore", "/Library/Caches/**",
                "--add-ignore", "/Library/Logs/**",
                "--ignore-cache-dirs", "true",
            ]
        )
        XCTAssertEqual(
            KopiaRepositoryCommand.cacheInfoPathArguments(configFile: "/tmp/kopia.config"),
            ["--config-file", "/tmp/kopia.config", "cache", "info", "--path"]
        )
    }

    func testPolicyJsonParsingAndReconciliation() throws {
        let data = """
        {
          "files": {
            "ignore": ["/Library/Caches/**", "/Unmanaged/**"],
            "ignoreCacheDirs": false
          }
        }
        """.data(using: .utf8)!
        let policy = try JSONDecoder().decode(KopiaPolicySnapshot.self, from: data)

        let reconciliation = KopiaPolicyReconciler.reconcile(
            files: policy.files,
            managedIgnorePatterns: ["/Library/Caches/**", "/Library/Logs/**", "/Library/Logs/**"],
            userIgnorePatterns: ["/Projects/tmp/**", " ", "/Projects/tmp/**"]
        )

        XCTAssertEqual(policy.files.ignore, ["/Library/Caches/**", "/Unmanaged/**"])
        XCTAssertEqual(
            reconciliation,
            KopiaPolicyReconciliation(
                missingIgnorePatterns: ["/Library/Logs/**", "/Projects/tmp/**"],
                shouldEnableIgnoreCacheDirs: true
            )
        )
    }

    func testRepositoryStatusClassification() {
        XCTAssertEqual(
            RepositoryStatusClassifier.classify(status: 0, stdout: "{}", stderr: "", timedOut: false),
            .connected
        )
        XCTAssertEqual(
            RepositoryStatusClassifier.classify(status: 1, stdout: "", stderr: "KOPIA_PASSWORD is required", timedOut: false),
            .missingPassword
        )
        XCTAssertEqual(
            RepositoryStatusClassifier.classify(status: 1, stdout: "", stderr: "unable to open repository", timedOut: false),
            .disconnected
        )
    }

    func testWorkCoordinatorSerializesKopiaWork() {
        let coordinator = KopiaWorkCoordinator()
        let backup = coordinator.begin(.backup)
        XCTAssertNotNil(backup)
        XCTAssertNil(coordinator.begin(.repositorySetup))
        XCTAssertEqual(coordinator.activeKind, .backup)
        coordinator.finish(backup!)
        XCTAssertNotNil(coordinator.begin(.repositorySetup))
    }
}
