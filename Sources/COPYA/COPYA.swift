import AppKit
import COPYACore
import CoreLocation
import CoreWLAN
import Darwin
import Foundation
import Network
import Security
import ServiceManagement
import SwiftUI

struct RuntimeConfig: Codable {
    var backup_source: String
    var backup_ignore_patterns: [String]
    var backup_tolerated_ephemeral_ignore_patterns: [String]
    var protected_data_probe_paths: [String]
    var cloud_materialization_roots: [String]
    var cloud_materialization_enabled: Bool
    var cloud_materialization_requires_allowed_network: Bool
    var cloud_materialization_timeout_seconds: Int
    var cloud_materialization_retry_seconds: Int
    var network_policy_enabled: Bool
    var deny_ssids: [String]
    var run_interval_seconds: Int
    var network_check_interval_seconds: Int
    var preflight_failure_retry_seconds: Int
    var password_source: String
    var password_env_var: String
    var password_command: [String]
    var password_read_timeout_seconds: Int
    var kopia_password_ref: String
    var kopia_config_file: String?
    var minimum_execution_reserve_bytes: Int64
    var critical_runtime_free_space_bytes: Int64
    var unknown_icloud_placeholder_estimate_bytes: Int64
    var limited_backup_acknowledged: Bool

    static func defaults(home: String) -> RuntimeConfig {
        RuntimeConfig(
            backup_source: home,
            backup_ignore_patterns: [],
            backup_tolerated_ephemeral_ignore_patterns: [
                "/Library/Metadata/CoreSpotlight/*",
                "/Library/Application Support/FileProvider/*/wharf/tombstone/*",
                "/Library/DuetExpertCenter/*",
                "/Library/Group Containers/group.com.apple.CoreSpeech/Caches/*",
                "/Library/Containers/*/Data/Library/Saved Application State/*",
                "/Library/Daemon Containers/*/Data/com.apple.milod/*",
                "/Library/Group Containers/group.com.apple.secure-control-center-preferences/*",
                "/Library/Containers/com.apple.Maps/Data/Library/Maps/ReportAProblem/*",
            ],
            protected_data_probe_paths: [
                "\(home)/Desktop",
                "\(home)/Documents",
                "\(home)/Library/Mobile Documents",
                "\(home)/Library/Mobile Documents/com~apple~CloudDocs",
                "\(home)/Library/Mail",
                "\(home)/Library/Messages",
                "\(home)/Library/Safari",
                "\(home)/Pictures/Photos Library.photoslibrary",
            ],
            cloud_materialization_roots: [
                "\(home)/Desktop",
                "\(home)/Documents",
                "\(home)/Library/Mobile Documents",
                "\(home)/Library/CloudStorage",
            ],
            cloud_materialization_enabled: true,
            cloud_materialization_requires_allowed_network: true,
            cloud_materialization_timeout_seconds: 3600,
            cloud_materialization_retry_seconds: 900,
            network_policy_enabled: true,
            deny_ssids: [
                "ExampleMeteredWiFi",
                "ExamplePhoneHotspot",
            ],
            run_interval_seconds: 21600,
            network_check_interval_seconds: 60,
            preflight_failure_retry_seconds: 300,
            password_source: "keychain",
            password_env_var: "KOPIA_PASSWORD",
            password_command: [],
            password_read_timeout_seconds: 60,
            kopia_password_ref: "",
            kopia_config_file: nil,
            minimum_execution_reserve_bytes: 53687091200,
            critical_runtime_free_space_bytes: 21474836480,
            unknown_icloud_placeholder_estimate_bytes: 268435456,
            limited_backup_acknowledged: false
        )
    }

    static func load(path: String, home: String, requireValid: Bool = false) -> RuntimeConfig {
        let defaults = RuntimeConfig.defaults(home: home)
        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: path))
        } catch {
            if requireValid {
                fputs("unable to read COPYA config at \(path): \(error)\n", stderr)
                exit(78)
            }
            return defaults
        }
        do {
            let overrides = try JSONDecoder().decode(RuntimeConfigOverrides.self, from: data)
            return overrides.apply(to: defaults).validated(fallback: defaults)
        } catch {
            if requireValid {
                fputs("unable to parse COPYA config at \(path): \(error)\n", stderr)
                exit(78)
            }
            return defaults
        }
    }

    func validated(fallback: RuntimeConfig) -> RuntimeConfig {
        var config = self
        if config.backup_source.isEmpty {
            config.backup_source = fallback.backup_source
        }
        if config.protected_data_probe_paths.isEmpty {
            config.protected_data_probe_paths = fallback.protected_data_probe_paths
        }
        if config.cloud_materialization_roots.isEmpty {
            config.cloud_materialization_roots = fallback.cloud_materialization_roots
        }
        if config.run_interval_seconds <= 0 {
            config.run_interval_seconds = fallback.run_interval_seconds
        }
        if config.network_check_interval_seconds <= 0 {
            config.network_check_interval_seconds = fallback.network_check_interval_seconds
        }
        if config.preflight_failure_retry_seconds <= 0 {
            config.preflight_failure_retry_seconds = fallback.preflight_failure_retry_seconds
        }
        if config.password_source.isEmpty {
            config.password_source = fallback.password_source
        }
        if config.password_env_var.isEmpty {
            config.password_env_var = fallback.password_env_var
        }
        if config.kopia_config_file?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            config.kopia_config_file = nil
        }
        return config
    }
}

struct RuntimeConfigOverrides: Decodable {
    var backup_source: String?
    var backup_ignore_patterns: [String]?
    var backup_tolerated_ephemeral_ignore_patterns: [String]?
    var protected_data_probe_paths: [String]?
    var cloud_materialization_roots: [String]?
    var cloud_materialization_enabled: Bool?
    var cloud_materialization_requires_allowed_network: Bool?
    var cloud_materialization_timeout_seconds: Int?
    var cloud_materialization_retry_seconds: Int?
    var network_policy_enabled: Bool?
    var deny_ssids: [String]?
    var run_interval_seconds: Int?
    var network_check_interval_seconds: Int?
    var preflight_failure_retry_seconds: Int?
    var password_source: String?
    var password_env_var: String?
    var password_command: [String]?
    var password_read_timeout_seconds: Int?
    var kopia_password_ref: String?
    var kopia_config_file: String?
    var minimum_execution_reserve_bytes: Int64?
    var critical_runtime_free_space_bytes: Int64?
    var unknown_icloud_placeholder_estimate_bytes: Int64?
    var limited_backup_acknowledged: Bool?

    func apply(to defaults: RuntimeConfig) -> RuntimeConfig {
        RuntimeConfig(
            backup_source: backup_source ?? defaults.backup_source,
            backup_ignore_patterns: backup_ignore_patterns ?? defaults.backup_ignore_patterns,
            backup_tolerated_ephemeral_ignore_patterns: backup_tolerated_ephemeral_ignore_patterns ?? defaults.backup_tolerated_ephemeral_ignore_patterns,
            protected_data_probe_paths: protected_data_probe_paths ?? defaults.protected_data_probe_paths,
            cloud_materialization_roots: cloud_materialization_roots ?? defaults.cloud_materialization_roots,
            cloud_materialization_enabled: cloud_materialization_enabled ?? defaults.cloud_materialization_enabled,
            cloud_materialization_requires_allowed_network: cloud_materialization_requires_allowed_network ?? defaults.cloud_materialization_requires_allowed_network,
            cloud_materialization_timeout_seconds: cloud_materialization_timeout_seconds ?? defaults.cloud_materialization_timeout_seconds,
            cloud_materialization_retry_seconds: cloud_materialization_retry_seconds ?? defaults.cloud_materialization_retry_seconds,
            network_policy_enabled: network_policy_enabled ?? defaults.network_policy_enabled,
            deny_ssids: deny_ssids ?? defaults.deny_ssids,
            run_interval_seconds: run_interval_seconds ?? defaults.run_interval_seconds,
            network_check_interval_seconds: network_check_interval_seconds ?? defaults.network_check_interval_seconds,
            preflight_failure_retry_seconds: preflight_failure_retry_seconds ?? defaults.preflight_failure_retry_seconds,
            password_source: password_source ?? defaults.password_source,
            password_env_var: password_env_var ?? defaults.password_env_var,
            password_command: password_command ?? defaults.password_command,
            password_read_timeout_seconds: password_read_timeout_seconds ?? defaults.password_read_timeout_seconds,
            kopia_password_ref: kopia_password_ref ?? defaults.kopia_password_ref,
            kopia_config_file: kopia_config_file ?? defaults.kopia_config_file,
            minimum_execution_reserve_bytes: minimum_execution_reserve_bytes ?? defaults.minimum_execution_reserve_bytes,
            critical_runtime_free_space_bytes: critical_runtime_free_space_bytes ?? defaults.critical_runtime_free_space_bytes,
            unknown_icloud_placeholder_estimate_bytes: unknown_icloud_placeholder_estimate_bytes ?? defaults.unknown_icloud_placeholder_estimate_bytes,
            limited_backup_acknowledged: limited_backup_acknowledged ?? defaults.limited_backup_acknowledged
        )
    }
}

enum Config {
    static func normalizedPath(_ rawValue: String?) -> String? {
        guard var path = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else {
            return nil
        }
        while path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }
        return path
    }

    static let appVersion = "1.1.1"
    static let appName = "COPYA"
    static let bundleIdentifier = "com.freesidenyc.copya"
    static let monitorLaunchdLabel = "com.freesidenyc.copya.agent"
    static let home = FileManager.default.homeDirectoryForCurrentUser.path
    static let currentUser = NSUserName()
    static let runtimeRoot = normalizedPath(ProcessInfo.processInfo.environment["COPYA_RUNTIME_ROOT"])
    static let kopiaHome = runtimeRoot.map { "\($0)/home" } ?? home
    static let appSupportDir = runtimeRoot.map { "\($0)/Application Support/COPYA" } ?? "\(home)/Library/Application Support/COPYA"
    static let cacheDir = runtimeRoot.map { "\($0)/Caches/COPYA" } ?? "\(home)/Library/Caches/COPYA"
    static let logDir = runtimeRoot.map { "\($0)/Logs/COPYA" } ?? "\(home)/Library/Logs/COPYA"
    static let explicitConfigFile = normalizedPath(ProcessInfo.processInfo.environment["COPYA_CONFIG_FILE"])
    static let configFile = explicitConfigFile ?? "\(appSupportDir)/config.json"
    private static let runtimeDefaults = RuntimeConfig.defaults(home: home)
    private static let runtimeStore = COPYACore.RuntimeConfigStore(
        path: configFile,
        defaults: runtimeDefaults,
        requireValid: explicitConfigFile != nil
    )
    private static let runtimeLock = NSLock()
    private static var runtimeStorage = loadRuntime()

    static var runtime: RuntimeConfig {
        runtimeLock.lock()
        defer {
            runtimeLock.unlock()
        }
        return runtimeStorage
    }

    static var configExists: Bool {
        runtimeStore.exists
    }

    static func saveRuntime(_ config: RuntimeConfig) throws {
        let validated = config.validated(fallback: runtimeDefaults)
        try runtimeStore.save(validated)
        runtimeLock.lock()
        runtimeStorage = validated
        runtimeLock.unlock()
    }

    static func reloadRuntime() {
        runtimeLock.lock()
        runtimeStorage = loadRuntime()
        runtimeLock.unlock()
    }

    private static func loadRuntime() -> RuntimeConfig {
        RuntimeConfig.load(
            path: configFile,
            home: home,
            requireValid: explicitConfigFile != nil
        )
    }

    static var backupSource: String { runtime.backup_source }
    static let backupIgnoreFile = "\(appSupportDir)/kopiaignore"
    static var backupIgnorePatterns: [String] { runtime.backup_ignore_patterns }
    static var backupToleratedEphemeralIgnorePatterns: [String] {
        runtime.backup_tolerated_ephemeral_ignore_patterns
    }
    static var protectedDataProbePaths: [String] { runtime.protected_data_probe_paths }
    static var cloudMaterializationRoots: [String] { runtime.cloud_materialization_roots }
    static var cloudMaterializationEnabled: Bool { runtime.cloud_materialization_enabled }
    static var cloudMaterializationRequiresAllowedNetwork: Bool {
        runtime.cloud_materialization_requires_allowed_network
    }
    static var cloudMaterializationTimeoutSeconds: Int { runtime.cloud_materialization_timeout_seconds }
    static var cloudMaterializationRetrySeconds: Int { runtime.cloud_materialization_retry_seconds }
    static var networkPolicyEnabled: Bool { runtime.network_policy_enabled }
    static let logFile = "\(logDir)/copya.log"
    static let rawKopiaLogFile = "\(logDir)/kopia-raw.log"
    static let statusFile = "\(appSupportDir)/status.json"
    static let activeRunFile = "\(appSupportDir)/active-run.json"
    static let internalKopiaActivityProbeEnabled = true
    static let internalKopiaLogDirs: [String] = [
        "\(kopiaHome)/Library/Logs/kopia/cli-logs",
        "\(kopiaHome)/Library/Logs/kopia/content-logs",
    ]
    static let internalKopiaLogMtimeToleranceSeconds = 10
    static let internalKopiaLogTailBytes = 131072
    static let kopiaActivityHeartbeatIntervalSeconds = 300
    static let kopiaInternalLogRetentionBytes: Int64 = 536870912
    static var minimumExecutionReserveBytes: Int64 { runtime.minimum_execution_reserve_bytes }
    static var criticalRuntimeFreeSpaceBytes: Int64 { runtime.critical_runtime_free_space_bytes }
    static var unknownICloudPlaceholderEstimateBytes: Int64 {
        runtime.unknown_icloud_placeholder_estimate_bytes
    }
    static var limitedBackupAcknowledged: Bool { runtime.limited_backup_acknowledged }
    static var diskFreeSpaceCheckPaths: [String] {
        [
            "\(cacheDir)/kopia",
            "\(kopiaHome)/Library/Logs/kopia",
            rawKopiaLogFile,
            kopiaHome,
        ]
    }
    static var passwordSource: String { runtime.password_source }
    static var passwordEnvVar: String { runtime.password_env_var }
    static let keychainService = "com.freesidenyc.copya"
    static let keychainAccount = "kopia-password"
    static var passwordCommand: [String] { runtime.password_command }
    static var passwordReadTimeoutSeconds: Int { runtime.password_read_timeout_seconds }
    static var kopiaPasswordRef: String { runtime.kopia_password_ref }
    static var kopiaConfigFile: String? { normalizedPath(runtime.kopia_config_file) }
    static var runIntervalSeconds: Int { runtime.run_interval_seconds }
    static var networkCheckIntervalSeconds: Int { runtime.network_check_interval_seconds }
    static var preflightFailureRetrySeconds: Int { runtime.preflight_failure_retry_seconds }
    static var denySSIDs: Set<String> { Set(runtime.deny_ssids) }
    static let executableSearchPath = [
        Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/bin").path,
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin",
        "/usr/sbin",
        "/sbin",
    ]
}
enum DateFormatters {
    static let iso = ISO8601DateFormatter()

    static let log: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return formatter
    }()

    static let menu: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()
}

struct ConfigSummary: Codable {
    var app_name: String
    var runtime_root: String?
    var kopia_home: String
    var config_file: String
    var backup_source: String
    var backup_ignore_file: String
    var backup_ignore_patterns: [String]
    var backup_tolerated_ephemeral_ignore_patterns: [String]
    var protected_data_probe_paths: [String]
    var cloud_materialization_roots: [String]
    var cloud_materialization_enabled: Bool
    var cloud_materialization_requires_allowed_network: Bool
    var cloud_materialization_timeout_seconds: Int
    var cloud_materialization_retry_seconds: Int
    var network_policy_enabled: Bool
    var run_interval_seconds: Int
    var network_check_interval_seconds: Int
    var preflight_failure_retry_seconds: Int
    var deny_ssids: [String]
    var password_source: String
    var password_env_var: String
    var password_command_configured: Bool
    var password_ref_configured: Bool
    var kopia_config_file: String?
    var app_bundle_identifier: String
    var monitor_launchd_label: String
    var log_file: String
    var raw_kopia_log_file: String
    var status_file: String
    var active_run_file: String
    var internal_kopia_activity_probe_enabled: Bool
    var internal_kopia_log_dirs: [String]
    var internal_kopia_log_mtime_tolerance_seconds: Int
    var internal_kopia_log_tail_bytes: Int
    var kopia_activity_heartbeat_interval_seconds: Int
    var kopia_internal_log_retention_bytes: Int64
    var minimum_execution_reserve_bytes: Int64
    var critical_runtime_free_space_bytes: Int64
    var unknown_icloud_placeholder_estimate_bytes: Int64
    var limited_backup_acknowledged: Bool
    var disk_free_space_check_paths: [String]
}

extension ConfigSummary {
    enum CodingKeys: String, CodingKey {
        case app_name
        case runtime_root
        case kopia_home
        case config_file
        case backup_source
        case backup_ignore_file
        case backup_ignore_patterns
        case backup_tolerated_ephemeral_ignore_patterns
        case protected_data_probe_paths
        case cloud_materialization_roots
        case cloud_materialization_enabled
        case cloud_materialization_requires_allowed_network
        case cloud_materialization_timeout_seconds
        case cloud_materialization_retry_seconds
        case network_policy_enabled
        case run_interval_seconds
        case network_check_interval_seconds
        case preflight_failure_retry_seconds
        case deny_ssids
        case password_source
        case password_env_var
        case password_command_configured
        case password_ref_configured
        case kopia_config_file
        case app_bundle_identifier
        case monitor_launchd_label
        case log_file
        case raw_kopia_log_file
        case status_file
        case active_run_file
        case internal_kopia_activity_probe_enabled
        case internal_kopia_log_dirs
        case internal_kopia_log_mtime_tolerance_seconds
        case internal_kopia_log_tail_bytes
        case kopia_activity_heartbeat_interval_seconds
        case kopia_internal_log_retention_bytes
        case minimum_execution_reserve_bytes
        case critical_runtime_free_space_bytes
        case unknown_icloud_placeholder_estimate_bytes
        case limited_backup_acknowledged
        case disk_free_space_check_paths
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        app_name = try container.decodeIfPresent(String.self, forKey: .app_name) ?? Config.appName
        runtime_root = try container.decodeIfPresent(String.self, forKey: .runtime_root) ?? Config.runtimeRoot
        kopia_home = try container.decodeIfPresent(String.self, forKey: .kopia_home) ?? Config.kopiaHome
        config_file = try container.decodeIfPresent(String.self, forKey: .config_file) ?? Config.configFile
        backup_source = try container.decodeIfPresent(String.self, forKey: .backup_source) ?? Config.backupSource
        backup_ignore_file = try container.decodeIfPresent(String.self, forKey: .backup_ignore_file) ?? Config.backupIgnoreFile
        backup_ignore_patterns = try container.decodeIfPresent([String].self, forKey: .backup_ignore_patterns) ?? Config.backupIgnorePatterns
        backup_tolerated_ephemeral_ignore_patterns = try container.decodeIfPresent([String].self, forKey: .backup_tolerated_ephemeral_ignore_patterns) ?? Config.backupToleratedEphemeralIgnorePatterns
        protected_data_probe_paths = try container.decodeIfPresent([String].self, forKey: .protected_data_probe_paths) ?? Config.protectedDataProbePaths
        cloud_materialization_roots = try container.decodeIfPresent([String].self, forKey: .cloud_materialization_roots) ?? Config.cloudMaterializationRoots
        cloud_materialization_enabled = try container.decodeIfPresent(Bool.self, forKey: .cloud_materialization_enabled) ?? Config.cloudMaterializationEnabled
        cloud_materialization_requires_allowed_network = try container.decodeIfPresent(Bool.self, forKey: .cloud_materialization_requires_allowed_network) ?? Config.cloudMaterializationRequiresAllowedNetwork
        cloud_materialization_timeout_seconds = try container.decodeIfPresent(Int.self, forKey: .cloud_materialization_timeout_seconds) ?? Config.cloudMaterializationTimeoutSeconds
        cloud_materialization_retry_seconds = try container.decodeIfPresent(Int.self, forKey: .cloud_materialization_retry_seconds) ?? Config.cloudMaterializationRetrySeconds
        network_policy_enabled = try container.decodeIfPresent(Bool.self, forKey: .network_policy_enabled) ?? Config.networkPolicyEnabled
        run_interval_seconds = try container.decodeIfPresent(Int.self, forKey: .run_interval_seconds) ?? Config.runIntervalSeconds
        network_check_interval_seconds = try container.decodeIfPresent(Int.self, forKey: .network_check_interval_seconds) ?? Config.networkCheckIntervalSeconds
        preflight_failure_retry_seconds = try container.decodeIfPresent(Int.self, forKey: .preflight_failure_retry_seconds) ?? Config.preflightFailureRetrySeconds
        deny_ssids = try container.decodeIfPresent([String].self, forKey: .deny_ssids) ?? Array(Config.denySSIDs).sorted()
        password_source = try container.decodeIfPresent(String.self, forKey: .password_source) ?? Config.passwordSource
        password_env_var = try container.decodeIfPresent(String.self, forKey: .password_env_var) ?? Config.passwordEnvVar
        password_command_configured = try container.decodeIfPresent(Bool.self, forKey: .password_command_configured) ?? !Config.passwordCommand.isEmpty
        password_ref_configured = try container.decodeIfPresent(Bool.self, forKey: .password_ref_configured) ?? (Config.passwordSource == "onepassword" && !Config.kopiaPasswordRef.isEmpty)
        kopia_config_file = try container.decodeIfPresent(String.self, forKey: .kopia_config_file) ?? Config.kopiaConfigFile
        app_bundle_identifier = try container.decodeIfPresent(String.self, forKey: .app_bundle_identifier) ?? Config.bundleIdentifier
        monitor_launchd_label = try container.decodeIfPresent(String.self, forKey: .monitor_launchd_label) ?? Config.monitorLaunchdLabel
        log_file = try container.decodeIfPresent(String.self, forKey: .log_file) ?? Config.logFile
        raw_kopia_log_file = try container.decodeIfPresent(String.self, forKey: .raw_kopia_log_file) ?? Config.rawKopiaLogFile
        status_file = try container.decodeIfPresent(String.self, forKey: .status_file) ?? Config.statusFile
        active_run_file = try container.decodeIfPresent(String.self, forKey: .active_run_file) ?? Config.activeRunFile
        internal_kopia_activity_probe_enabled = try container.decodeIfPresent(Bool.self, forKey: .internal_kopia_activity_probe_enabled) ?? Config.internalKopiaActivityProbeEnabled
        internal_kopia_log_dirs = try container.decodeIfPresent([String].self, forKey: .internal_kopia_log_dirs) ?? Config.internalKopiaLogDirs
        internal_kopia_log_mtime_tolerance_seconds = try container.decodeIfPresent(Int.self, forKey: .internal_kopia_log_mtime_tolerance_seconds) ?? Config.internalKopiaLogMtimeToleranceSeconds
        internal_kopia_log_tail_bytes = try container.decodeIfPresent(Int.self, forKey: .internal_kopia_log_tail_bytes) ?? Config.internalKopiaLogTailBytes
        kopia_activity_heartbeat_interval_seconds = try container.decodeIfPresent(Int.self, forKey: .kopia_activity_heartbeat_interval_seconds) ?? Config.kopiaActivityHeartbeatIntervalSeconds
        kopia_internal_log_retention_bytes = try container.decodeIfPresent(Int64.self, forKey: .kopia_internal_log_retention_bytes) ?? Config.kopiaInternalLogRetentionBytes
        minimum_execution_reserve_bytes = try container.decodeIfPresent(Int64.self, forKey: .minimum_execution_reserve_bytes) ?? Config.minimumExecutionReserveBytes
        critical_runtime_free_space_bytes = try container.decodeIfPresent(Int64.self, forKey: .critical_runtime_free_space_bytes) ?? Config.criticalRuntimeFreeSpaceBytes
        unknown_icloud_placeholder_estimate_bytes = try container.decodeIfPresent(Int64.self, forKey: .unknown_icloud_placeholder_estimate_bytes) ?? Config.unknownICloudPlaceholderEstimateBytes
        limited_backup_acknowledged = try container.decodeIfPresent(Bool.self, forKey: .limited_backup_acknowledged) ?? Config.limitedBackupAcknowledged
        disk_free_space_check_paths = try container.decodeIfPresent([String].self, forKey: .disk_free_space_check_paths) ?? Config.diskFreeSpaceCheckPaths
    }
}

enum ConfigSummaryFactory {
    static func current() -> ConfigSummary {
        ConfigSummary(
            app_name: Config.appName,
            runtime_root: Config.runtimeRoot,
            kopia_home: Config.kopiaHome,
            config_file: Config.configFile,
            backup_source: Config.backupSource,
            backup_ignore_file: Config.backupIgnoreFile,
            backup_ignore_patterns: Config.backupIgnorePatterns,
            backup_tolerated_ephemeral_ignore_patterns: Config.backupToleratedEphemeralIgnorePatterns,
            protected_data_probe_paths: Config.protectedDataProbePaths,
            cloud_materialization_roots: Config.cloudMaterializationRoots,
            cloud_materialization_enabled: Config.cloudMaterializationEnabled,
            cloud_materialization_requires_allowed_network: Config.cloudMaterializationRequiresAllowedNetwork,
            cloud_materialization_timeout_seconds: Config.cloudMaterializationTimeoutSeconds,
            cloud_materialization_retry_seconds: Config.cloudMaterializationRetrySeconds,
            network_policy_enabled: Config.networkPolicyEnabled,
            run_interval_seconds: Config.runIntervalSeconds,
            network_check_interval_seconds: Config.networkCheckIntervalSeconds,
            preflight_failure_retry_seconds: Config.preflightFailureRetrySeconds,
            deny_ssids: Array(Config.denySSIDs).sorted(),
            password_source: Config.passwordSource,
            password_env_var: Config.passwordEnvVar,
            password_command_configured: !Config.passwordCommand.isEmpty,
            password_ref_configured: Config.passwordSource == "onepassword" && !Config.kopiaPasswordRef.isEmpty,
            kopia_config_file: Config.kopiaConfigFile,
            app_bundle_identifier: Config.bundleIdentifier,
            monitor_launchd_label: Config.monitorLaunchdLabel,
            log_file: Config.logFile,
            raw_kopia_log_file: Config.rawKopiaLogFile,
            status_file: Config.statusFile,
            active_run_file: Config.activeRunFile,
            internal_kopia_activity_probe_enabled: Config.internalKopiaActivityProbeEnabled,
            internal_kopia_log_dirs: Config.internalKopiaLogDirs,
            internal_kopia_log_mtime_tolerance_seconds: Config.internalKopiaLogMtimeToleranceSeconds,
            internal_kopia_log_tail_bytes: Config.internalKopiaLogTailBytes,
            kopia_activity_heartbeat_interval_seconds: Config.kopiaActivityHeartbeatIntervalSeconds,
            kopia_internal_log_retention_bytes: Config.kopiaInternalLogRetentionBytes,
            minimum_execution_reserve_bytes: Config.minimumExecutionReserveBytes,
            critical_runtime_free_space_bytes: Config.criticalRuntimeFreeSpaceBytes,
            unknown_icloud_placeholder_estimate_bytes: Config.unknownICloudPlaceholderEstimateBytes,
            limited_backup_acknowledged: Config.limitedBackupAcknowledged,
            disk_free_space_check_paths: Config.diskFreeSpaceCheckPaths
        )
    }
}

struct NetworkSnapshot: Codable {
    var state: String
    var allowed: Bool
    var device: String?
    var ssid: String?
    var reason: String
    var location_authorization: String
    var is_expensive: Bool
    var is_constrained: Bool
    var deny_ssids: [String]
}

struct DiskSpaceCheckResult: Codable {
    var path: String
    var checked_path: String
    var volume_key: String?
    var free_bytes: Int64?
    var required_bytes: Int64
    var threshold_kind: String
    var ok: Bool
    var error: String?
}

struct DiskHealthSnapshot: Codable {
    var checked_at: String?
    var ok: Bool
    var threshold_kind: String
    var required_bytes: Int64
    var failing_path: String?
    var failing_free_bytes: Int64?
    var reason: String?
    var results: [DiskSpaceCheckResult]

    static func unknown() -> DiskHealthSnapshot {
        DiskHealthSnapshot(
            checked_at: nil,
            ok: true,
            threshold_kind: "unknown",
            required_bytes: 0,
            failing_path: nil,
            failing_free_bytes: nil,
            reason: nil,
            results: []
        )
    }
}

struct CloudCapacityRootEstimate: Codable {
    var root: String
    var exists: Bool
    var provider: String
    var volume_key: String?
    var dataless_placeholders: Int
    var icloud_known_bytes: Int64
    var icloud_unknown_count: Int
    var icloud_unknown_fallback_bytes: Int64
    var fileprovider_advisory_known_bytes: Int64
    var fileprovider_advisory_unknown_count: Int
    var local_unknown_count: Int
    var sample_paths: [String]
    var errors: [String]
}

struct CloudCapacityVolumeEstimate: Codable {
    var volume_key: String
    var checked_path: String
    var available_bytes: Int64?
    var required_bytes: Int64
    var execution_reserve_bytes: Int64
    var icloud_known_bytes: Int64
    var icloud_unknown_fallback_bytes: Int64
    var ok: Bool
    var capacity_api: String
    var error: String?
}

struct CloudCapacityEstimate: Codable {
    var checked_at: String?
    var ok: Bool
    var confidence: String
    var reason: String?
    var execution_reserve_bytes: Int64
    var unknown_icloud_placeholder_estimate_bytes: Int64
    var icloud_known_bytes: Int64
    var icloud_unknown_count: Int
    var icloud_unknown_fallback_bytes: Int64
    var fileprovider_advisory_known_bytes: Int64
    var fileprovider_advisory_unknown_count: Int
    var local_unknown_count: Int
    var capacity_api: String
    var warnings: [String]
    var roots: [CloudCapacityRootEstimate]
    var volumes: [CloudCapacityVolumeEstimate]

    static func unknown() -> CloudCapacityEstimate {
        CloudCapacityEstimate(
            checked_at: nil,
            ok: true,
            confidence: "unknown",
            reason: nil,
            execution_reserve_bytes: Config.minimumExecutionReserveBytes,
            unknown_icloud_placeholder_estimate_bytes: Config.unknownICloudPlaceholderEstimateBytes,
            icloud_known_bytes: 0,
            icloud_unknown_count: 0,
            icloud_unknown_fallback_bytes: 0,
            fileprovider_advisory_known_bytes: 0,
            fileprovider_advisory_unknown_count: 0,
            local_unknown_count: 0,
            capacity_api: "unknown",
            warnings: [],
            roots: [],
            volumes: []
        )
    }
}

enum CloudPlaceholderKind: String, Codable {
    case file
    case directory
    case package
    case other
}

struct CloudPlaceholderRecord {
    var path: String
    var kind: CloudPlaceholderKind
    var isICloudActionable: Bool
    var downloadRequestError: String?
}

enum CloudPlaceholderClassifier {
    static func record(
        for url: URL,
        root: String,
        values: URLResourceValues?,
        statSnapshot: FileFlags.Snapshot?
    ) -> CloudPlaceholderRecord? {
        guard let statSnapshot, FileFlags.isDataless(statSnapshot) else {
            return nil
        }

        return CloudPlaceholderRecord(
            path: url.path,
            kind: kind(values: values, url: url),
            isICloudActionable: providerClass(for: url, root: root, values: values) == "icloud_actionable",
            downloadRequestError: nil
        )
    }

    static func kind(values: URLResourceValues?, url: URL? = nil) -> CloudPlaceholderKind {
        if values?.isPackage == true {
            return .package
        }
        if values?.isDirectory == true {
            return .directory
        }
        if values?.isRegularFile == true {
            return .file
        }
        if let url {
            var isDirectory = ObjCBool(false)
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                return .directory
            }
        }
        return .other
    }

    static func providerClass(forRoot root: String) -> String {
        if root.contains("/Library/Mobile Documents") {
            return "icloud_actionable"
        }
        if root.contains("/Library/CloudStorage") {
            return "fileprovider_advisory"
        }
        return "local_unknown"
    }

    static func providerClass(for url: URL, root: String, values: URLResourceValues?) -> String {
        if values?.isUbiquitousItem == true || root.contains("/Library/Mobile Documents") {
            return "icloud_actionable"
        }
        if url.path.contains("/Library/CloudStorage/") || root.contains("/Library/CloudStorage") {
            return "fileprovider_advisory"
        }
        return "local_unknown"
    }
}

struct ProtectedDataProbeResult: Codable {
    var path: String
    var exists: Bool
    var readable: Bool
    var is_directory: Bool
    var error: String?
}

struct CloudMaterializationRootResult: Codable {
    var root: String
    var exists: Bool
    var directories_seen: Int
    var files_seen: Int
    var files_read: Int
    var dataless_placeholders: Int
    var read_failures: Int
    var failures: Int
    var aborted: Bool
    var timed_out: Bool
    var last_error: String?
    var dataless_sample_paths: [String]
    var read_failure_sample_paths: [String]
    var total_dataless_entries: Int?
    var resolved_dataless_placeholders: Int?
    var download_request_failures: Int?
    var placeholder_resolution_failures: Int?
    var dataless_kind_counts: [String: Int]?
    var placeholder_failure_sample_paths: [String]

    enum CodingKeys: String, CodingKey {
        case root
        case exists
        case directories_seen
        case files_seen
        case files_read
        case dataless_placeholders
        case read_failures
        case failures
        case aborted
        case timed_out
        case last_error
        case dataless_sample_paths
        case read_failure_sample_paths
        case total_dataless_entries
        case resolved_dataless_placeholders
        case download_request_failures
        case placeholder_resolution_failures
        case dataless_kind_counts
        case placeholder_failure_sample_paths
    }

    init(
        root: String,
        exists: Bool,
        directories_seen: Int,
        files_seen: Int,
        files_read: Int,
        dataless_placeholders: Int = 0,
        read_failures: Int? = nil,
        failures: Int,
        aborted: Bool,
        timed_out: Bool,
        last_error: String?,
        dataless_sample_paths: [String] = [],
        read_failure_sample_paths: [String] = [],
        total_dataless_entries: Int? = nil,
        resolved_dataless_placeholders: Int? = nil,
        download_request_failures: Int? = nil,
        placeholder_resolution_failures: Int? = nil,
        dataless_kind_counts: [String: Int]? = nil,
        placeholder_failure_sample_paths: [String] = []
    ) {
        self.root = root
        self.exists = exists
        self.directories_seen = directories_seen
        self.files_seen = files_seen
        self.files_read = files_read
        self.dataless_placeholders = dataless_placeholders
        self.read_failures = read_failures ?? failures
        self.failures = failures
        self.aborted = aborted
        self.timed_out = timed_out
        self.last_error = last_error
        self.dataless_sample_paths = dataless_sample_paths
        self.read_failure_sample_paths = read_failure_sample_paths
        self.total_dataless_entries = total_dataless_entries
        self.resolved_dataless_placeholders = resolved_dataless_placeholders
        self.download_request_failures = download_request_failures
        self.placeholder_resolution_failures = placeholder_resolution_failures
        self.dataless_kind_counts = dataless_kind_counts
        self.placeholder_failure_sample_paths = placeholder_failure_sample_paths
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        root = try container.decode(String.self, forKey: .root)
        exists = try container.decode(Bool.self, forKey: .exists)
        directories_seen = try container.decode(Int.self, forKey: .directories_seen)
        files_seen = try container.decode(Int.self, forKey: .files_seen)
        files_read = try container.decode(Int.self, forKey: .files_read)
        dataless_placeholders = try container.decodeIfPresent(Int.self, forKey: .dataless_placeholders) ?? 0
        failures = try container.decode(Int.self, forKey: .failures)
        read_failures = try container.decodeIfPresent(Int.self, forKey: .read_failures) ?? failures
        aborted = try container.decode(Bool.self, forKey: .aborted)
        timed_out = try container.decode(Bool.self, forKey: .timed_out)
        last_error = try container.decodeIfPresent(String.self, forKey: .last_error)
        dataless_sample_paths = try container.decodeIfPresent([String].self, forKey: .dataless_sample_paths) ?? []
        read_failure_sample_paths = try container.decodeIfPresent([String].self, forKey: .read_failure_sample_paths) ?? []
        total_dataless_entries = try container.decodeIfPresent(Int.self, forKey: .total_dataless_entries)
        resolved_dataless_placeholders = try container.decodeIfPresent(Int.self, forKey: .resolved_dataless_placeholders)
        download_request_failures = try container.decodeIfPresent(Int.self, forKey: .download_request_failures)
        placeholder_resolution_failures = try container.decodeIfPresent(Int.self, forKey: .placeholder_resolution_failures)
        dataless_kind_counts = try container.decodeIfPresent([String: Int].self, forKey: .dataless_kind_counts)
        placeholder_failure_sample_paths = try container.decodeIfPresent([String].self, forKey: .placeholder_failure_sample_paths) ?? []
    }
}

struct CloudMaterializationSnapshot: Codable {
    var enabled: Bool
    var started_at: String?
    var finished_at: String?
    var completed: Bool
    var aborted: Bool
    var reason: String?
    var current_root: String?
    var current_phase: String?
    var total_directories_seen: Int
    var total_files_seen: Int
    var total_files_read: Int
    var total_failures: Int
    var total_dataless_placeholders: Int? = nil
    var total_read_failures: Int? = nil
    var total_dataless_entries: Int? = nil
    var total_resolved_dataless_placeholders: Int? = nil
    var total_download_request_failures: Int? = nil
    var total_placeholder_resolution_failures: Int? = nil
    var cloud_coverage: String? = nil
    var roots: [CloudMaterializationRootResult]
}

extension CloudMaterializationSnapshot {
    static func empty() -> CloudMaterializationSnapshot {
        CloudMaterializationSnapshot(
            enabled: Config.cloudMaterializationEnabled,
            started_at: nil,
            finished_at: nil,
            completed: false,
            aborted: false,
            reason: nil,
            current_root: nil,
            current_phase: nil,
            total_directories_seen: 0,
            total_files_seen: 0,
            total_files_read: 0,
            total_failures: 0,
            total_dataless_placeholders: 0,
            total_read_failures: 0,
            total_dataless_entries: 0,
            total_resolved_dataless_placeholders: 0,
            total_download_request_failures: 0,
            total_placeholder_resolution_failures: 0,
            cloud_coverage: nil,
            roots: []
        )
    }
}

struct KopiaSnapshotIssueSample: Codable {
    var category: String
    var path: String?
    var detail: String
}

struct KopiaParsedRun: Codable {
    var run_id: String?
    var pid: Int32?
    var started_at: String?
    var completed_at: String?
    var exit_status: Int32?
    var snapshot_id: String?
    var snapshot_root: String?
    var snapshot_duration: String?
    var snapshot_result: String
    var fatal_error_count: Int
    var tolerated_count: Int
    var action_required_count: Int
    var unclassified_count: Int
    var categorized_counts: [String: Int]
    var samples: [KopiaSnapshotIssueSample]
}

struct StatusSnapshot: Codable {
    var app_version: String
    var updated_at: String
    var state: String
    var network_state: String
    var network_ssid: String?
    var network_reason: String
    var network_is_expensive: Bool
    var network_is_constrained: Bool
    var next_run_at: String?
    var active_operation: String?
    var active_operation_started_at: String?
    var active_operation_detail: String?
    var operation_elapsed_seconds: Int?
    var active_pid: Int32?
    var active_run_id: String?
    var active_pid_owner: String?
    var external_kopia_pids: [Int32]?
    var last_start_at: String?
    var last_success_at: String?
    var last_success_cloud_coverage: String?
    var last_snapshot_at: String?
    var last_snapshot_id: String?
    var last_snapshot_root: String?
    var last_snapshot_duration: String?
    var last_snapshot_result: String?
    var last_snapshot_error_count: Int?
    var last_snapshot_tolerated_count: Int?
    var last_snapshot_action_required_count: Int?
    var last_snapshot_unclassified_count: Int?
    var last_snapshot_issue_counts: [String: Int]?
    var last_snapshot_issue_samples: [KopiaSnapshotIssueSample]?
    var backup_elapsed_seconds: Int?
    var last_liveness_check_at: String?
    var last_kopia_output_at: String?
    var kopia_output_idle_seconds: Int?
    var kopia_activity: InternalKopiaActivitySnapshot?
    var kopia_suppressed_dataless_read_errors: Int?
    var kopia_other_output_read_errors: Int?
    var disk_health: DiskHealthSnapshot?
    var cloud_capacity_estimate: CloudCapacityEstimate?
    var last_failure_at: String?
    var last_failure_kind: String?
    var last_failure_detail: String?
    var last_failure: String?
    var last_abort_reason: String?
    var protected_data_probe_results: [ProtectedDataProbeResult]?
    var cloud_materialization: CloudMaterializationSnapshot?
    var kopia_ran_after_materialization: Bool?
    var setup_gate: SetupGateResult?
    var repository_status: RepositoryStatusSnapshot?
    var config_summary: ConfigSummary

    enum CodingKeys: String, CodingKey {
        case app_version
        case updated_at
        case state
        case network_state
        case network_ssid
        case network_reason
        case network_is_expensive
        case network_is_constrained
        case next_run_at
        case active_operation
        case active_operation_started_at
        case active_operation_detail
        case operation_elapsed_seconds
        case active_pid
        case active_run_id
        case active_pid_owner
        case external_kopia_pids
        case last_start_at
        case last_success_at
        case last_success_cloud_coverage
        case last_snapshot_at
        case last_snapshot_id
        case last_snapshot_root
        case last_snapshot_duration
        case last_snapshot_result
        case last_snapshot_error_count
        case last_snapshot_tolerated_count
        case last_snapshot_action_required_count
        case last_snapshot_unclassified_count
        case last_snapshot_issue_counts
        case last_snapshot_issue_samples
        case backup_elapsed_seconds
        case last_liveness_check_at
        case last_kopia_output_at
        case kopia_output_idle_seconds
        case kopia_activity
        case kopia_suppressed_dataless_read_errors
        case kopia_other_output_read_errors
        case disk_health
        case cloud_capacity_estimate
        case last_failure_at
        case last_failure_kind
        case last_failure_detail
        case last_failure
        case last_abort_reason
        case protected_data_probe_results
        case cloud_materialization
        case kopia_ran_after_materialization
        case setup_gate
        case repository_status
        case config_summary
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(app_version, forKey: .app_version)
        try container.encode(updated_at, forKey: .updated_at)
        try container.encode(state, forKey: .state)
        try container.encode(network_state, forKey: .network_state)
        try container.encode(network_reason, forKey: .network_reason)
        try container.encode(network_is_expensive, forKey: .network_is_expensive)
        try container.encode(network_is_constrained, forKey: .network_is_constrained)
        try container.encode(config_summary, forKey: .config_summary)
        try encodeOptional(network_ssid, into: &container, forKey: .network_ssid)
        try encodeOptional(next_run_at, into: &container, forKey: .next_run_at)
        try encodeOptional(active_operation, into: &container, forKey: .active_operation)
        try encodeOptional(active_operation_started_at, into: &container, forKey: .active_operation_started_at)
        try encodeOptional(active_operation_detail, into: &container, forKey: .active_operation_detail)
        try encodeOptional(operation_elapsed_seconds, into: &container, forKey: .operation_elapsed_seconds)
        try encodeOptional(active_pid, into: &container, forKey: .active_pid)
        try encodeOptional(active_run_id, into: &container, forKey: .active_run_id)
        try encodeOptional(active_pid_owner, into: &container, forKey: .active_pid_owner)
        try encodeOptional(external_kopia_pids, into: &container, forKey: .external_kopia_pids)
        try encodeOptional(last_start_at, into: &container, forKey: .last_start_at)
        try encodeOptional(last_success_at, into: &container, forKey: .last_success_at)
        try encodeOptional(last_success_cloud_coverage, into: &container, forKey: .last_success_cloud_coverage)
        try encodeOptional(last_snapshot_at, into: &container, forKey: .last_snapshot_at)
        try encodeOptional(last_snapshot_id, into: &container, forKey: .last_snapshot_id)
        try encodeOptional(last_snapshot_root, into: &container, forKey: .last_snapshot_root)
        try encodeOptional(last_snapshot_duration, into: &container, forKey: .last_snapshot_duration)
        try encodeOptional(last_snapshot_result, into: &container, forKey: .last_snapshot_result)
        try encodeOptional(last_snapshot_error_count, into: &container, forKey: .last_snapshot_error_count)
        try encodeOptional(last_snapshot_tolerated_count, into: &container, forKey: .last_snapshot_tolerated_count)
        try encodeOptional(last_snapshot_action_required_count, into: &container, forKey: .last_snapshot_action_required_count)
        try encodeOptional(last_snapshot_unclassified_count, into: &container, forKey: .last_snapshot_unclassified_count)
        try encodeOptional(last_snapshot_issue_counts, into: &container, forKey: .last_snapshot_issue_counts)
        try encodeOptional(last_snapshot_issue_samples, into: &container, forKey: .last_snapshot_issue_samples)
        try encodeOptional(backup_elapsed_seconds, into: &container, forKey: .backup_elapsed_seconds)
        try encodeOptional(last_liveness_check_at, into: &container, forKey: .last_liveness_check_at)
        try encodeOptional(last_kopia_output_at, into: &container, forKey: .last_kopia_output_at)
        try encodeOptional(kopia_output_idle_seconds, into: &container, forKey: .kopia_output_idle_seconds)
        try encodeOptional(kopia_activity, into: &container, forKey: .kopia_activity)
        try encodeOptional(kopia_suppressed_dataless_read_errors, into: &container, forKey: .kopia_suppressed_dataless_read_errors)
        try encodeOptional(kopia_other_output_read_errors, into: &container, forKey: .kopia_other_output_read_errors)
        try encodeOptional(disk_health, into: &container, forKey: .disk_health)
        try encodeOptional(cloud_capacity_estimate, into: &container, forKey: .cloud_capacity_estimate)
        try encodeOptional(last_failure_at, into: &container, forKey: .last_failure_at)
        try encodeOptional(last_failure_kind, into: &container, forKey: .last_failure_kind)
        try encodeOptional(last_failure_detail, into: &container, forKey: .last_failure_detail)
        try encodeOptional(last_failure, into: &container, forKey: .last_failure)
        try encodeOptional(last_abort_reason, into: &container, forKey: .last_abort_reason)
        try encodeOptional(protected_data_probe_results, into: &container, forKey: .protected_data_probe_results)
        try encodeOptional(cloud_materialization, into: &container, forKey: .cloud_materialization)
        try encodeOptional(kopia_ran_after_materialization, into: &container, forKey: .kopia_ran_after_materialization)
        try encodeOptional(setup_gate, into: &container, forKey: .setup_gate)
        try encodeOptional(repository_status, into: &container, forKey: .repository_status)
    }

    private func encodeOptional<T: Encodable>(
        _ value: T?,
        into container: inout KeyedEncodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws {
        if let value {
            try container.encode(value, forKey: key)
        } else {
            try container.encodeNil(forKey: key)
        }
    }
}

enum BackupState: String {
    case ready
    case startingBackup = "starting_backup"
    case preparingCloudFiles = "preparing_cloud_files"
    case syncing
    case externalBackupDetected = "external_backup_detected"
    case paused
    case needsPermission = "needs_permission"
    case needsFullDiskAccess = "needs_full_disk_access"
    case needsDiskSpace = "needs_disk_space"
    case needsSecret = "needs_secret"
    case setupIncomplete = "setup_incomplete"
    case cloudDownloadBlocked = "cloud_download_blocked"
    case cloudPartial = "cloud_partial"
    case backupPartial = "backup_partial"
    case failed
    case disabled
}

enum LocationStatus {
    static func name(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "notDetermined"
        case .restricted:
            return "restricted"
        case .denied:
            return "denied"
        case .authorizedAlways:
            return "authorizedAlways"
        @unknown default:
            return "unknown"
        }
    }

    static func isAuthorized(_ status: CLAuthorizationStatus) -> Bool {
        status == .authorizedAlways
    }
}

enum NetworkPolicy {
    static func current(
        isExpensive: Bool,
        isConstrained: Bool,
        authorization: CLAuthorizationStatus? = nil
    ) -> NetworkSnapshot {
        let authorization = authorization ?? CLLocationManager().authorizationStatus
        let authorizationName = LocationStatus.name(authorization)

        guard Config.networkPolicyEnabled else {
            return snapshot(
                state: "allowed",
                allowed: true,
                device: nil,
                ssid: nil,
                reason: "Network policy disabled by runtime config",
                authorization: authorizationName,
                isExpensive: isExpensive,
                isConstrained: isConstrained
            )
        }

        guard CLLocationManager.locationServicesEnabled() else {
            return snapshot(
                state: "permission",
                allowed: false,
                device: nil,
                ssid: nil,
                reason: "Location Services are disabled",
                authorization: authorizationName,
                isExpensive: isExpensive,
                isConstrained: isConstrained
            )
        }

        guard LocationStatus.isAuthorized(authorization) else {
            return snapshot(
                state: "permission",
                allowed: false,
                device: nil,
                ssid: nil,
                reason: "Location permission is \(authorizationName)",
                authorization: authorizationName,
                isExpensive: isExpensive,
                isConstrained: isConstrained
            )
        }

        let client = CWWiFiClient.shared()
        guard let wifiInterface = client.interface() else {
            return snapshot(
                state: "missing",
                allowed: false,
                device: nil,
                ssid: nil,
                reason: "No Wi-Fi interface found",
                authorization: authorizationName,
                isExpensive: isExpensive,
                isConstrained: isConstrained
            )
        }

        let device = wifiInterface.interfaceName
        let ssid = readSSID(from: wifiInterface)?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let ssid, !ssid.isEmpty else {
            return snapshot(
                state: "missing",
                allowed: false,
                device: device,
                ssid: nil,
                reason: "No SSID detected",
                authorization: authorizationName,
                isExpensive: isExpensive,
                isConstrained: isConstrained
            )
        }

        if isRedacted(ssid) {
            return snapshot(
                state: "redacted",
                allowed: false,
                device: device,
                ssid: ssid,
                reason: "SSID redacted by macOS privacy controls",
                authorization: authorizationName,
                isExpensive: isExpensive,
                isConstrained: isConstrained
            )
        }

        if Config.denySSIDs.contains(ssid) {
            return snapshot(
                state: "denied",
                allowed: false,
                device: device,
                ssid: ssid,
                reason: "SSID is denied",
                authorization: authorizationName,
                isExpensive: isExpensive,
                isConstrained: isConstrained
            )
        }

        var reason = "SSID is allowed"
        if isConstrained {
            reason += "; Low Data Mode is on"
        } else if isExpensive {
            reason += "; network is marked expensive"
        }

        return snapshot(
            state: "allowed",
            allowed: true,
            device: device,
            ssid: ssid,
            reason: reason,
            authorization: authorizationName,
            isExpensive: isExpensive,
            isConstrained: isConstrained
        )
    }

    private static func readSSID(from wifiInterface: CWInterface) -> String? {
        if let ssid = wifiInterface.ssid(), !ssid.isEmpty {
            return ssid
        }

        if let ssidData = wifiInterface.ssidData(),
           let ssid = String(data: ssidData, encoding: .utf8),
           !ssid.isEmpty {
            return ssid
        }

        return nil
    }

    private static func isRedacted(_ ssid: String) -> Bool {
        ssid == "<redacted>" || ssid == "redacted" || ssid == "Wi-Fi" || ssid == "WLAN"
    }

    private static func snapshot(
        state: String,
        allowed: Bool,
        device: String?,
        ssid: String?,
        reason: String,
        authorization: String,
        isExpensive: Bool,
        isConstrained: Bool
    ) -> NetworkSnapshot {
        NetworkSnapshot(
            state: state,
            allowed: allowed,
            device: device,
            ssid: ssid,
            reason: reason,
            location_authorization: authorization,
            is_expensive: isExpensive,
            is_constrained: isConstrained,
            deny_ssids: Array(Config.denySSIDs).sorted()
        )
    }
}

struct CommandResult {
    var status: Int32
    var stdout: String
    var stderr: String
    var timedOut: Bool = false
}

enum CommandRunner {
    static func findExecutable(_ name: String) -> String? {
        for directory in Config.executableSearchPath {
            let candidate = "\(directory)/\(name)"
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    static func run(
        _ executable: String,
        arguments: [String],
        environment: [String: String]? = nil,
        timeoutSeconds: Int? = nil
    ) throws -> CommandResult {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        let semaphore = DispatchSemaphore(value: 0)

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let environment {
            process.environment = environment
        }
        process.standardOutput = stdout
        process.standardError = stderr
        if timeoutSeconds != nil {
            process.terminationHandler = { _ in
                semaphore.signal()
            }
        }

        try process.run()
        var timedOut = false
        if let timeoutSeconds {
            if semaphore.wait(timeout: .now() + .seconds(timeoutSeconds)) == .timedOut {
                timedOut = true
                process.terminate()
                if semaphore.wait(timeout: .now() + .seconds(5)) == .timedOut {
                    kill(process.processIdentifier, SIGKILL)
                    _ = semaphore.wait(timeout: .now() + .seconds(5))
                }
            }
        } else {
            process.waitUntilExit()
        }

        let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()

        return CommandResult(
            status: timedOut ? 124 : process.terminationStatus,
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? "",
            timedOut: timedOut
        )
    }
}

enum KopiaCommand {
    static func snapshotCreateArguments() -> [String] {
        var arguments: [String] = []
        if let configFile = Config.kopiaConfigFile {
            arguments += ["--config-file", configFile]
        }
        arguments += ["snapshot", "create", "--no-progress", Config.backupSource]
        return arguments
    }

    static func display(_ executableName: String = "kopia", arguments: [String]) -> String {
        ([executableName] + arguments).map(shellQuote).joined(separator: " ")
    }

    private static func shellQuote(_ value: String) -> String {
        if value.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'\\$"))) == nil {
            return value
        }
        return "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

struct ActiveRunRecord: Codable {
    var run_id: String
    var app_pid: Int32
    var child_pid: Int32?
    var executable: String
    var command: [String]
    var backup_source: String
    var started_at: String
    var updated_at: String
}

struct InternalKopiaActivitySnapshot: Codable {
    var probe_enabled: Bool
    var confidence: String
    var summary: String?
    var latest_activity_at: String?
    var source_type: String?
    var source_path: String?
    var idle_seconds: Int?
    var stdout_idle_seconds: Int?
    var active_pid: Int32?
    var active_run_id: String?
    var run_started_at: String?
    var used_fallback_run_start: Bool
    var unavailable_reason: String?
    var recent_upload_bytes: Int64?
    var content_activity_count: Int
    var scanned_log_count: Int

    static func inactive() -> InternalKopiaActivitySnapshot {
        InternalKopiaActivitySnapshot(
            probe_enabled: Config.internalKopiaActivityProbeEnabled,
            confidence: "none",
            summary: nil,
            latest_activity_at: nil,
            source_type: nil,
            source_path: nil,
            idle_seconds: nil,
            stdout_idle_seconds: nil,
            active_pid: nil,
            active_run_id: nil,
            run_started_at: nil,
            used_fallback_run_start: false,
            unavailable_reason: "no active COPYA-owned Kopia run",
            recent_upload_bytes: nil,
            content_activity_count: 0,
            scanned_log_count: 0
        )
    }

    static func unavailable(
        enabled: Bool = Config.internalKopiaActivityProbeEnabled,
        reason: String,
        activePID: Int32?,
        activeRunID: String?,
        runStartedAt: Date?,
        usedFallbackRunStart: Bool,
        stdoutAt: Date?,
        now: Date = Date(),
        scannedLogCount: Int = 0
    ) -> InternalKopiaActivitySnapshot {
        InternalKopiaActivitySnapshot(
            probe_enabled: enabled,
            confidence: enabled ? "unavailable" : "disabled",
            summary: nil,
            latest_activity_at: nil,
            source_type: nil,
            source_path: nil,
            idle_seconds: nil,
            stdout_idle_seconds: stdoutAt.map { max(0, Int(now.timeIntervalSince($0))) },
            active_pid: activePID,
            active_run_id: activeRunID,
            run_started_at: runStartedAt.map { DateFormatters.iso.string(from: $0) },
            used_fallback_run_start: usedFallbackRunStart,
            unavailable_reason: reason,
            recent_upload_bytes: nil,
            content_activity_count: 0,
            scanned_log_count: scannedLogCount
        )
    }
}

private struct InternalKopiaActivityEvent {
    var date: Date
    var summary: String
    var sourceType: String
    var sourcePath: String
    var uploadBytes: Int64?
}

enum InternalKopiaActivityProbe {
    static func scan(
        activePID: Int32?,
        activeRunID: String?,
        activeRunRecord: ActiveRunRecord?,
        fallbackRunStartedAt: Date?,
        stdoutAt: Date?,
        now: Date = Date()
    ) -> InternalKopiaActivitySnapshot {
        guard Config.internalKopiaActivityProbeEnabled else {
            return InternalKopiaActivitySnapshot.unavailable(
                enabled: false,
                reason: "internal Kopia activity probe disabled",
                activePID: activePID,
                activeRunID: activeRunID,
                runStartedAt: fallbackRunStartedAt,
                usedFallbackRunStart: fallbackRunStartedAt != nil,
                stdoutAt: stdoutAt,
                now: now
            )
        }

        guard let activePID else {
            return .inactive()
        }

        let runContext = resolvedRunContext(
            activePID: activePID,
            activeRunID: activeRunID,
            activeRunRecord: activeRunRecord,
            fallbackRunStartedAt: fallbackRunStartedAt
        )
        guard let runStartedAt = runContext.startedAt else {
            return InternalKopiaActivitySnapshot.unavailable(
                reason: "missing active run start timestamp",
                activePID: activePID,
                activeRunID: runContext.runID,
                runStartedAt: nil,
                usedFallbackRunStart: false,
                stdoutAt: stdoutAt,
                now: now
            )
        }

        let fileManager = FileManager.default
        let existingDirs = Config.internalKopiaLogDirs.filter { path in
            var isDirectory = ObjCBool(false)
            return fileManager.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
        }
        guard !existingDirs.isEmpty else {
            return InternalKopiaActivitySnapshot.unavailable(
                enabled: false,
                reason: "configured Kopia log directories do not exist",
                activePID: activePID,
                activeRunID: runContext.runID,
                runStartedAt: runStartedAt,
                usedFallbackRunStart: runContext.usedFallback,
                stdoutAt: stdoutAt,
                now: now
            )
        }

        let tolerance = TimeInterval(Config.internalKopiaLogMtimeToleranceSeconds)
        let minEligibleDate = runStartedAt.addingTimeInterval(-tolerance)
        let files = eligibleLogFiles(
            in: existingDirs,
            activePID: activePID,
            minEligibleDate: minEligibleDate
        )

        guard !files.isEmpty else {
            return InternalKopiaActivitySnapshot.unavailable(
                reason: "no per-PID Kopia logs found for active run",
                activePID: activePID,
                activeRunID: runContext.runID,
                runStartedAt: runStartedAt,
                usedFallbackRunStart: runContext.usedFallback,
                stdoutAt: stdoutAt,
                now: now
            )
        }

        var latestEvent: InternalKopiaActivityEvent?
        var latestMTime: (date: Date, sourceType: String, sourcePath: String)?
        var recentUploadBytes: Int64 = 0
        var uploadEventCount = 0
        var contentActivityCount = 0

        for file in files {
            if latestMTime == nil || file.modifiedAt > latestMTime!.date {
                latestMTime = (file.modifiedAt, file.sourceType, file.url.path)
            }
            let parsed = parseTail(
                url: file.url,
                sourceType: file.sourceType,
                minEligibleDate: minEligibleDate,
                fallbackDate: file.modifiedAt
            )
            contentActivityCount += parsed.contentActivityCount
            recentUploadBytes += parsed.uploadBytes
            uploadEventCount += parsed.uploadEventCount
            if let event = parsed.latestEvent,
               latestEvent == nil || event.date > latestEvent!.date {
                latestEvent = event
            }
        }

        let selectedEvent: InternalKopiaActivityEvent
        let confidence: String
        if let latestEvent {
            selectedEvent = latestEvent
            confidence = "internal-log"
        } else if let latestMTime {
            selectedEvent = InternalKopiaActivityEvent(
                date: latestMTime.date,
                summary: "Kopia log updated",
                sourceType: latestMTime.sourceType,
                sourcePath: latestMTime.sourcePath,
                uploadBytes: nil
            )
            confidence = "internal-log-mtime"
        } else {
            return InternalKopiaActivitySnapshot.unavailable(
                reason: "per-PID Kopia logs were unreadable",
                activePID: activePID,
                activeRunID: runContext.runID,
                runStartedAt: runStartedAt,
                usedFallbackRunStart: runContext.usedFallback,
                stdoutAt: stdoutAt,
                now: now,
                scannedLogCount: files.count
            )
        }

        return InternalKopiaActivitySnapshot(
            probe_enabled: true,
            confidence: confidence,
            summary: selectedEvent.summary,
            latest_activity_at: DateFormatters.iso.string(from: selectedEvent.date),
            source_type: selectedEvent.sourceType,
            source_path: selectedEvent.sourcePath,
            idle_seconds: max(0, Int(now.timeIntervalSince(selectedEvent.date))),
            stdout_idle_seconds: stdoutAt.map { max(0, Int(now.timeIntervalSince($0))) },
            active_pid: activePID,
            active_run_id: runContext.runID,
            run_started_at: DateFormatters.iso.string(from: runStartedAt),
            used_fallback_run_start: runContext.usedFallback,
            unavailable_reason: nil,
            recent_upload_bytes: uploadEventCount == 0 ? selectedEvent.uploadBytes : recentUploadBytes,
            content_activity_count: contentActivityCount,
            scanned_log_count: files.count
        )
    }

    private static func resolvedRunContext(
        activePID: Int32,
        activeRunID: String?,
        activeRunRecord: ActiveRunRecord?,
        fallbackRunStartedAt: Date?
    ) -> (runID: String?, startedAt: Date?, usedFallback: Bool) {
        if let record = activeRunRecord,
           record.child_pid == activePID,
           activeRunID.map({ record.run_id == $0 }) ?? true,
           let startedAt = parseISODate(record.started_at) {
            return (record.run_id, startedAt, false)
        }

        if let fallbackRunStartedAt {
            return (activeRunID ?? activeRunRecord?.run_id, fallbackRunStartedAt, true)
        }

        return (activeRunID ?? activeRunRecord?.run_id, nil, false)
    }

    private static func eligibleLogFiles(
        in dirs: [String],
        activePID: Int32,
        minEligibleDate: Date
    ) -> [(url: URL, sourceType: String, modifiedAt: Date)] {
        let fileManager = FileManager.default
        let pidNeedle = "-\(activePID)-snapshot-create."
        var files: [(URL, String, Date)] = []

        for dir in dirs {
            let dirURL = URL(fileURLWithPath: dir)
            guard let children = try? fileManager.contentsOfDirectory(
                at: dirURL,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            let sourceType = dirURL.lastPathComponent == "content-logs" ? "content-log" : "cli-log"
            for url in children {
                let name = url.lastPathComponent
                guard name.hasPrefix("kopia-"),
                      name.contains(pidNeedle),
                      name.hasSuffix(".log") else {
                    continue
                }
                let modifiedAt = ((try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate) ?? Date.distantPast
                guard modifiedAt >= minEligibleDate else {
                    continue
                }
                files.append((url, sourceType, modifiedAt))
            }
        }

        return files.sorted { left, right in
            left.2 > right.2
        }
    }

    private static func parseTail(
        url: URL,
        sourceType: String,
        minEligibleDate: Date,
        fallbackDate: Date
    ) -> (latestEvent: InternalKopiaActivityEvent?, uploadBytes: Int64, uploadEventCount: Int, contentActivityCount: Int) {
        guard let text = readTail(url: url) else {
            return (nil, 0, 0, 0)
        }

        var latestEvent: InternalKopiaActivityEvent?
        var uploadBytes: Int64 = 0
        var uploadEventCount = 0
        var contentActivityCount = 0

        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let event = parseEvent(
                String(line),
                sourceType: sourceType,
                sourcePath: url.path,
                fallbackDate: fallbackDate
            ) else {
                continue
            }
            guard event.date >= minEligibleDate else {
                continue
            }
            if event.summary == "upload activity", let bytes = event.uploadBytes {
                uploadBytes += bytes
                uploadEventCount += 1
            }
            if event.summary == "content write activity"
                || event.summary == "packing content"
                || event.summary == "upload activity" {
                contentActivityCount += 1
            }
            if latestEvent == nil || event.date > latestEvent!.date {
                latestEvent = event
            }
        }

        return (latestEvent, uploadBytes, uploadEventCount, contentActivityCount)
    }

    private static func readTail(url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        defer {
            try? handle.close()
        }

        let endOffset = (try? handle.seekToEnd()) ?? 0
        let tailBytes = UInt64(max(4096, Config.internalKopiaLogTailBytes))
        let startOffset = endOffset > tailBytes ? endOffset - tailBytes : 0
        try? handle.seek(toOffset: startOffset)
        let data = handle.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    private static func parseEvent(
        _ line: String,
        sourceType: String,
        sourcePath: String,
        fallbackDate: Date
    ) -> InternalKopiaActivityEvent? {
        let parsedObject = parseJSONObject(from: line)
        let message = (parsedObject?["m"] as? String)
            ?? (parsedObject?["message"] as? String)
            ?? (line.contains("PutBlob") ? "PutBlob" : nil)
        let eventDate = parseEventDate(line: line, object: parsedObject) ?? fallbackDate

        if message == "PutBlob" || line.contains("PutBlob") {
            if let object = parsedObject,
               let error = object["error"],
               !(error is NSNull) {
                return nil
            }
            let length = numericInt64(parsedObject?["length"])
            return InternalKopiaActivityEvent(
                date: eventDate,
                summary: "upload activity",
                sourceType: sourceType,
                sourcePath: sourcePath,
                uploadBytes: length
            )
        }

        if message == "write-content-new" {
            return InternalKopiaActivityEvent(
                date: eventDate,
                summary: "content write activity",
                sourceType: sourceType,
                sourcePath: sourcePath,
                uploadBytes: nil
            )
        }

        if message == "add-to-pack" {
            return InternalKopiaActivityEvent(
                date: eventDate,
                summary: "packing content",
                sourceType: sourceType,
                sourcePath: sourcePath,
                uploadBytes: nil
            )
        }

        if line.contains("snapshotted directory") {
            return InternalKopiaActivityEvent(
                date: eventDate,
                summary: "snapshotted directory",
                sourceType: sourceType,
                sourcePath: sourcePath,
                uploadBytes: nil
            )
        }

        return nil
    }

    private static func parseJSONObject(from line: String) -> [String: Any]? {
        guard let jsonStart = line.firstIndex(of: "{") else {
            return nil
        }
        let jsonText = String(line[jsonStart...])
        guard let data = jsonText.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object
    }

    private static func parseEventDate(line: String, object: [String: Any]?) -> Date? {
        if let value = object?["ts"] as? String,
           let date = parseISODate(value) {
            return date
        }

        guard let firstToken = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).first else {
            return nil
        }
        return parseISODate(String(firstToken))
    }

    private static func parseISODate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private static func numericInt64(_ value: Any?) -> Int64? {
        if let value = value as? Int64 {
            return value
        }
        if let value = value as? Int {
            return Int64(value)
        }
        if let value = value as? NSNumber {
            return value.int64Value
        }
        if let value = value as? String {
            return Int64(value)
        }
        return nil
    }
}

struct KopiaProcessInfo: Codable, Equatable {
    var pid: Int32
    var parent_pid: Int32
    var command: String
}

struct KopiaProcessScan {
    var succeeded: Bool
    var processes: [KopiaProcessInfo]
    var error: String?
}

struct ReconciledKopiaState {
    var owned: KopiaProcessInfo?
    var starting: ActiveRunRecord?
    var external: [KopiaProcessInfo]
    var staleActiveRunRecord: Bool
}

enum ProcessInspector {
    static func scanKopiaSnapshots() -> KopiaProcessScan {
        do {
            let result = try CommandRunner.run(
                "/usr/bin/pgrep",
                arguments: [
                    "-flx",
                    ".*kopia.*snapshot.*create.*",
                ],
                timeoutSeconds: 10
            )
            guard result.status == 0 || result.status == 1 else {
                return KopiaProcessScan(
                    succeeded: false,
                    processes: [],
                    error: sanitizedScanError(result.stderr, fallback: "pgrep exited \(result.status)")
                )
            }

            let processes = result.stdout
                .split(separator: "\n")
                .compactMap(parsePgrepLine)
                .filter { isMatchingKopiaSnapshot(command: $0.command) }
            return KopiaProcessScan(succeeded: true, processes: processes, error: nil)
        } catch {
            return KopiaProcessScan(
                succeeded: false,
                processes: [],
                error: error.localizedDescription
            )
        }
    }

    static func matchingKopiaSnapshots() -> [KopiaProcessInfo] {
        scanKopiaSnapshots().processes
    }

    static func isMatchingKopiaSnapshot(command: String) -> Bool {
        let arguments = shellLikeWords(command)
        guard let kopiaIndex = arguments.firstIndex(where: { argument in
            argument == "kopia" || argument.hasSuffix("/kopia")
        }) else {
            return false
        }

        let kopiaArguments = Array(arguments.dropFirst(kopiaIndex + 1))
        guard kopiaArguments.contains("snapshot"),
              kopiaArguments.contains("create") else {
            return false
        }

        return true
    }

    static func terminate(pids: [Int32]) {
        for pid in pids {
            kill(pid, SIGTERM)
        }
    }

    static func forceTerminate(pids: [Int32]) {
        for pid in pids {
            kill(pid, SIGKILL)
        }
    }

    private static func parsePgrepLine(_ line: Substring) -> KopiaProcessInfo? {
        let fields = line
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(maxSplits: 1, whereSeparator: { $0 == " " || $0 == "\t" })
        guard fields.count == 2,
              let pid = Int32(String(fields[0])) else {
            return nil
        }
        return KopiaProcessInfo(
            pid: pid,
            parent_pid: 0,
            command: String(fields[1])
        )
    }

    private static func shellLikeWords(_ command: String) -> [String] {
        var words: [String] = []
        var current = ""
        var quote: Character?
        var escaping = false

        for character in command {
            if escaping {
                current.append(character)
                escaping = false
                continue
            }
            if character == "\\" {
                escaping = true
                continue
            }
            if let activeQuote = quote {
                if character == activeQuote {
                    quote = nil
                } else {
                    current.append(character)
                }
                continue
            }
            if character == "\"" || character == "'" {
                quote = character
                continue
            }
            if character.isWhitespace {
                if !current.isEmpty {
                    words.append(current)
                    current = ""
                }
                continue
            }
            current.append(character)
        }

        if !current.isEmpty {
            words.append(current)
        }
        return words
    }

    private static func sanitizedScanError(_ stderr: String, fallback: String) -> String {
        stderr
            .split(separator: "\n")
            .last
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? fallback
    }
}

enum ProcessReconciler {
    static func reconcile(
        matching processes: [KopiaProcessInfo],
        activeRunRecord: ActiveRunRecord?
    ) -> ReconciledKopiaState {
        guard let activeRunRecord else {
            return ReconciledKopiaState(
                owned: nil,
                starting: nil,
                external: processes,
                staleActiveRunRecord: false
            )
        }

        guard activeRunRecord.backup_source == Config.backupSource,
              activeRunRecord.command == KopiaCommand.snapshotCreateArguments() else {
            return ReconciledKopiaState(
                owned: nil,
                starting: nil,
                external: processes,
                staleActiveRunRecord: true
            )
        }

        if let childPID = activeRunRecord.child_pid,
           let owned = processes.first(where: { $0.pid == childPID }) {
            return ReconciledKopiaState(
                owned: owned,
                starting: nil,
                external: processes.filter { $0.pid != owned.pid },
                staleActiveRunRecord: false
            )
        }

        if activeRunRecord.child_pid == nil,
           let updatedAt = DateFormatters.iso.date(from: activeRunRecord.updated_at),
           Date().timeIntervalSince(updatedAt) < 300 {
            return ReconciledKopiaState(
                owned: nil,
                starting: activeRunRecord,
                external: processes,
                staleActiveRunRecord: false
            )
        }

        return ReconciledKopiaState(
            owned: nil,
            starting: nil,
            external: processes,
            staleActiveRunRecord: true
        )
    }
}

struct VolumeCapacitySnapshot {
    var volume_key: String
    var checked_path: String
    var available_bytes: Int64?
    var capacity_api: String
    var error: String?
}

enum DiskSpaceProbe {
    static func snapshot(
        paths: [String],
        requiredBytes: Int64,
        thresholdKind: String
    ) -> DiskHealthSnapshot {
        let results = paths.map { path in
            check(path: path, requiredBytes: requiredBytes, thresholdKind: thresholdKind)
        }
        let failing = results.first { !$0.ok }
        return DiskHealthSnapshot(
            checked_at: DateFormatters.iso.string(from: Date()),
            ok: failing == nil,
            threshold_kind: thresholdKind,
            required_bytes: requiredBytes,
            failing_path: failing?.path,
            failing_free_bytes: failing?.free_bytes,
            reason: failing.map(diskFailureReason),
            results: results
        )
    }

    private static func check(
        path: String,
        requiredBytes: Int64,
        thresholdKind: String
    ) -> DiskSpaceCheckResult {
        let snapshot = volumeSnapshot(for: path, preferImportantUsage: false)
        let ok = snapshot.available_bytes.map { $0 >= requiredBytes } ?? false
        return DiskSpaceCheckResult(
            path: path,
            checked_path: snapshot.checked_path,
            volume_key: snapshot.volume_key,
            free_bytes: snapshot.available_bytes,
            required_bytes: requiredBytes,
            threshold_kind: thresholdKind,
            ok: ok,
            error: snapshot.error ?? (snapshot.available_bytes == nil ? "free space unavailable" : nil)
        )
    }

    static func volumeSnapshot(for path: String, preferImportantUsage: Bool = true) -> VolumeCapacitySnapshot {
        let checkedPath = nearestExistingPath(for: path)
        let url = URL(fileURLWithPath: checkedPath)
        var resourceVolumeKey: String?
        var importantBytes: Int64?
        if preferImportantUsage,
           let values = try? url.resourceValues(forKeys: [.volumeIdentifierKey, .volumeAvailableCapacityForImportantUsageKey]) {
            resourceVolumeKey = values.volumeIdentifier.map { String(describing: $0) }
            importantBytes = values.volumeAvailableCapacityForImportantUsage
        }

        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: checkedPath)
            let filesystemBytes = int64Value(attributes[.systemFreeSize])
            let filesystemVolumeKey = attributes[.systemNumber].map { String(describing: $0) }
            let volumeKey = resourceVolumeKey ?? filesystemVolumeKey ?? checkedPath
            if let importantBytes {
                return VolumeCapacitySnapshot(
                    volume_key: volumeKey,
                    checked_path: checkedPath,
                    available_bytes: importantBytes,
                    capacity_api: "important_usage",
                    error: nil
                )
            }
            return VolumeCapacitySnapshot(
                volume_key: volumeKey,
                checked_path: checkedPath,
                available_bytes: filesystemBytes,
                capacity_api: "filesystem_fallback",
                error: filesystemBytes == nil ? "free space unavailable" : nil
            )
        } catch {
            if let importantBytes {
                return VolumeCapacitySnapshot(
                    volume_key: resourceVolumeKey ?? checkedPath,
                    checked_path: checkedPath,
                    available_bytes: importantBytes,
                    capacity_api: "important_usage",
                    error: nil
                )
            }
            return VolumeCapacitySnapshot(
                volume_key: resourceVolumeKey ?? checkedPath,
                checked_path: checkedPath,
                available_bytes: nil,
                capacity_api: "unavailable",
                error: error.localizedDescription
            )
        }
    }

    static func nearestExistingPath(for path: String) -> String {
        let fileManager = FileManager.default
        var url = URL(fileURLWithPath: path)
        if fileManager.fileExists(atPath: url.path) {
            return url.path
        }

        while url.path != "/" {
            url.deleteLastPathComponent()
            if fileManager.fileExists(atPath: url.path) {
                return url.path
            }
        }
        return "/"
    }

    private static func int64Value(_ value: Any?) -> Int64? {
        if let value = value as? NSNumber {
            return value.int64Value
        }
        if let value = value as? Int64 {
            return value
        }
        if let value = value as? Int {
            return Int64(value)
        }
        return nil
    }

    private static func diskFailureReason(_ result: DiskSpaceCheckResult) -> String {
        if let freeBytes = result.free_bytes {
            return "only \(freeBytes) bytes free for \(result.path); requires \(result.required_bytes) bytes"
        }
        if let error = result.error {
            return "unable to read free space for \(result.path): \(error)"
        }
        return "unable to read free space for \(result.path)"
    }
}

struct CloudCapacityVolumeAccumulator {
    var volumeKey: String
    var checkedPath: String
    var availableBytes: Int64?
    var capacityAPI: String
    var error: String?
    var executionReserveBytes: Int64 = 0
    var iCloudKnownBytes: Int64 = 0
    var iCloudUnknownFallbackBytes: Int64 = 0

    var requiredBytes: Int64 {
        executionReserveBytes + iCloudKnownBytes + iCloudUnknownFallbackBytes
    }

    var ok: Bool {
        guard let availableBytes else {
            return false
        }
        return availableBytes >= requiredBytes
    }
}

enum CloudCapacityEstimator {
    static func estimate(
        roots: [String],
        executionPaths: [String]
    ) -> CloudCapacityEstimate {
        var volumeAccumulators: [String: CloudCapacityVolumeAccumulator] = [:]
        var rootEstimates: [CloudCapacityRootEstimate] = []

        for path in executionPaths {
            var accumulator = accumulatorForPath(path, in: &volumeAccumulators)
            accumulator.executionReserveBytes = max(accumulator.executionReserveBytes, Config.minimumExecutionReserveBytes)
            volumeAccumulators[accumulator.volumeKey] = accumulator
        }

        for root in roots {
            rootEstimates.append(estimateRoot(root, volumeAccumulators: &volumeAccumulators))
        }

        let volumes = volumeAccumulators.values
            .sorted { $0.volumeKey < $1.volumeKey }
            .map { accumulator in
                CloudCapacityVolumeEstimate(
                    volume_key: accumulator.volumeKey,
                    checked_path: accumulator.checkedPath,
                    available_bytes: accumulator.availableBytes,
                    required_bytes: accumulator.requiredBytes,
                    execution_reserve_bytes: accumulator.executionReserveBytes,
                    icloud_known_bytes: accumulator.iCloudKnownBytes,
                    icloud_unknown_fallback_bytes: accumulator.iCloudUnknownFallbackBytes,
                    ok: accumulator.ok,
                    capacity_api: accumulator.capacityAPI,
                    error: accumulator.error
                )
            }

        let iCloudKnownBytes = rootEstimates.reduce(Int64(0)) { $0 + $1.icloud_known_bytes }
        let iCloudUnknownCount = rootEstimates.reduce(0) { $0 + $1.icloud_unknown_count }
        let iCloudUnknownFallbackBytes = rootEstimates.reduce(Int64(0)) { $0 + $1.icloud_unknown_fallback_bytes }
        let fileProviderKnownBytes = rootEstimates.reduce(Int64(0)) { $0 + $1.fileprovider_advisory_known_bytes }
        let fileProviderUnknownCount = rootEstimates.reduce(0) { $0 + $1.fileprovider_advisory_unknown_count }
        let localUnknownCount = rootEstimates.reduce(0) { $0 + $1.local_unknown_count }
        let failingVolume = volumes.first { !$0.ok }
        var warnings: [String] = []
        if iCloudUnknownCount > 0 {
            warnings.append("icloud_unknown_sizes_fallback")
        }
        if fileProviderKnownBytes > 0 || fileProviderUnknownCount > 0 {
            warnings.append("fileprovider_advisory_placeholders")
        }
        if localUnknownCount > 0 {
            warnings.append("local_unknown_placeholders")
        }
        if volumes.contains(where: { $0.capacity_api == "filesystem_fallback" }) {
            warnings.append("capacity_filesystem_fallback")
        }
        if volumes.contains(where: { $0.capacity_api == "unavailable" }) {
            warnings.append("capacity_unavailable")
        }

        let ok = failingVolume == nil
        let confidence: String
        if !ok {
            confidence = "insufficient"
        } else if warnings.isEmpty {
            confidence = "high"
        } else {
            confidence = "degraded"
        }

        return CloudCapacityEstimate(
            checked_at: DateFormatters.iso.string(from: Date()),
            ok: ok,
            confidence: confidence,
            reason: failingVolume.map(capacityFailureReason),
            execution_reserve_bytes: Config.minimumExecutionReserveBytes,
            unknown_icloud_placeholder_estimate_bytes: Config.unknownICloudPlaceholderEstimateBytes,
            icloud_known_bytes: iCloudKnownBytes,
            icloud_unknown_count: iCloudUnknownCount,
            icloud_unknown_fallback_bytes: iCloudUnknownFallbackBytes,
            fileprovider_advisory_known_bytes: fileProviderKnownBytes,
            fileprovider_advisory_unknown_count: fileProviderUnknownCount,
            local_unknown_count: localUnknownCount,
            capacity_api: capacityAPISummary(volumes),
            warnings: warnings,
            roots: rootEstimates,
            volumes: volumes
        )
    }

    private static func estimateRoot(
        _ root: String,
        volumeAccumulators: inout [String: CloudCapacityVolumeAccumulator]
    ) -> CloudCapacityRootEstimate {
        let rootURL = URL(fileURLWithPath: root)
        var isDirectory = ObjCBool(false)
        let exists = FileManager.default.fileExists(atPath: root, isDirectory: &isDirectory)
        var provider = CloudPlaceholderClassifier.providerClass(forRoot: root)
        var datalessPlaceholders = 0
        var iCloudKnownBytes: Int64 = 0
        var iCloudUnknownCount = 0
        var fileProviderKnownBytes: Int64 = 0
        var fileProviderUnknownCount = 0
        var localUnknownCount = 0
        var samplePaths: [String] = []
        var errors: [String] = []
        let rootVolume = DiskSpaceProbe.volumeSnapshot(for: root)

        func rememberSample(_ path: String) {
            if samplePaths.count < 5 {
                samplePaths.append(path)
            }
        }

        func rememberError(_ message: String) {
            if errors.count < 5 {
                errors.append(message)
            }
        }

        guard exists else {
            return CloudCapacityRootEstimate(
                root: root,
                exists: false,
                provider: provider,
                volume_key: rootVolume.volume_key,
                dataless_placeholders: 0,
                icloud_known_bytes: 0,
                icloud_unknown_count: 0,
                icloud_unknown_fallback_bytes: 0,
                fileprovider_advisory_known_bytes: 0,
                fileprovider_advisory_unknown_count: 0,
                local_unknown_count: 0,
                sample_paths: [],
                errors: []
            )
        }

        let keys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .isPackageKey,
            .isRegularFileKey,
            .fileSizeKey,
            .isUbiquitousItemKey,
            .volumeIdentifierKey,
        ]

        func recordPlaceholder(
            _ placeholder: CloudPlaceholderRecord,
            values: URLResourceValues?,
            statSnapshot: FileFlags.Snapshot
        ) {
            datalessPlaceholders += 1
            rememberSample(placeholder.path)
            let fileProvider = CloudPlaceholderClassifier.providerClass(
                for: URL(fileURLWithPath: placeholder.path),
                root: root,
                values: values
            )
            if fileProvider == "icloud_actionable" {
                provider = "icloud_actionable"
                let fileVolume = DiskSpaceProbe.volumeSnapshot(for: placeholder.path)
                var accumulator = accumulatorForVolume(
                    fileVolume.volume_key,
                    fallbackPath: fileVolume.checked_path,
                    volumeAccumulators: &volumeAccumulators
                )
                if let logicalBytes = logicalSize(values: values, statSnapshot: statSnapshot) {
                    iCloudKnownBytes += logicalBytes
                    accumulator.iCloudKnownBytes += logicalBytes
                } else {
                    iCloudUnknownCount += 1
                    accumulator.iCloudUnknownFallbackBytes += Config.unknownICloudPlaceholderEstimateBytes
                }
                volumeAccumulators[accumulator.volumeKey] = accumulator
            } else if fileProvider == "fileprovider_advisory" {
                provider = provider == "icloud_actionable" ? provider : "fileprovider_advisory"
                if let logicalBytes = logicalSize(values: values, statSnapshot: statSnapshot) {
                    fileProviderKnownBytes += logicalBytes
                } else {
                    fileProviderUnknownCount += 1
                }
            } else {
                localUnknownCount += 1
            }
        }

        let rootValues = try? rootURL.resourceValues(forKeys: keys)
        if let rootStatSnapshot = FileFlags.snapshot(for: rootURL),
           let rootPlaceholder = CloudPlaceholderClassifier.record(
                for: rootURL,
                root: root,
                values: rootValues,
                statSnapshot: rootStatSnapshot
           ) {
            recordPlaceholder(rootPlaceholder, values: rootValues, statSnapshot: rootStatSnapshot)
            if rootPlaceholder.kind == .directory || rootPlaceholder.kind == .package {
                return CloudCapacityRootEstimate(
                    root: root,
                    exists: true,
                    provider: provider,
                    volume_key: rootVolume.volume_key,
                    dataless_placeholders: datalessPlaceholders,
                    icloud_known_bytes: iCloudKnownBytes,
                    icloud_unknown_count: iCloudUnknownCount,
                    icloud_unknown_fallback_bytes: Int64(iCloudUnknownCount) * Config.unknownICloudPlaceholderEstimateBytes,
                    fileprovider_advisory_known_bytes: fileProviderKnownBytes,
                    fileprovider_advisory_unknown_count: fileProviderUnknownCount,
                    local_unknown_count: localUnknownCount,
                    sample_paths: samplePaths,
                    errors: errors
                )
            }
        }

        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: Array(keys),
            options: [],
            errorHandler: { url, error in
                rememberError("\(url.path): \(error.localizedDescription)")
                return true
            }
        ) else {
            rememberError("unable to enumerate \(root)")
            return CloudCapacityRootEstimate(
                root: root,
                exists: true,
                provider: provider,
                volume_key: rootVolume.volume_key,
                dataless_placeholders: 0,
                icloud_known_bytes: 0,
                icloud_unknown_count: 0,
                icloud_unknown_fallback_bytes: 0,
                fileprovider_advisory_known_bytes: 0,
                fileprovider_advisory_unknown_count: 0,
                local_unknown_count: 0,
                sample_paths: [],
                errors: errors
            )
        }

        for case let url as URL in enumerator {
            let statSnapshot = FileFlags.snapshot(for: url)
            guard let statSnapshot else {
                continue
            }

            let values = try? url.resourceValues(forKeys: keys)
            guard let placeholder = CloudPlaceholderClassifier.record(
                for: url,
                root: root,
                values: values,
                statSnapshot: statSnapshot
            ) else {
                continue
            }

            recordPlaceholder(placeholder, values: values, statSnapshot: statSnapshot)
            if placeholder.kind == .directory || placeholder.kind == .package {
                enumerator.skipDescendants()
            }
        }

        return CloudCapacityRootEstimate(
            root: root,
            exists: true,
            provider: provider,
            volume_key: rootVolume.volume_key,
            dataless_placeholders: datalessPlaceholders,
            icloud_known_bytes: iCloudKnownBytes,
            icloud_unknown_count: iCloudUnknownCount,
            icloud_unknown_fallback_bytes: Int64(iCloudUnknownCount) * Config.unknownICloudPlaceholderEstimateBytes,
            fileprovider_advisory_known_bytes: fileProviderKnownBytes,
            fileprovider_advisory_unknown_count: fileProviderUnknownCount,
            local_unknown_count: localUnknownCount,
            sample_paths: samplePaths,
            errors: errors
        )
    }

    private static func logicalSize(values: URLResourceValues?, statSnapshot: FileFlags.Snapshot) -> Int64? {
        if let fileSize = values?.fileSize, fileSize >= 0 {
            return Int64(fileSize)
        }
        if statSnapshot.size > 0 {
            return statSnapshot.size
        }
        return nil
    }

    private static func accumulatorForPath(
        _ path: String,
        in accumulators: inout [String: CloudCapacityVolumeAccumulator]
    ) -> CloudCapacityVolumeAccumulator {
        let snapshot = DiskSpaceProbe.volumeSnapshot(for: path)
        return accumulatorForVolume(
            snapshot.volume_key,
            fallbackPath: snapshot.checked_path,
            volumeAccumulators: &accumulators
        )
    }

    private static func accumulatorForVolume(
        _ volumeKey: String,
        fallbackPath: String,
        volumeAccumulators: inout [String: CloudCapacityVolumeAccumulator]
    ) -> CloudCapacityVolumeAccumulator {
        if let existing = volumeAccumulators[volumeKey] {
            return existing
        }
        let snapshot = DiskSpaceProbe.volumeSnapshot(for: fallbackPath)
        let accumulator = CloudCapacityVolumeAccumulator(
            volumeKey: volumeKey,
            checkedPath: snapshot.checked_path,
            availableBytes: snapshot.available_bytes,
            capacityAPI: snapshot.capacity_api,
            error: snapshot.error
        )
        volumeAccumulators[volumeKey] = accumulator
        return accumulator
    }

    private static func capacityFailureReason(_ volume: CloudCapacityVolumeEstimate) -> String {
        if let availableBytes = volume.available_bytes {
            return "only \(availableBytes) bytes available on \(volume.checked_path); requires \(volume.required_bytes) bytes"
        }
        if let error = volume.error {
            return "unable to read available capacity for \(volume.checked_path): \(error)"
        }
        return "unable to read available capacity for \(volume.checked_path)"
    }

    private static func capacityAPISummary(_ volumes: [CloudCapacityVolumeEstimate]) -> String {
        if volumes.contains(where: { $0.capacity_api == "unavailable" }) {
            return "unavailable"
        }
        if volumes.contains(where: { $0.capacity_api == "filesystem_fallback" }) {
            return "filesystem_fallback"
        }
        if volumes.isEmpty {
            return "unknown"
        }
        return "important_usage"
    }
}

struct KopiaFailureClassification {
    var kind: String
    var message: String
    var detail: String
    var priority: Int
}

enum KopiaFailureClassifier {
    static func classify(line: String) -> KopiaFailureClassification? {
        let lower = line.lowercased()
        if lower.contains("no space left on device") {
            return KopiaFailureClassification(
                kind: "disk_space_exhausted",
                message: "Kopia ran out of local disk space",
                detail: line,
                priority: 100
            )
        }
        if lower.contains("storage_cap_exceeded") {
            return KopiaFailureClassification(
                kind: "b2_storage_cap_exceeded",
                message: "B2 storage cap exceeded",
                detail: line,
                priority: 90
            )
        }
        if line.contains("Error when processing")
            && (lower.contains("operation not permitted") || lower.contains("permission denied")) {
            return KopiaFailureClassification(
                kind: "file_read_failure",
                message: "Kopia reported file read failures",
                detail: line,
                priority: 50
            )
        }
        return nil
    }

    static func generic(status: Int32) -> KopiaFailureClassification {
        KopiaFailureClassification(
            kind: "kopia_exit_status",
            message: "Kopia exited with status \(status)",
            detail: "status=\(status)",
            priority: 0
        )
    }
}

enum KopiaSnapshotResult {
    static let clean = "clean"
    static let partialTolerated = "partial_tolerated"
    static let partialActionRequired = "partial_action_required"
    static let failed = "failed"
}

enum KopiaIssueCategory {
    static let cloudPlaceholder = "cloud_placeholder"
    static let toleratedSystemEphemeral = "tolerated_system_ephemeral"
    static let actionableUserData = "actionable_user_data"
    static let unclassified = "unclassified"
}

enum PathPatternMatcher {
    static func normalizedRelativePath(_ path: String) -> String {
        var normalized = path
        let root = Config.backupSource + "/"
        if normalized.hasPrefix(root) {
            normalized.removeFirst(root.count)
        }
        while normalized.hasPrefix("/") {
            normalized.removeFirst()
        }
        return normalized
    }

    static func matchesAny(_ patterns: [String], relativePath: String) -> Bool {
        patterns.contains { pattern in
            matches(pattern: pattern, relativePath: relativePath)
        }
    }

    static func matches(pattern: String, relativePath: String) -> Bool {
        var normalizedPattern = pattern
        while normalizedPattern.hasPrefix("/") {
            normalizedPattern.removeFirst()
        }
        let normalizedPath = normalizedRelativePath(relativePath)
        return Darwin.fnmatch(normalizedPattern, normalizedPath, 0) == 0
    }
}

enum KopiaFileIssueClassifier {
    static func classify(line: String) -> KopiaSnapshotIssueSample? {
        guard line.contains("Error when processing") else {
            return nil
        }

        let path = extractProcessingPath(from: line)
        let relativePath = path.map(PathPatternMatcher.normalizedRelativePath)
        let lower = line.lowercased()

        if lower.contains("resource deadlock avoided"),
           let relativePath,
           isCloudMaterializationPath(relativePath) {
            return KopiaSnapshotIssueSample(
                category: KopiaIssueCategory.cloudPlaceholder,
                path: relativePath,
                detail: line
            )
        }

        if let relativePath,
           PathPatternMatcher.matchesAny(
               Config.backupToleratedEphemeralIgnorePatterns,
               relativePath: relativePath
           ) {
            return KopiaSnapshotIssueSample(
                category: KopiaIssueCategory.toleratedSystemEphemeral,
                path: relativePath,
                detail: line
            )
        }

        if let relativePath,
           isActionableUserDataPath(relativePath) {
            return KopiaSnapshotIssueSample(
                category: KopiaIssueCategory.actionableUserData,
                path: relativePath,
                detail: line
            )
        }

        return KopiaSnapshotIssueSample(
            category: KopiaIssueCategory.unclassified,
            path: relativePath,
            detail: line
        )
    }

    private static func extractProcessingPath(from line: String) -> String? {
        guard let startRange = line.range(of: "Error when processing \"") else {
            return nil
        }
        let remainder = line[startRange.upperBound...]
        guard let endIndex = remainder.firstIndex(of: "\"") else {
            return nil
        }
        return String(remainder[..<endIndex])
    }

    private static func isCloudMaterializationPath(_ relativePath: String) -> Bool {
        Config.cloudMaterializationRoots.contains { root in
            let relativeRoot = PathPatternMatcher.normalizedRelativePath(root)
            return relativePath == relativeRoot || relativePath.hasPrefix(relativeRoot + "/")
        }
    }

    private static func isActionableUserDataPath(_ relativePath: String) -> Bool {
        if relativePath.hasPrefix("Desktop/")
            || relativePath == "Desktop"
            || relativePath.hasPrefix("Documents/")
            || relativePath == "Documents"
            || relativePath.hasPrefix("Downloads/")
            || relativePath == "Downloads"
            || relativePath.hasPrefix("Library/Mobile Documents/")
            || relativePath == "Library/Mobile Documents"
            || relativePath.hasPrefix("Library/Mail/")
            || relativePath == "Library/Mail"
            || relativePath.hasPrefix("Library/Messages/")
            || relativePath == "Library/Messages"
            || relativePath.hasPrefix("Library/Safari/")
            || relativePath == "Library/Safari"
            || relativePath.hasPrefix("Pictures/Photos Library.photoslibrary/")
            || relativePath == "Pictures/Photos Library.photoslibrary"
            || relativePath.hasPrefix("Library/Containers/net.whatsapp.WhatsApp/") {
            return true
        }

        return false
    }
}

struct KopiaOutputObservation {
    var snapshotID: String?
    var snapshotRoot: String?
    var snapshotDuration: String?
    var fatalErrorCount: Int?
    var categoryCounts: [String: Int] = [:]
    var samples: [KopiaSnapshotIssueSample] = []

    mutating func observe(line: String) {
        if let created = Self.parseCreatedSnapshotLine(line) {
            snapshotRoot = created.root
            snapshotID = created.id
            snapshotDuration = created.duration
            return
        }

        if let fatalCount = Self.parseFatalErrorCount(line) {
            fatalErrorCount = fatalCount
            return
        }

        guard let issue = KopiaFileIssueClassifier.classify(line: line) else {
            return
        }

        categoryCounts[issue.category, default: 0] += 1
        if samples.count < 12 {
            samples.append(issue)
        }
    }

    func finish(
        status: Int32,
        runID: String?,
        pid: Int32?,
        startedAt: Date?,
        completedAt: Date
    ) -> KopiaParsedRun {
        var finalCounts = categoryCounts
        var finalSamples = samples
        let parsedIssueCount = categoryCounts.values.reduce(0, +)
        let fatalCount = max(fatalErrorCount ?? parsedIssueCount, parsedIssueCount)
        let missingNonZeroExitEvidence = status != 0 && snapshotID != nil && fatalCount == 0 && parsedIssueCount == 0
        let unparsedFatalCount = missingNonZeroExitEvidence ? 1 : max(0, fatalCount - parsedIssueCount)

        if unparsedFatalCount > 0 {
            finalCounts[KopiaIssueCategory.unclassified, default: 0] += unparsedFatalCount
            if finalSamples.count < 12 {
                finalSamples.append(
                    KopiaSnapshotIssueSample(
                        category: KopiaIssueCategory.unclassified,
                        path: nil,
                        detail: missingNonZeroExitEvidence
                            ? "Kopia exited with status \(status) after creating a snapshot, but COPYA found no per-file fatal evidence"
                            : "Kopia reported \(fatalCount) fatal errors but COPYA parsed \(parsedIssueCount) file error lines"
                    )
                )
            }
        }

        let toleratedCount =
            (finalCounts[KopiaIssueCategory.cloudPlaceholder] ?? 0)
            + (finalCounts[KopiaIssueCategory.toleratedSystemEphemeral] ?? 0)
        let unclassifiedCount = finalCounts[KopiaIssueCategory.unclassified] ?? 0
        let actionRequiredCount =
            (finalCounts[KopiaIssueCategory.actionableUserData] ?? 0)
            + unclassifiedCount

        let result: String
        if snapshotID == nil {
            result = KopiaSnapshotResult.failed
        } else if status == 0 && fatalCount == 0 {
            result = KopiaSnapshotResult.clean
        } else if actionRequiredCount > 0 {
            result = KopiaSnapshotResult.partialActionRequired
        } else {
            result = KopiaSnapshotResult.partialTolerated
        }

        return KopiaParsedRun(
            run_id: runID,
            pid: pid,
            started_at: startedAt.map(DateFormatters.iso.string(from:)),
            completed_at: DateFormatters.iso.string(from: completedAt),
            exit_status: status,
            snapshot_id: snapshotID,
            snapshot_root: snapshotRoot,
            snapshot_duration: snapshotDuration,
            snapshot_result: result,
            fatal_error_count: fatalCount,
            tolerated_count: toleratedCount,
            action_required_count: actionRequiredCount,
            unclassified_count: unclassifiedCount,
            categorized_counts: finalCounts,
            samples: finalSamples
        )
    }

    static func parseCreatedSnapshotLine(_ line: String) -> (root: String, id: String, duration: String)? {
        guard let rootRange = line.range(of: "Created snapshot with root ") else {
            return nil
        }
        let afterRoot = line[rootRange.upperBound...]
        guard let idRange = afterRoot.range(of: " and ID ") else {
            return nil
        }
        let root = String(afterRoot[..<idRange.lowerBound])
        let afterID = afterRoot[idRange.upperBound...]
        guard let durationRange = afterID.range(of: " in ") else {
            return nil
        }
        let id = String(afterID[..<durationRange.lowerBound])
        let duration = String(afterID[durationRange.upperBound...])
        return (root, id, duration)
    }

    static func parseFatalErrorCount(_ line: String) -> Int? {
        guard line.hasPrefix("Found "),
              let endRange = line.range(of: " fatal error") else {
            return nil
        }
        let countText = line[line.index(line.startIndex, offsetBy: 6)..<endRange.lowerBound]
        return Int(countText)
    }
}

enum KopiaRunLogReplayer {
    private struct ReplayRun {
        var runID: String?
        var pid: Int32?
        var startedAt: Date?
        var observation = KopiaOutputObservation()
    }

    static func latestCompletedRun(logFile: String = Config.rawKopiaLogFile) -> KopiaParsedRun? {
        guard let text = tailText(path: logFile, bytes: 64 * 1024 * 1024) else {
            if logFile != Config.logFile {
                return latestCompletedRun(logFile: Config.logFile)
            }
            return nil
        }
        return latestCompletedRun(in: text)
    }

    static func latestCompletedRun(in text: String) -> KopiaParsedRun? {
        var current: ReplayRun?
        var latest: KopiaParsedRun?
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let (date, event) = stripLogPrefix(String(rawLine))
            if event.contains("raw kopia output starting") || event.contains("kopia backup starting") {
                let existingObservation = current?.observation ?? KopiaOutputObservation()
                current = ReplayRun(
                    runID: value(after: "run_id=", in: event) ?? current?.runID,
                    pid: value(after: "pid=", in: event).flatMap(Int32.init) ?? current?.pid,
                    startedAt: date ?? current?.startedAt,
                    observation: existingObservation
                )
                continue
            }

            if current == nil && looksLikeKopiaOutput(event) {
                current = ReplayRun()
            }

            guard var run = current else {
                continue
            }

            if (event.hasPrefix("raw kopia output finished status=")
                || event.hasPrefix("kopia backup exit observed status=")),
               let status = value(after: "status=", in: event).flatMap(Int32.init) {
                latest = run.observation.finish(
                    status: status,
                    runID: run.runID,
                    pid: run.pid,
                    startedAt: run.startedAt,
                    completedAt: date ?? Date()
                )
                current = nil
                continue
            }

            run.observation.observe(line: event)
            current = run
        }

        return latest
    }

    private static func looksLikeKopiaOutput(_ line: String) -> Bool {
        line.hasPrefix("Snapshotting ")
            || line.hasPrefix("Error when processing ")
            || line.hasPrefix("Created snapshot with root ")
            || line.hasPrefix("Found ")
    }

    private static func tailText(path: String, bytes: UInt64) -> String? {
        let url = URL(fileURLWithPath: path)
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        defer {
            try? handle.close()
        }

        let endOffset = (try? handle.seekToEnd()) ?? 0
        let startOffset = endOffset > bytes ? endOffset - bytes : 0
        try? handle.seek(toOffset: startOffset)
        let data = handle.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    private static func stripLogPrefix(_ line: String) -> (Date?, String) {
        guard line.count > 25 else {
            return (nil, line)
        }
        let prefix = String(line.prefix(24))
        guard let date = DateFormatters.log.date(from: prefix) else {
            return (nil, line)
        }
        let eventStart = line.index(line.startIndex, offsetBy: 25)
        return (date, String(line[eventStart...]))
    }

    private static func value(after marker: String, in line: String) -> String? {
        guard let range = line.range(of: marker) else {
            return nil
        }
        let remainder = line[range.upperBound...]
        let end = remainder.firstIndex(where: { $0 == " " || $0 == "\t" }) ?? remainder.endIndex
        return String(remainder[..<end])
    }
}

struct KopiaLogPruneSummary {
    var removed_count: Int
    var removed_bytes: Int64
    var kept_inactive_bytes: Int64
    var preserved_live_count: Int
}

enum KopiaDiagnosticLogPruner {
    private struct LogFile {
        var url: URL
        var size: Int64
        var modifiedAt: Date
        var pid: Int32?
    }

    static func prune(
        logDirs: [String],
        retentionBytes: Int64,
        preservePIDs: Set<Int32>
    ) -> KopiaLogPruneSummary {
        guard retentionBytes > 0 else {
            return KopiaLogPruneSummary(
                removed_count: 0,
                removed_bytes: 0,
                kept_inactive_bytes: 0,
                preserved_live_count: 0
            )
        }

        let livePIDs = preservePIDs.union(Set(ProcessInspector.matchingKopiaSnapshots().map(\.pid)))
        let files = logDirs.flatMap(logFiles(in:))
        let preserved = files.filter { file in
            guard let pid = file.pid else {
                return false
            }
            return livePIDs.contains(pid)
        }
        let candidates = files
            .filter { file in
                guard let pid = file.pid else {
                    return true
                }
                return !livePIDs.contains(pid)
            }
            .sorted { left, right in
                left.modifiedAt > right.modifiedAt
            }

        var keptBytes: Int64 = 0
        var removedCount = 0
        var removedBytes: Int64 = 0
        for file in candidates {
            if keptBytes + file.size <= retentionBytes {
                keptBytes += file.size
                continue
            }
            do {
                try FileManager.default.removeItem(at: file.url)
                removedCount += 1
                removedBytes += file.size
            } catch {
                continue
            }
        }

        return KopiaLogPruneSummary(
            removed_count: removedCount,
            removed_bytes: removedBytes,
            kept_inactive_bytes: keptBytes,
            preserved_live_count: preserved.count
        )
    }

    private static func logFiles(in dir: String) -> [LogFile] {
        let url = URL(fileURLWithPath: dir)
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
            options: []
        ) else {
            return []
        }

        return urls.compactMap { fileURL in
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]),
                  values.isRegularFile == true else {
                return nil
            }
            return LogFile(
                url: fileURL,
                size: Int64(values.fileSize ?? 0),
                modifiedAt: values.contentModificationDate ?? Date.distantPast,
                pid: pid(from: fileURL.lastPathComponent)
            )
        }
    }

    private static func pid(from filename: String) -> Int32? {
        let parts = filename.split(separator: "-")
        guard parts.count >= 5,
              parts[0] == "kopia",
              parts[4] == "snapshot",
              let pid = Int32(parts[3]) else {
            return nil
        }
        return pid
    }
}

enum FileFlags {
    private static let sfDataless = UInt32(0x40000000)

    struct Snapshot {
        var flags: UInt32
        var size: Int64
        var mode: mode_t
    }

    static func snapshot(for url: URL) -> Snapshot? {
        url.path.withCString { path in
            var statBuffer = stat()
            guard lstat(path, &statBuffer) == 0 else {
                return nil
            }
            return Snapshot(
                flags: statBuffer.st_flags,
                size: Int64(statBuffer.st_size),
                mode: statBuffer.st_mode
            )
        }
    }

    static func flags(for url: URL) -> UInt32? {
        snapshot(for: url)?.flags
    }

    static func isDataless(_ url: URL) -> Bool {
        guard let flags = flags(for: url) else {
            return false
        }
        return (flags & sfDataless) != 0
    }

    static func isDataless(_ snapshot: Snapshot) -> Bool {
        (snapshot.flags & sfDataless) != 0
    }
}

final class BackupMonitor: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = BackupMonitor()

    @Published var state: BackupState = .disabled
    @Published var network = NetworkPolicy.current(isExpensive: false, isConstrained: false)
    @Published var nextRunAt: Date?
    @Published var lastStartAt: Date?
    @Published var lastSuccessAt: Date?
    @Published var lastSuccessCloudCoverage: String?
    @Published var lastSnapshotAt: Date?
    @Published var lastSnapshotID: String?
    @Published var lastSnapshotRoot: String?
    @Published var lastSnapshotDuration: String?
    @Published var lastSnapshotResult: String?
    @Published var lastSnapshotErrorCount: Int?
    @Published var lastSnapshotToleratedCount: Int?
    @Published var lastSnapshotActionRequiredCount: Int?
    @Published var lastSnapshotUnclassifiedCount: Int?
    @Published var lastSnapshotIssueCounts: [String: Int] = [:]
    @Published var lastSnapshotIssueSamples: [KopiaSnapshotIssueSample] = []
    @Published var lastFailureAt: Date?
    @Published var lastFailure: String?
    @Published var lastFailureKind: String?
    @Published var lastFailureDetail: String?
    @Published var lastAbortReason: String?
    @Published var activePID: Int32?
    @Published var activeOperation: String?
    @Published var activeOperationStartedAt: Date?
    @Published var activeOperationDetail: String?
    @Published var activeRunID: String?
    @Published var activePIDOwner: String?
    @Published var externalKopiaPIDs: [Int32] = []
    @Published var livenessCheckAt = Date()
    @Published var viewerBackupElapsedSeconds: Int?
    @Published var lastKopiaOutputAt: Date?
    @Published var internalKopiaActivity = InternalKopiaActivitySnapshot.inactive()
    @Published var protectedDataProbeResults: [ProtectedDataProbeResult] = []
    @Published var cloudMaterialization = CloudMaterializationSnapshot.empty()
    @Published var kopiaRanAfterMaterialization = false
    @Published var diskHealth = DiskHealthSnapshot.unknown()
    @Published var cloudCapacityEstimate = CloudCapacityEstimate.unknown()
    @Published var setupGate = SetupGateResult(
        complete: false,
        blockers: [.configMissing, .passwordMissing, .repositoryNotConnected]
    )
    @Published var repositoryStatus = RepositoryStatusSnapshot.unknown()

    private let locationManager = CLLocationManager()
    private let pathMonitor = NWPathMonitor()
    private let pathQueue = DispatchQueue(label: "kopia.monitor.network-path")
    private let materializationQueue = DispatchQueue(label: "kopia.monitor.cloud-materialization", qos: .utility)
    private let processQueue = DispatchQueue(label: "kopia.monitor.process", qos: .utility)
    private let startQueue = DispatchQueue(label: "kopia.monitor.start", qos: .utility)
    private let kopiaActivityQueue = DispatchQueue(label: "kopia.monitor.kopia-activity", qos: .utility)
    private let materializationControlLock = NSLock()
    private var timer: Timer?
    private var started = false
    private var viewerOnly = false
    private var activeProcess: Process?
    private var activePipe: Pipe?
    private var activeOperationID: UUID?
    private var processReconcileInFlight = false
    private var kopiaActivityProbeInFlight = false
    private var startupReady = false
    private var kopiaOutputBuffer = ""
    private var kopiaSuppressedDatalessReadErrors = 0
    private var kopiaOtherOutputReadErrors = 0
    private var kopiaOutputObservation = KopiaOutputObservation()
    private var observedKopiaFailure: KopiaFailureClassification?
    private var activeMaterializationID: UUID?
    private var stopReason: String?
    private var lastNetworkCheckAt = Date.distantPast
    private var lastMaterializationNetworkCheckAt = Date.distantPast
    private var cancelledMaterializationIDs = Set<UUID>()
    private var pathIsExpensive = false
    private var pathIsConstrained = false
    private var fullDiskAccessBlocked = false
    private var cloudDownloadBlocked = false
    private var lastKopiaActivityHeartbeatLogAt: Date?
    private var lastKopiaActivityHeartbeatSummary: String?
    private var stopFailureKind: String?
    private var stopFailureDetail: String?
    private var oneShotMode = false
    private var oneShotExitCode: Int32?

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    func start() {
        guard !started else {
            return
        }
        started = true

        loadPersistedStatus()
        appendLog("monitor starting")
        pathMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.pathIsExpensive = path.isExpensive
                self?.pathIsConstrained = path.isConstrained
                self?.refreshNetwork(reason: "path-update", shouldEvaluateSchedule: true)
            }
        }
        pathMonitor.start(queue: pathQueue)

        refreshNetwork(reason: "startup", shouldEvaluateSchedule: false)
        refreshSetupGate()
        if !oneShotMode {
            refreshRepositoryStatus()
        }
        seedLastSuccessFromLogIfNeededThenReconcile()
        timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            self?.tick()
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func startViewer() {
        guard !started else {
            return
        }
        started = true
        viewerOnly = true

        loadViewerStatus()
        timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            self?.loadViewerStatus()
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func runOneShotBackupAndExit(timeoutSeconds: Int) -> Never {
        oneShotMode = true
        oneShotExitCode = nil
        start()
        startBackup(trigger: "backup-once")

        let deadline = Date().addingTimeInterval(TimeInterval(timeoutSeconds))
        while Date() < deadline {
            if let exitCode = oneShotExitCode {
                exit(exitCode)
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.2))
        }

        appendLog("backup-once timed out after \(timeoutSeconds)s")
        stopBackup(reason: "backup-once timeout")
        let stopDeadline = Date().addingTimeInterval(20)
        while Date() < stopDeadline {
            if activeProcess == nil && activePID == nil && activeRunID == nil {
                break
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.2))
        }
        if let process = activeProcess, process.isRunning {
            appendLog("backup-once timeout cleanup: killing kopia pid \(process.processIdentifier)")
            kill(process.processIdentifier, SIGKILL)
        }
        if let activePID {
            appendLog("backup-once timeout cleanup: killing recovered kopia pid \(activePID)")
            ProcessInspector.forceTerminate(pids: [activePID])
        }
        removeActiveRunRecord()
        exit(124)
    }

    private func loadViewerStatus() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: Config.statusFile)),
              let status = try? JSONDecoder().decode(StatusSnapshot.self, from: data) else {
            applyViewerStatusUnavailable()
            return
        }

        state = BackupState(rawValue: status.state) ?? state
        network = NetworkSnapshot(
            state: status.network_state,
            allowed: status.network_state == "allowed",
            device: nil,
            ssid: status.network_ssid,
            reason: status.network_reason,
            location_authorization: "from_status",
            is_expensive: status.network_is_expensive,
            is_constrained: status.network_is_constrained,
            deny_ssids: Array(Config.denySSIDs).sorted()
        )
        nextRunAt = parseDate(status.next_run_at)
        activeOperation = status.active_operation
        activeOperationStartedAt = parseDate(status.active_operation_started_at)
        activeOperationDetail = status.active_operation_detail
        activePID = status.active_pid
        activeRunID = status.active_run_id
        activePIDOwner = status.active_pid_owner
        externalKopiaPIDs = status.external_kopia_pids ?? []
        lastStartAt = parseDate(status.last_start_at)
        livenessCheckAt = parseDate(status.last_liveness_check_at) ?? livenessCheckAt
        viewerBackupElapsedSeconds = status.backup_elapsed_seconds
        lastSuccessAt = parseDate(status.last_success_at)
        lastSuccessCloudCoverage = status.last_success_cloud_coverage
        lastSnapshotAt = parseDate(status.last_snapshot_at)
        lastSnapshotID = status.last_snapshot_id
        lastSnapshotRoot = status.last_snapshot_root
        lastSnapshotDuration = status.last_snapshot_duration
        lastSnapshotResult = status.last_snapshot_result
        lastSnapshotErrorCount = status.last_snapshot_error_count
        lastSnapshotToleratedCount = status.last_snapshot_tolerated_count
        lastSnapshotActionRequiredCount = status.last_snapshot_action_required_count
        lastSnapshotUnclassifiedCount = status.last_snapshot_unclassified_count
        lastSnapshotIssueCounts = status.last_snapshot_issue_counts ?? [:]
        lastSnapshotIssueSamples = status.last_snapshot_issue_samples ?? []
        lastFailureAt = parseDate(status.last_failure_at)
        lastFailure = status.last_failure
        lastFailureKind = status.last_failure_kind
        lastFailureDetail = status.last_failure_detail
        lastAbortReason = status.last_abort_reason
        lastKopiaOutputAt = parseDate(status.last_kopia_output_at)
        internalKopiaActivity = status.kopia_activity ?? .inactive()
        kopiaSuppressedDatalessReadErrors = status.kopia_suppressed_dataless_read_errors ?? 0
        kopiaOtherOutputReadErrors = status.kopia_other_output_read_errors ?? 0
        protectedDataProbeResults = status.protected_data_probe_results ?? []
        cloudMaterialization = status.cloud_materialization ?? .empty()
        kopiaRanAfterMaterialization = status.kopia_ran_after_materialization ?? false
        setupGate = status.setup_gate ?? setupGate
        repositoryStatus = status.repository_status ?? repositoryStatus
        if let statusDiskHealth = status.disk_health {
            diskHealth = statusDiskHealth
        }
        if let statusCloudCapacityEstimate = status.cloud_capacity_estimate {
            cloudCapacityEstimate = statusCloudCapacityEstimate
        }
    }

    private func applyViewerStatusUnavailable() {
        state = .disabled
        network = NetworkSnapshot(
            state: "unknown",
            allowed: false,
            device: nil,
            ssid: nil,
            reason: "Agent status unavailable",
            location_authorization: "from_status",
            is_expensive: false,
            is_constrained: false,
            deny_ssids: Array(Config.denySSIDs).sorted()
        )
        nextRunAt = nil
        activeOperation = nil
        activeOperationStartedAt = nil
        activeOperationDetail = nil
        activePID = nil
        activeRunID = nil
        activePIDOwner = nil
        externalKopiaPIDs = []
        livenessCheckAt = Date()
        viewerBackupElapsedSeconds = nil
        lastKopiaOutputAt = nil
        internalKopiaActivity = .inactive()
        kopiaSuppressedDatalessReadErrors = 0
        kopiaOtherOutputReadErrors = 0
    }

    func requestLocationPermission() {
        appendLog("requesting Location Services permission")
        if let executableURL = Bundle.main.executableURL {
            let process = Process()
            process.executableURL = executableURL
            process.arguments = ["--request-location"]
            try? process.run()
        } else {
            locationManager.requestAlwaysAuthorization()
            locationManager.startUpdatingLocation()
        }
    }

    func checkNetworkNow() {
        if viewerOnly {
            loadViewerStatus()
            return
        }

        refreshNetwork(reason: "manual-check", shouldEvaluateSchedule: false)
        reconcileLiveKopiaProcesses(reason: "manual-check", shouldEvaluateSchedule: true)
        refreshInternalKopiaActivity(reason: "manual-check")
    }

    func recordManualActionFailure(_ message: String) {
        lastFailureAt = Date()
        lastFailure = message
        lastFailureKind = "manual_action_failed"
        lastFailureDetail = message
        appendLog("manual action failed: \(message)")
        updateDerivedState()
        writeStatus()
        completeOneShot(exitCode: 1)
    }

    var hasActiveWork: Bool {
        activeProcess != nil
            || activePID != nil
            || activeRunID != nil
            || activeMaterializationID != nil
            || activeOperationID != nil
    }

    var canSavePreferences: Bool {
        !viewerOnly && !hasActiveWork
    }

    func saveRuntimeConfig(_ config: RuntimeConfig) throws {
        guard canSavePreferences else {
            throw NSError(
                domain: Config.bundleIdentifier,
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Cannot save preferences while COPYA work is running"]
            )
        }
        try Config.saveRuntime(config)
        appendLog("preferences saved")
        refreshNetwork(reason: "preferences-saved", shouldEvaluateSchedule: false)
        refreshSetupGate()
        writeStatus()
    }

    func storeKeychainPasswordFromPreferences(_ password: String) throws {
        guard !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(
                domain: Config.bundleIdentifier,
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Kopia password cannot be empty"]
            )
        }
        try KeychainPasswordStore.storePassword(password)
        appendLog("Kopia password stored in Keychain")
        refreshSetupGate()
        refreshRepositoryStatus()
        writeStatus()
    }

    func refreshSetupGate() {
        setupGate = evaluateSetupGate()
    }

    private func evaluateSetupGate() -> SetupGateResult {
        let source = Config.backupSource
        var isDirectory = ObjCBool(false)
        let sourceExists = FileManager.default.fileExists(atPath: source, isDirectory: &isDirectory)
        let sourceReadable = sourceExists && FileManager.default.isReadableFile(atPath: source)
        let needsLocation = Config.networkPolicyEnabled
            && ["permission", "redacted"].contains(network.state)
        let fullDiskAcceptable = Config.limitedBackupAcknowledged || !fullDiskAccessBlocked
        return SetupGateResult.evaluate(
            SetupGateInput(
                configExists: Config.configExists,
                sourceExists: sourceExists,
                sourceReadable: sourceReadable,
                passwordAvailable: passwordIsAvailableForSetup(),
                repositoryConnected: repositoryStatus.connected,
                networkPolicyNeedsPermission: needsLocation,
                fullDiskAccessAcceptable: fullDiskAcceptable,
                activeWorkRunning: false
            )
        )
    }

    private func passwordIsAvailableForSetup() -> Bool {
        switch Config.passwordSource {
        case "keychain":
            return KeychainPasswordStore.hasPassword()
        case "environment":
            return !(childEnvironment()[Config.passwordEnvVar] ?? "").isEmpty
        case "onepassword":
            return !Config.kopiaPasswordRef.isEmpty && CommandRunner.findExecutable("op") != nil
        case "command":
            return !Config.passwordCommand.isEmpty
        default:
            return false
        }
    }

    private func refreshRepositoryStatusSynchronously(timeoutSeconds: Int = 10) {
        guard let kopiaPath = CommandRunner.findExecutable("kopia") else {
            repositoryStatus = RepositoryStatusSnapshot(
                checkedAt: DateFormatters.iso.string(from: Date()),
                state: .failed,
                detail: "Kopia is not installed or bundled"
            )
            refreshSetupGate()
            return
        }
        let password = (try? readConfiguredPasswordForRepositoryWork()) ?? ""
        var environment = childEnvironment()
        if !password.isEmpty {
            environment["KOPIA_PASSWORD"] = password
        }
        do {
            let result = try CommandRunner.run(
                kopiaPath,
                arguments: KopiaRepositoryCommand.statusArguments(configFile: Config.kopiaConfigFile),
                environment: environment,
                timeoutSeconds: timeoutSeconds
            )
            let state = RepositoryStatusClassifier.classify(
                status: result.status,
                stdout: result.stdout,
                stderr: result.stderr,
                timedOut: result.timedOut
            )
            repositoryStatus = RepositoryStatusSnapshot(
                checkedAt: DateFormatters.iso.string(from: Date()),
                state: state,
                detail: repositoryDetail(state: state, stderr: result.stderr)
            )
        } catch {
            repositoryStatus = RepositoryStatusSnapshot(
                checkedAt: DateFormatters.iso.string(from: Date()),
                state: .failed,
                detail: error.localizedDescription
            )
        }
        refreshSetupGate()
    }

    func refreshRepositoryStatus() {
        guard !viewerOnly else {
            return
        }
        guard !hasActiveWork else {
            return
        }
        let operationID = UUID()
        beginOperation(id: operationID, name: "repository_status", detail: "checking Kopia repository")
        processQueue.async { [weak self] in
            guard let self else {
                return
            }
            let kopiaPath = CommandRunner.findExecutable("kopia")
            let password = (try? self.readConfiguredPasswordForRepositoryWork()) ?? ""
            DispatchQueue.main.async {
                guard self.activeOperationID == operationID else {
                    return
                }
                guard let kopiaPath else {
                    self.repositoryStatus = RepositoryStatusSnapshot(
                        checkedAt: DateFormatters.iso.string(from: Date()),
                        state: .failed,
                        detail: "Kopia is not installed or bundled"
                    )
                    self.clearOperation(id: operationID)
                    self.refreshSetupGate()
                    self.updateDerivedState()
                    self.writeStatus()
                    return
                }
                var environment = self.childEnvironment()
                if !password.isEmpty {
                    environment["KOPIA_PASSWORD"] = password
                }
                self.processQueue.async { [weak self] in
                    guard let self else {
                        return
                    }
                    do {
                        let result = try CommandRunner.run(
                            kopiaPath,
                            arguments: KopiaRepositoryCommand.statusArguments(configFile: Config.kopiaConfigFile),
                            environment: environment,
                            timeoutSeconds: 20
                        )
                        DispatchQueue.main.async {
                            guard self.activeOperationID == operationID else {
                                return
                            }
                            let state = RepositoryStatusClassifier.classify(
                                status: result.status,
                                stdout: result.stdout,
                                stderr: result.stderr,
                                timedOut: result.timedOut
                            )
                            self.repositoryStatus = RepositoryStatusSnapshot(
                                checkedAt: DateFormatters.iso.string(from: Date()),
                                state: state,
                                detail: self.repositoryDetail(state: state, stderr: result.stderr)
                            )
                            self.clearOperation(id: operationID)
                            self.refreshSetupGate()
                            self.updateDerivedState()
                            self.writeStatus()
                        }
                    } catch {
                        DispatchQueue.main.async {
                            guard self.activeOperationID == operationID else {
                                return
                            }
                            self.repositoryStatus = RepositoryStatusSnapshot(
                                checkedAt: DateFormatters.iso.string(from: Date()),
                                state: .failed,
                                detail: error.localizedDescription
                            )
                            self.clearOperation(id: operationID)
                            self.refreshSetupGate()
                            self.updateDerivedState()
                            self.writeStatus()
                        }
                    }
                }
            }
        }
    }

    func setupBackblazeRepository(
        mode: KopiaRepositoryMode,
        bucket: String,
        endpoint: String,
        region: String,
        prefix: String,
        accessKeyID: String,
        applicationKey: String
    ) {
        let request = BackblazeB2S3RepositoryRequest(
            mode: mode,
            bucket: bucket.trimmingCharacters(in: .whitespacesAndNewlines),
            endpoint: endpoint.trimmingCharacters(in: .whitespacesAndNewlines),
            region: region.trimmingCharacters(in: .whitespacesAndNewlines),
            prefix: prefix.trimmingCharacters(in: .whitespacesAndNewlines),
            accessKeyID: accessKeyID,
            applicationKey: applicationKey,
            configFile: Config.kopiaConfigFile
        )
        guard !request.bucket.isEmpty,
              !request.resolvedEndpoint.isEmpty,
              !request.accessKeyID.isEmpty,
              !request.applicationKey.isEmpty else {
            recordManualActionFailure("Backblaze B2 setup needs bucket, region or endpoint, key ID, and application key")
            return
        }
        runRepositorySetup(kind: "Backblaze B2 S3 \(mode.rawValue)") { [weak self] password in
            guard let self else {
                return nil
            }
            return KopiaRepositoryCommand.backblazeB2S3Spec(
                request: request,
                baseEnvironment: self.childEnvironment(),
                kopiaPassword: password
            )
        }
    }

    func setupFilesystemRepository(mode: KopiaRepositoryMode, path: String) {
        let request = FilesystemRepositoryRequest(
            mode: mode,
            path: path.trimmingCharacters(in: .whitespacesAndNewlines),
            configFile: Config.kopiaConfigFile
        )
        guard !request.path.isEmpty else {
            recordManualActionFailure("Filesystem repository path is required")
            return
        }
        runRepositorySetup(kind: "filesystem \(mode.rawValue)") { [weak self] password in
            guard let self else {
                return nil
            }
            return KopiaRepositoryCommand.filesystemSpec(
                request: request,
                baseEnvironment: self.childEnvironment(),
                kopiaPassword: password
            )
        }
    }

    private func runRepositorySetup(
        kind: String,
        buildSpec: @escaping (String) -> KopiaProcessSpec?
    ) {
        guard !viewerOnly else {
            recordManualActionFailure("Repository setup is controlled by the launch agent instance")
            return
        }
        guard !hasActiveWork else {
            recordManualActionFailure("Cannot run repository setup while backup work is active")
            return
        }
        guard let kopiaPath = CommandRunner.findExecutable("kopia") else {
            recordManualActionFailure("Kopia is not installed or bundled")
            return
        }
        let operationID = UUID()
        beginOperation(id: operationID, name: "repository_setup", detail: "running \(kind)")

        processQueue.async { [weak self] in
            guard let self else {
                return
            }
            let password: String
            do {
                password = try self.readConfiguredPasswordForRepositoryWork()
            } catch {
                DispatchQueue.main.async {
                    guard self.activeOperationID == operationID else {
                        return
                    }
                    self.recordSecretUnavailable(
                        "Unable to read Kopia password for repository setup",
                        detail: String(describing: error),
                        operationID: operationID
                    )
                }
                return
            }
            guard let spec = buildSpec(password) else {
                DispatchQueue.main.async {
                    guard self.activeOperationID == operationID else {
                        return
                    }
                    self.recordManualActionFailure("Unable to build repository setup command")
                }
                return
            }
            do {
                let result = try CommandRunner.run(
                    kopiaPath,
                    arguments: spec.arguments,
                    environment: spec.environment,
                    timeoutSeconds: 120
                )
                DispatchQueue.main.async {
                    guard self.activeOperationID == operationID else {
                        return
                    }
                    if result.status == 0 {
                        self.appendLog("repository setup complete kind=\"\(kind)\" command=\"\(spec.redactedDisplay)\"")
                        self.tightenKopiaConfigPermissions()
                        self.repositoryStatus = RepositoryStatusSnapshot(
                            checkedAt: DateFormatters.iso.string(from: Date()),
                            state: .connected,
                            detail: "\(kind) complete"
                        )
                        self.clearOperation(id: operationID)
                        self.refreshSetupGate()
                        self.updateDerivedState()
                        self.writeStatus()
                    } else {
                        let detail = self.repositoryDetail(state: .failed, stderr: result.stderr)
                        self.repositoryStatus = RepositoryStatusSnapshot(
                            checkedAt: DateFormatters.iso.string(from: Date()),
                            state: .failed,
                            detail: detail
                        )
                        self.clearOperation(id: operationID)
                        self.recordFailure(
                            "Repository setup failed",
                            kind: "repository_setup_failed",
                            detail: detail
                        )
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    guard self.activeOperationID == operationID else {
                        return
                    }
                    self.repositoryStatus = RepositoryStatusSnapshot(
                        checkedAt: DateFormatters.iso.string(from: Date()),
                        state: .failed,
                        detail: error.localizedDescription
                    )
                    self.clearOperation(id: operationID)
                    self.recordFailure(
                        "Repository setup failed",
                        kind: "repository_setup_failed",
                        detail: error.localizedDescription
                    )
                }
            }
        }
    }

    private func readConfiguredPasswordForRepositoryWork() throws -> String {
        switch Config.passwordSource {
        case "keychain":
            return try KeychainPasswordStore.readPassword()
        case "environment":
            return childEnvironment()[Config.passwordEnvVar] ?? ""
        case "onepassword":
            guard let opPath = CommandRunner.findExecutable("op") else {
                throw KeychainPasswordStore.Error.notFound
            }
            let result = try CommandRunner.run(
                opPath,
                arguments: ["read", Config.kopiaPasswordRef],
                environment: childEnvironment(),
                timeoutSeconds: Config.passwordReadTimeoutSeconds
            )
            guard result.status == 0 else {
                throw NSError(
                    domain: Config.bundleIdentifier,
                    code: Int(result.status),
                    userInfo: [NSLocalizedDescriptionKey: "1Password read failed"]
                )
            }
            return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        case "command":
            guard let executable = Config.passwordCommand.first else {
                return ""
            }
            let result = try CommandRunner.run(
                executable,
                arguments: Array(Config.passwordCommand.dropFirst()),
                environment: childEnvironment(),
                timeoutSeconds: Config.passwordReadTimeoutSeconds
            )
            guard result.status == 0 else {
                return ""
            }
            return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        default:
            return ""
        }
    }

    private func repositoryDetail(state: RepositoryConnectionState, stderr: String) -> String? {
        switch state {
        case .connected:
            return "Repository connected"
        case .missingPassword:
            return "Kopia password is required"
        case .unknown:
            return nil
        case .disconnected, .failed:
            let detail = stderr
                .split(separator: "\n")
                .last
                .map(String.init)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return detail?.isEmpty == false ? detail : "Repository is not connected"
        }
    }

    private func tightenKopiaConfigPermissions() {
        let paths = [
            Config.kopiaConfigFile,
            "\(Config.kopiaHome)/.config/kopia/repository.config",
            "\(Config.kopiaHome)/Library/Application Support/kopia/repository.config",
        ].compactMap { $0 }
        for path in paths where FileManager.default.fileExists(atPath: path) {
            chmod(path, 0o600)
        }
    }

    private func refreshInternalKopiaActivity(reason: String) {
        guard activePID != nil else {
            internalKopiaActivity = .inactive()
            return
        }
        guard !kopiaActivityProbeInFlight else {
            return
        }

        kopiaActivityProbeInFlight = true
        let activePID = activePID
        let activeRunID = activeRunID
        let activeRunRecord = readActiveRunRecord()
        let fallbackRunStartedAt = lastStartAt
        let stdoutAt = lastKopiaOutputAt

        kopiaActivityQueue.async { [weak self] in
            let snapshot = InternalKopiaActivityProbe.scan(
                activePID: activePID,
                activeRunID: activeRunID,
                activeRunRecord: activeRunRecord,
                fallbackRunStartedAt: fallbackRunStartedAt,
                stdoutAt: stdoutAt
            )

            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.kopiaActivityProbeInFlight = false
                guard self.activePID == activePID else {
                    return
                }
                self.internalKopiaActivity = snapshot
                self.appendKopiaActivityHeartbeatIfNeeded(snapshot, reason: reason)
                self.writeStatus()
            }
        }
    }

    private func appendKopiaActivityHeartbeatIfNeeded(
        _ snapshot: InternalKopiaActivitySnapshot,
        reason: String
    ) {
        guard activePID != nil else {
            return
        }
        let now = Date()
        let summary = snapshot.summary ?? snapshot.unavailable_reason ?? snapshot.confidence
        let shouldLogStateChange = summary != lastKopiaActivityHeartbeatSummary
        let shouldLogInterval = lastKopiaActivityHeartbeatLogAt == nil
            || now.timeIntervalSince(lastKopiaActivityHeartbeatLogAt!) >= TimeInterval(Config.kopiaActivityHeartbeatIntervalSeconds)

        guard shouldLogStateChange || shouldLogInterval else {
            return
        }

        lastKopiaActivityHeartbeatLogAt = now
        lastKopiaActivityHeartbeatSummary = summary
        let idleText = snapshot.idle_seconds.map { " idle_seconds=\($0)" } ?? ""
        let sourceText = snapshot.source_type.map { " source=\($0)" } ?? ""
        let pathText = snapshot.source_path.map { " path=\"\($0)\"" } ?? ""
        appendLog("kopia activity heartbeat reason=\(reason) confidence=\(snapshot.confidence) summary=\"\(summary)\"\(idleText)\(sourceText)\(pathText)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        refreshNetwork(reason: "location-authorization", shouldEvaluateSchedule: true)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        refreshNetwork(reason: "location-update", shouldEvaluateSchedule: true)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        refreshNetwork(reason: "location-error", shouldEvaluateSchedule: true)
    }

    private func beginOperation(id: UUID, name: String, detail: String) {
        activeOperationID = id
        activeOperation = name
        activeOperationStartedAt = Date()
        activeOperationDetail = detail
        updateDerivedState()
        writeStatus()
    }

    private func clearOperation(id: UUID? = nil) {
        if let id, activeOperationID != id {
            return
        }
        activeOperationID = nil
        activeOperation = nil
        activeOperationStartedAt = nil
        activeOperationDetail = nil
    }

    @discardableResult
    private func refreshDiskHealth(
        requiredBytes: Int64,
        thresholdKind: String
    ) -> DiskHealthSnapshot {
        let snapshot = DiskSpaceProbe.snapshot(
            paths: Config.diskFreeSpaceCheckPaths,
            requiredBytes: requiredBytes,
            thresholdKind: thresholdKind
        )
        diskHealth = snapshot
        return snapshot
    }

    private func recordDiskSpaceFailure(
        _ health: DiskHealthSnapshot,
        message: String
    ) {
        let detail = health.reason ?? "disk space check failed"
        recordFailure(
            "\(message): \(detail)",
            kind: "disk_space_exhausted",
            detail: detail
        )
    }

    private func pruneInactiveKopiaDiagnosticLogs(
        preservePIDs: Set<Int32>,
        reason: String
    ) {
        let summary = KopiaDiagnosticLogPruner.prune(
            logDirs: Config.internalKopiaLogDirs,
            retentionBytes: Config.kopiaInternalLogRetentionBytes,
            preservePIDs: preservePIDs
        )
        guard summary.removed_count > 0 else {
            return
        }
        appendLog("kopia diagnostic log prune reason=\(reason) removed_files=\(summary.removed_count) removed_bytes=\(summary.removed_bytes) kept_inactive_bytes=\(summary.kept_inactive_bytes) preserved_live_files=\(summary.preserved_live_count)")
    }

    private func markMaterializationCancelled(_ id: UUID) {
        materializationControlLock.lock()
        cancelledMaterializationIDs.insert(id)
        materializationControlLock.unlock()
    }

    private func clearMaterializationCancellation(_ id: UUID) {
        materializationControlLock.lock()
        cancelledMaterializationIDs.remove(id)
        materializationControlLock.unlock()
    }

    private func isMaterializationCancelled(_ id: UUID) -> Bool {
        materializationControlLock.lock()
        let cancelled = cancelledMaterializationIDs.contains(id)
        materializationControlLock.unlock()
        return cancelled
    }

    private func applyReconciledKopiaState(
        _ reconciled: ReconciledKopiaState,
        reason: String
    ) -> Bool {
        if reconciled.staleActiveRunRecord {
            appendLog("removing stale active-run record reason=\(reason)")
            removeActiveRunRecord()
        }

        if let owned = reconciled.owned {
            activePID = owned.pid
            activePIDOwner = activeProcess == nil ? "recovered" : "current"
            activeRunID = readActiveRunRecord()?.run_id
            externalKopiaPIDs = reconciled.external.map(\.pid).sorted()
            lastStartAt = lastStartAt ?? parseDate(readActiveRunRecord()?.started_at) ?? Date()
            appendLog("recovered COPYA-owned Kopia process pid=\(owned.pid) reason=\(reason)")
            return true
        }

        if let starting = reconciled.starting {
            activePID = nil
            activePIDOwner = "starting"
            activeRunID = starting.run_id
            activeOperation = "starting_backup"
            activeOperationStartedAt = parseDate(starting.started_at) ?? Date()
            activeOperationDetail = "another COPYA instance is starting Kopia"
            externalKopiaPIDs = reconciled.external.map(\.pid).sorted()
            appendLog("COPYA active-run start in progress run_id=\(starting.run_id) reason=\(reason)")
            return true
        }

        if !reconciled.external.isEmpty {
            activePID = nil
            activePIDOwner = nil
            activeRunID = nil
            activeOperation = nil
            activeOperationStartedAt = nil
            activeOperationDetail = nil
            externalKopiaPIDs = reconciled.external.map(\.pid).sorted()
            appendLog("external Kopia snapshot process detected pids=\(externalKopiaPIDs.map { String($0) }.joined(separator: ",")) reason=\(reason)")
            return true
        }

        if !externalKopiaPIDs.isEmpty {
            appendLog("external Kopia snapshot processes cleared reason=\(reason)")
        }
        if activePIDOwner == "starting" {
            activePIDOwner = nil
            activeRunID = nil
            activeOperation = nil
            activeOperationStartedAt = nil
            activeOperationDetail = nil
        }
        externalKopiaPIDs = []
        return false
    }

    private func reconcileLiveKopiaProcesses(
        reason: String,
        shouldEvaluateSchedule: Bool,
        markStartupReady: Bool = false
    ) {
        guard !processReconcileInFlight else {
            return
        }
        processReconcileInFlight = true
        let recoveredPID = activePIDOwner == "recovered" ? activePID : nil

        processQueue.async { [weak self] in
            guard let self else {
                return
            }

            let scan = ProcessInspector.scanKopiaSnapshots()
            let activeRunRecord = self.readActiveRunRecord()
            let reconciled = ProcessReconciler.reconcile(
                matching: scan.processes,
                activeRunRecord: activeRunRecord
            )

            DispatchQueue.main.async {
                self.processReconcileInFlight = false
                if markStartupReady {
                    self.startupReady = true
                }
                guard scan.succeeded else {
                    self.appendLog("process scan failed during \(reason): \(scan.error ?? "unknown error")")
                    self.updateDerivedState()
                    self.writeStatus()
                    return
                }

                if let recoveredPID,
                   !scan.processes.contains(where: { $0.pid == recoveredPID }) {
                    self.handleRecoveredBackupExit()
                    return
                }

                let blocked = self.applyReconciledKopiaState(reconciled, reason: reason)
                self.updateDerivedState()
                self.writeStatus()
                if shouldEvaluateSchedule && !blocked {
                    self.evaluateSchedule(becameAllowed: false, reason: reason)
                }
            }
        }
    }

    func startBackup(trigger: String) {
        guard !viewerOnly else {
            appendLog("start ignored: menu is in viewer mode because launch agent owns backup control")
            completeOneShot(exitCode: 1)
            return
        }
        guard activeProcess == nil else {
            appendLog("start ignored: backup already running pid=\(activePID ?? 0)")
            completeOneShot(exitCode: 1)
            return
        }
        guard activePID == nil else {
            appendLog("start ignored: backup already running pid=\(activePID ?? 0) owner=\(activePIDOwner ?? "unknown")")
            completeOneShot(exitCode: 1)
            return
        }
        guard activeRunID == nil else {
            appendLog("start ignored: active run already present run_id=\(activeRunID ?? "unknown") owner=\(activePIDOwner ?? "unknown")")
            completeOneShot(exitCode: 1)
            return
        }
        guard activeMaterializationID == nil else {
            appendLog("start ignored: cloud materialization already running")
            completeOneShot(exitCode: 1)
            return
        }
        guard activeOperationID == nil else {
            appendLog("start ignored: operation already running \(activeOperation ?? "unknown")")
            completeOneShot(exitCode: 1)
            return
        }
        guard externalKopiaPIDs.isEmpty else {
            appendLog("start blocked: external Kopia process detected pids=\(externalKopiaPIDs.map { String($0) }.joined(separator: ","))")
            updateDerivedState()
            writeStatus()
            completeOneShot(exitCode: 1)
            return
        }

        if repositoryStatus.state == .unknown {
            refreshRepositoryStatusSynchronously()
        }
        refreshSetupGate()
        guard setupGate.complete else {
            let reason = setupGate.summary
            lastFailureAt = Date()
            lastFailure = reason
            lastFailureKind = "setup_incomplete"
            lastFailureDetail = reason
            appendLog("start blocked: setup incomplete: \(reason)")
            updateDerivedState()
            writeStatus()
            completeOneShot(exitCode: 1)
            return
        }

        network = currentNetworkSnapshot()
        guard network.allowed else {
            appendLog("start blocked: network_state=\(network.state) reason='\(network.reason)'")
            updateDerivedState()
            writeStatus()
            completeOneShot(exitCode: 1)
            return
        }

        let startDiskHealth = refreshDiskHealth(
            requiredBytes: Config.minimumExecutionReserveBytes,
            thresholdKind: "start"
        )
        guard startDiskHealth.ok else {
            recordDiskSpaceFailure(
                startDiskHealth,
                message: "Insufficient local disk space to start Kopia"
            )
            return
        }

        let operationID = UUID()
        beginOperation(
            id: operationID,
            name: "starting_backup",
            detail: "checking for existing Kopia processes"
        )

        startQueue.async { [weak self] in
            guard let self else {
                return
            }

            let opPath = Config.passwordSource == "onepassword"
                ? CommandRunner.findExecutable("op")
                : nil
            let kopiaPath = CommandRunner.findExecutable("kopia")
            let scan = ProcessInspector.scanKopiaSnapshots()
            let activeRunRecord = self.readActiveRunRecord()
            let reconciled = ProcessReconciler.reconcile(
                matching: scan.processes,
                activeRunRecord: activeRunRecord
            )
            if scan.succeeded {
                self.pruneInactiveKopiaDiagnosticLogs(
                    preservePIDs: Set(scan.processes.map(\.pid)),
                    reason: "preflight-\(trigger)"
                )
            }

            DispatchQueue.main.async {
                guard self.activeOperationID == operationID else {
                    return
                }

                guard scan.succeeded else {
                    self.recordPreflightFailure("Unable to inspect running Kopia processes: \(scan.error ?? "unknown error")", operationID: operationID)
                    return
                }

                if self.applyReconciledKopiaState(reconciled, reason: "start-\(trigger)") {
                    self.clearOperation(id: operationID)
                    self.updateDerivedState()
                    self.writeStatus()
                    return
                }

                if Config.passwordSource == "onepassword" && opPath == nil {
                    self.recordSecretUnavailable("1Password CLI 'op' is not installed or not on PATH", operationID: operationID)
                    return
                }

                guard let kopiaPath else {
                    self.recordPreflightFailure("Kopia is not installed or not on PATH", operationID: operationID)
                    return
                }

                self.activeOperationDetail = "preparing protected files"
                self.startPreflightAndMaterialization(trigger: trigger, opPath: opPath, kopiaPath: kopiaPath)
            }
        }
    }

    private func startPreflightAndMaterialization(trigger: String, opPath: String?, kopiaPath: String) {
        let materializationID = UUID()
        activeMaterializationID = materializationID
        clearMaterializationCancellation(materializationID)
        activeOperationDetail = "probing protected data"
        lastMaterializationNetworkCheckAt = Date()
        fullDiskAccessBlocked = false
        cloudDownloadBlocked = false
        protectedDataProbeResults = []
        cloudMaterialization = CloudMaterializationSnapshot(
            enabled: Config.cloudMaterializationEnabled,
            started_at: DateFormatters.iso.string(from: Date()),
            finished_at: nil,
            completed: false,
            aborted: false,
            reason: "running",
            current_root: nil,
            current_phase: "preflight",
            total_directories_seen: 0,
            total_files_seen: 0,
            total_files_read: 0,
            total_failures: 0,
            total_dataless_placeholders: 0,
            total_read_failures: 0,
            cloud_coverage: nil,
            roots: []
        )
        cloudCapacityEstimate = CloudCapacityEstimate.unknown()
        state = Config.cloudMaterializationEnabled ? .preparingCloudFiles : .ready
        lastFailure = nil
        lastFailureAt = nil
        lastFailureKind = nil
        lastFailureDetail = nil
        lastAbortReason = nil
        kopiaRanAfterMaterialization = false
        appendLog("cloud materialization starting trigger=\(trigger)")
        writeStatus()

        materializationQueue.async { [weak self] in
            guard let self else {
                return
            }

            let probeResults = self.runProtectedDataProbes()
            let unreadableProbeCount = probeResults.filter { $0.exists && !$0.readable }.count
            DispatchQueue.main.async {
                guard self.activeMaterializationID == materializationID else {
                    return
                }

                self.protectedDataProbeResults = probeResults
                self.appendLog("protected data probes complete paths=\(probeResults.count) unreadable=\(unreadableProbeCount)")
                self.writeStatus()
            }

            if let abortReason = self.materializationAbortReason(for: materializationID) {
                DispatchQueue.main.async {
                    self.finishMaterialization(
                        id: materializationID,
                        probeResults: probeResults,
                        snapshot: self.abortedMaterializationSnapshot(reason: abortReason),
                        trigger: trigger,
                        opPath: opPath,
                        kopiaPath: kopiaPath
                    )
                }
                return
            }

            let unreadableProtectedPaths = probeResults.filter { $0.exists && !$0.readable }
            guard unreadableProtectedPaths.isEmpty else {
                let message = "Full Disk Access required for: \(unreadableProtectedPaths.map { $0.path }.joined(separator: ", "))"
                DispatchQueue.main.async {
                    self.finishFullDiskAccessFailure(
                        id: materializationID,
                        probeResults: probeResults,
                        message: message
                    )
                }
                return
            }

            if Config.cloudMaterializationEnabled {
                let capacityEstimate = CloudCapacityEstimator.estimate(
                    roots: Config.cloudMaterializationRoots,
                    executionPaths: Config.diskFreeSpaceCheckPaths
                )
                DispatchQueue.main.async {
                    guard self.activeMaterializationID == materializationID else {
                        return
                    }
                    self.cloudCapacityEstimate = capacityEstimate
                    self.appendLog(self.cloudCapacityEstimateLogMessage(capacityEstimate))
                    self.writeStatus()
                }

                guard capacityEstimate.ok else {
                    DispatchQueue.main.async {
                        self.finishCloudCapacityFailure(
                            id: materializationID,
                            probeResults: probeResults,
                            estimate: capacityEstimate
                        )
                    }
                    return
                }
            }

            let snapshot: CloudMaterializationSnapshot
            if Config.cloudMaterializationEnabled {
                snapshot = self.runCloudMaterialization(id: materializationID)
            } else {
                snapshot = CloudMaterializationSnapshot(
                    enabled: false,
                    started_at: DateFormatters.iso.string(from: Date()),
                    finished_at: DateFormatters.iso.string(from: Date()),
                    completed: true,
                    aborted: false,
                    reason: "disabled",
                    current_root: nil,
                    current_phase: nil,
                    total_directories_seen: 0,
                    total_files_seen: 0,
                    total_files_read: 0,
                    total_failures: 0,
                    total_dataless_placeholders: 0,
                    total_read_failures: 0,
                    cloud_coverage: "disabled",
                    roots: []
                )
            }

            DispatchQueue.main.async {
                self.finishMaterialization(
                    id: materializationID,
                    probeResults: probeResults,
                    snapshot: snapshot,
                    trigger: trigger,
                    opPath: opPath,
                    kopiaPath: kopiaPath
                )
            }
        }
    }

    private func finishFullDiskAccessFailure(
        id: UUID,
        probeResults: [ProtectedDataProbeResult],
        message: String
    ) {
        guard activeMaterializationID == id else {
            clearMaterializationCancellation(id)
            return
        }

        clearMaterializationCancellation(id)
        activeMaterializationID = nil
        clearOperation()
        protectedDataProbeResults = probeResults
        cloudMaterialization = abortedMaterializationSnapshot(reason: message)
        fullDiskAccessBlocked = true
        cloudDownloadBlocked = false
        lastFailureAt = Date()
        lastFailure = message
        lastFailureKind = "full_disk_access_required"
        lastFailureDetail = message
        nextRunAt = Date().addingTimeInterval(TimeInterval(Config.cloudMaterializationRetrySeconds))
        appendLog("failure: \(message); retrying preflight at \(DateFormatters.iso.string(from: nextRunAt!))")
        updateDerivedState()
        writeStatus()
        completeOneShot(exitCode: 1)
    }

    private func finishCloudCapacityFailure(
        id: UUID,
        probeResults: [ProtectedDataProbeResult],
        estimate: CloudCapacityEstimate
    ) {
        guard activeMaterializationID == id else {
            clearMaterializationCancellation(id)
            return
        }

        clearMaterializationCancellation(id)
        activeMaterializationID = nil
        clearOperation()
        protectedDataProbeResults = probeResults
        cloudCapacityEstimate = estimate
        let reason = estimate.reason ?? "insufficient disk capacity for cloud preparation"
        cloudMaterialization = abortedMaterializationSnapshot(reason: reason)
        fullDiskAccessBlocked = false
        cloudDownloadBlocked = false
        lastFailureAt = Date()
        lastFailure = "Needs disk space: \(reason)"
        lastFailureKind = "disk_space_exhausted"
        lastFailureDetail = reason
        nextRunAt = Date().addingTimeInterval(TimeInterval(Config.cloudMaterializationRetrySeconds))
        appendLog("failure: cloud capacity estimate insufficient: \(reason); retrying preflight at \(DateFormatters.iso.string(from: nextRunAt!))")
        updateDerivedState()
        writeStatus()
        completeOneShot(exitCode: 1)
    }

    private func finishMaterialization(
        id: UUID,
        probeResults: [ProtectedDataProbeResult],
        snapshot: CloudMaterializationSnapshot,
        trigger: String,
        opPath: String?,
        kopiaPath: String
    ) {
        guard activeMaterializationID == id else {
            clearMaterializationCancellation(id)
            return
        }

        clearMaterializationCancellation(id)
        activeMaterializationID = nil
        protectedDataProbeResults = probeResults
        cloudMaterialization = snapshot

        guard snapshot.completed && !snapshot.aborted else {
            clearOperation()
            let reason = snapshot.reason ?? "cloud materialization did not complete"
            cloudDownloadBlocked = true
            fullDiskAccessBlocked = false
            lastFailureAt = Date()
            lastFailure = "Cloud download blocked: \(reason)"
            lastFailureKind = "cloud_download_blocked"
            lastFailureDetail = reason
            if snapshot.aborted {
                lastAbortReason = reason
            }
            nextRunAt = Date().addingTimeInterval(TimeInterval(Config.cloudMaterializationRetrySeconds))
            appendLog("failure: cloud materialization blocked: \(reason); retrying at \(DateFormatters.iso.string(from: nextRunAt!))")
            updateDerivedState()
            writeStatus()
            completeOneShot(exitCode: 1)
            return
        }

        let datalessPlaceholders = snapshot.total_dataless_placeholders ?? 0
        let readFailures = snapshot.total_read_failures ?? snapshot.total_failures
        if datalessPlaceholders > 0 || readFailures > 0 {
            appendLog("warning: cloud materialization partial dataless_placeholders=\(datalessPlaceholders) read_failures=\(readFailures); starting Kopia anyway")
        }
        appendLog("cloud materialization complete files_read=\(snapshot.total_files_read) dataless_placeholders=\(datalessPlaceholders) read_failures=\(readFailures) roots=\(snapshot.roots.count)")
        startKopiaLaunch(trigger: trigger, opPath: opPath, kopiaPath: kopiaPath, ranAfterMaterialization: Config.cloudMaterializationEnabled)
    }

    private func startKopiaLaunch(
        trigger: String,
        opPath: String?,
        kopiaPath: String,
        ranAfterMaterialization: Bool
    ) {
        network = currentNetworkSnapshot()
        guard network.allowed else {
            recordPreflightFailure("Network changed before Kopia start: state=\(network.state) reason='\(network.reason)'")
            return
        }

        let startDiskHealth = refreshDiskHealth(
            requiredBytes: Config.minimumExecutionReserveBytes,
            thresholdKind: "start"
        )
        guard startDiskHealth.ok else {
            recordDiskSpaceFailure(
                startDiskHealth,
                message: "Insufficient local disk space to start Kopia after cloud preparation"
            )
            return
        }

        let operationID = activeOperationID ?? UUID()
        if activeOperationID == nil {
            beginOperation(id: operationID, name: "starting_backup", detail: "reading Kopia password")
        } else {
            activeOperation = "starting_backup"
            activeOperationDetail = "reading Kopia password"
            updateDerivedState()
            writeStatus()
        }

        startQueue.async { [weak self] in
            guard let self else {
                return
            }

            let password: String
            switch Config.passwordSource {
            case "onepassword":
                guard let opPath else {
                    DispatchQueue.main.async {
                        guard self.activeOperationID == operationID else {
                            return
                        }
                        self.recordSecretUnavailable("1Password CLI 'op' is not installed or not on PATH", operationID: operationID)
                    }
                    return
                }
                do {
                let result = try CommandRunner.run(
                    opPath,
                    arguments: ["read", Config.kopiaPasswordRef],
                    environment: self.childEnvironment(),
                    timeoutSeconds: Config.passwordReadTimeoutSeconds
                )
                if result.timedOut {
                    DispatchQueue.main.async {
                        guard self.activeOperationID == operationID else {
                            return
                        }
                        self.recordSecretUnavailable("Timed out reading Kopia password from 1Password", operationID: operationID)
                    }
                    return
                }
                guard result.status == 0 else {
                    let detail = self.sanitizedCommandError(result.stderr)
                    DispatchQueue.main.async {
                        guard self.activeOperationID == operationID else {
                            return
                        }
                        if detail.isEmpty {
                            self.recordSecretUnavailable("Unable to read Kopia password from 1Password reference", operationID: operationID)
                        } else {
                            self.recordSecretUnavailable("Unable to read Kopia password from 1Password reference", detail: detail, operationID: operationID)
                            self.appendLog("op read failed: \(detail)")
                        }
                    }
                    return
                }
                password = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                DispatchQueue.main.async {
                    guard self.activeOperationID == operationID else {
                        return
                    }
                    self.recordSecretUnavailable("Unable to run 1Password CLI", detail: error.localizedDescription, operationID: operationID)
                }
                return
            }
            case "environment":
                password = self.childEnvironment()[Config.passwordEnvVar] ?? ""
            case "keychain":
                do {
                    password = try KeychainPasswordStore.readPassword()
                } catch {
                    DispatchQueue.main.async {
                        guard self.activeOperationID == operationID else {
                            return
                        }
                        self.recordSecretUnavailable(
                            "Unable to read Kopia password from Keychain",
                            detail: String(describing: error),
                            operationID: operationID
                        )
                    }
                    return
                }
            case "command":
                guard let executable = Config.passwordCommand.first else {
                    DispatchQueue.main.async {
                        guard self.activeOperationID == operationID else {
                            return
                        }
                        self.recordSecretUnavailable("password_source is command but password_command is empty", operationID: operationID)
                    }
                    return
                }
                do {
                    let result = try CommandRunner.run(
                        executable,
                        arguments: Array(Config.passwordCommand.dropFirst()),
                        environment: self.childEnvironment(),
                        timeoutSeconds: Config.passwordReadTimeoutSeconds
                    )
                    if result.timedOut {
                        DispatchQueue.main.async {
                            guard self.activeOperationID == operationID else {
                                return
                            }
                            self.recordSecretUnavailable("Timed out reading Kopia password from password_command", operationID: operationID)
                        }
                        return
                    }
                    guard result.status == 0 else {
                        DispatchQueue.main.async {
                            guard self.activeOperationID == operationID else {
                                return
                            }
                            self.recordSecretUnavailable(
                                "password_command failed",
                                detail: "exit status \(result.status)",
                                operationID: operationID
                            )
                        }
                        return
                    }
                    password = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                } catch {
                    DispatchQueue.main.async {
                        guard self.activeOperationID == operationID else {
                            return
                        }
                        self.recordSecretUnavailable(
                            "Unable to run password_command",
                            detail: "process launch failed",
                            operationID: operationID
                        )
                    }
                    return
                }
            default:
                DispatchQueue.main.async {
                    guard self.activeOperationID == operationID else {
                        return
                    }
                    self.recordSecretUnavailable("Unsupported password_source '\(Config.passwordSource)'", operationID: operationID)
                }
                return
            }

            guard !password.isEmpty else {
                DispatchQueue.main.async {
                    guard self.activeOperationID == operationID else {
                        return
                    }
                    self.recordSecretUnavailable("Configured password source returned an empty Kopia password", operationID: operationID)
                }
                return
            }

            let launchScan = ProcessInspector.scanKopiaSnapshots()
            let launchReconciled = ProcessReconciler.reconcile(
                matching: launchScan.processes,
                activeRunRecord: self.readActiveRunRecord()
            )

            guard launchScan.succeeded else {
                DispatchQueue.main.async {
                    guard self.activeOperationID == operationID else {
                        return
                    }
                    self.recordPreflightFailure("Unable to inspect running Kopia processes before launch: \(launchScan.error ?? "unknown error")", operationID: operationID)
                }
                return
            }

            if launchReconciled.owned != nil
                || launchReconciled.starting != nil
                || !launchReconciled.external.isEmpty {
                DispatchQueue.main.async {
                    guard self.activeOperationID == operationID else {
                        return
                    }
                    _ = self.applyReconciledKopiaState(launchReconciled, reason: "pre-launch-\(trigger)")
                    self.clearOperation(id: operationID)
                    self.updateDerivedState()
                    self.writeStatus()
                }
                return
            }

            let runID = UUID().uuidString
            let startedAt = Date()
            let process = Process()
            let pipe = Pipe()
            var environment = self.childEnvironment()
            environment["KOPIA_PASSWORD"] = password
            environment["COPYA_RUN_ID"] = runID
            let kopiaArguments = KopiaCommand.snapshotCreateArguments()

            process.executableURL = URL(fileURLWithPath: kopiaPath)
            process.arguments = kopiaArguments
            process.environment = environment
            process.standardOutput = pipe
            process.standardError = pipe

            let initialRecord = ActiveRunRecord(
                run_id: runID,
                app_pid: ProcessInfo.processInfo.processIdentifier,
                child_pid: nil,
                executable: kopiaPath,
                command: process.arguments ?? [],
                backup_source: Config.backupSource,
                started_at: DateFormatters.iso.string(from: startedAt),
                updated_at: DateFormatters.iso.string(from: Date())
            )
            guard self.createActiveRunRecord(initialRecord) else {
                DispatchQueue.main.async {
                    guard self.activeOperationID == operationID else {
                        return
                    }
                    self.recordPreflightFailure("Another COPYA run is already starting or active", operationID: operationID)
                }
                return
            }

            DispatchQueue.main.sync {
                self.kopiaOutputBuffer = ""
                self.kopiaSuppressedDatalessReadErrors = 0
                self.kopiaOtherOutputReadErrors = 0
                self.kopiaOutputObservation = KopiaOutputObservation()
                self.observedKopiaFailure = nil
                self.lastKopiaOutputAt = nil
            }

            pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty else {
                    return
                }
                self?.handleKopiaOutputData(data)
            }

            process.terminationHandler = { [weak self] finished in
                DispatchQueue.main.async {
                    self?.handleBackupExit(status: finished.terminationStatus)
                }
            }

            do {
                try process.run()
            } catch {
                pipe.fileHandleForReading.readabilityHandler = nil
                self.removeActiveRunRecord()
                DispatchQueue.main.async {
                    guard self.activeOperationID == operationID else {
                        return
                    }
                    self.recordPreflightFailure("Unable to start Kopia: \(error.localizedDescription)", operationID: operationID)
                }
                return
            }

            self.appendDataToFile(
                "\(DateFormatters.log.string(from: Date())) raw kopia output starting run_id=\(runID) pid=\(process.processIdentifier)\n".data(using: .utf8) ?? Data(),
                path: Config.rawKopiaLogFile
            )

            var activeRecord = initialRecord
            activeRecord.child_pid = process.processIdentifier
            activeRecord.updated_at = DateFormatters.iso.string(from: Date())
            self.writeActiveRunRecord(activeRecord)

            DispatchQueue.main.async {
                guard self.activeOperationID == operationID else {
                    self.removeActiveRunRecord()
                    process.terminate()
                    return
                }

                self.activeProcess = process
                self.activePipe = pipe
                self.activePID = process.processIdentifier
                self.activeRunID = runID
                self.activePIDOwner = "current"
                self.externalKopiaPIDs = []
                self.livenessCheckAt = Date()
                self.internalKopiaActivity = InternalKopiaActivitySnapshot.unavailable(
                    reason: "waiting for per-PID Kopia logs",
                    activePID: process.processIdentifier,
                    activeRunID: runID,
                    runStartedAt: startedAt,
                    usedFallbackRunStart: false,
                    stdoutAt: nil
                )
                self.lastKopiaActivityHeartbeatLogAt = nil
                self.lastKopiaActivityHeartbeatSummary = nil
                self.stopReason = nil
                self.lastStartAt = startedAt
                self.lastFailure = nil
                self.lastFailureAt = nil
                self.lastFailureKind = nil
                self.lastFailureDetail = nil
                self.lastAbortReason = nil
                self.lastNetworkCheckAt = Date()
                self.kopiaRanAfterMaterialization = ranAfterMaterialization
                self.clearOperation(id: operationID)
                self.state = .syncing

                self.appendLog("kopia backup starting trigger=\(trigger) run_id=\(runID) pid=\(process.processIdentifier)")
                self.appendLog("running: \(KopiaCommand.display(arguments: kopiaArguments))")
                self.writeStatus()
            }
        }
    }

    private func runProtectedDataProbes() -> [ProtectedDataProbeResult] {
        Config.protectedDataProbePaths.map { path in
            let url = URL(fileURLWithPath: path)
            var isDirectory = ObjCBool(false)
            let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)

            guard exists else {
                return ProtectedDataProbeResult(
                    path: path,
                    exists: false,
                    readable: true,
                    is_directory: false,
                    error: nil
                )
            }

            do {
                if isDirectory.boolValue {
                    _ = try FileManager.default.contentsOfDirectory(atPath: path).prefix(1)
                } else {
                    let handle = try FileHandle(forReadingFrom: url)
                    _ = try handle.read(upToCount: 1)
                    try? handle.close()
                }

                return ProtectedDataProbeResult(
                    path: path,
                    exists: true,
                    readable: true,
                    is_directory: isDirectory.boolValue,
                    error: nil
                )
            } catch {
                return ProtectedDataProbeResult(
                    path: path,
                    exists: true,
                    readable: false,
                    is_directory: isDirectory.boolValue,
                    error: error.localizedDescription
                )
            }
        }
    }

    private func runCloudMaterialization(id: UUID) -> CloudMaterializationSnapshot {
        let startedAt = Date()
        let deadline = startedAt.addingTimeInterval(TimeInterval(Config.cloudMaterializationTimeoutSeconds))
        var roots: [CloudMaterializationRootResult] = []
        var abortReason: String?

        publishCloudMaterializationProgress(
            id: id,
            startedAt: startedAt,
            roots: [],
            currentRoot: nil,
            currentPhase: "starting",
            logMessage: "cloud materialization progress phase=starting roots=\(Config.cloudMaterializationRoots.count)"
        )

        for root in Config.cloudMaterializationRoots {
            if let reason = materializationAbortReason(for: id) {
                abortReason = reason
                break
            }

            let result = materializeRoot(
                root,
                deadline: deadline,
                id: id,
                progress: { phase, partial, shouldLog in
                    self.publishCloudMaterializationProgress(
                        id: id,
                        startedAt: startedAt,
                        roots: roots + [partial],
                        currentRoot: root,
                        currentPhase: phase,
                        logMessage: shouldLog ? self.cloudMaterializationLogMessage(phase: phase, result: partial) : nil
                    )
                }
            )
            roots.append(result)
            publishCloudMaterializationProgress(
                id: id,
                startedAt: startedAt,
                roots: roots,
                currentRoot: root,
                currentPhase: result.aborted ? "aborted" : (result.timed_out ? "timed out" : "root complete"),
                logMessage: nil
            )

            if result.aborted {
                abortReason = result.last_error ?? "cloud materialization aborted"
                break
            }

            if result.timed_out {
                abortReason = "cloud materialization timed out"
                break
            }
        }

        let totals = materializationTotals(roots: roots)
        let timedOut = roots.contains { $0.timed_out }
        let aborted = abortReason != nil && !timedOut
        let readFailures = totals.readFailures
        let datalessPlaceholders = totals.dataless
        let downloadFailures = totals.downloadRequestFailures
        let resolutionFailures = totals.placeholderResolutionFailures
        let completed = abortReason == nil && !timedOut
        let cloudCoverage: String
        if completed && datalessPlaceholders == 0 && readFailures == 0 && downloadFailures == 0 && resolutionFailures == 0 {
            cloudCoverage = "complete"
        } else if completed {
            cloudCoverage = "partial"
        } else {
            cloudCoverage = "blocked"
        }

        let reason: String?
        if completed && datalessPlaceholders == 0 && readFailures == 0 && downloadFailures == 0 && resolutionFailures == 0 {
            reason = "completed"
        } else if completed {
            var parts: [String] = []
            if datalessPlaceholders > 0 {
                parts.append("\(datalessPlaceholders) dataless placeholders")
            }
            if readFailures > 0 {
                parts.append("\(readFailures) read failures")
            }
            if downloadFailures > 0 {
                parts.append("\(downloadFailures) download request failures")
            }
            if resolutionFailures > 0 {
                parts.append("\(resolutionFailures) placeholder resolution failures")
            }
            reason = "completed with \(parts.joined(separator: ", "))"
        } else if let abortReason {
            reason = abortReason
        } else if readFailures > 0 {
            reason = "\(readFailures) cloud materialization read failures"
        } else {
            reason = "cloud materialization did not complete"
        }

        return CloudMaterializationSnapshot(
            enabled: Config.cloudMaterializationEnabled,
            started_at: DateFormatters.iso.string(from: startedAt),
            finished_at: DateFormatters.iso.string(from: Date()),
            completed: completed,
            aborted: aborted,
            reason: reason,
            current_root: nil,
            current_phase: nil,
            total_directories_seen: totals.directories,
            total_files_seen: totals.filesSeen,
            total_files_read: totals.filesRead,
            total_failures: readFailures,
            total_dataless_placeholders: datalessPlaceholders,
            total_read_failures: readFailures,
            total_dataless_entries: totals.datalessEntries,
            total_resolved_dataless_placeholders: totals.resolvedDataless,
            total_download_request_failures: totals.downloadRequestFailures,
            total_placeholder_resolution_failures: totals.placeholderResolutionFailures,
            cloud_coverage: cloudCoverage,
            roots: roots
        )
    }

    private func materializeRoot(
        _ root: String,
        deadline: Date,
        id: UUID,
        progress: (_ phase: String, _ result: CloudMaterializationRootResult, _ shouldLog: Bool) -> Void
    ) -> CloudMaterializationRootResult {
        let rootURL = URL(fileURLWithPath: root)
        var isDirectory = ObjCBool(false)
        let exists = FileManager.default.fileExists(atPath: root, isDirectory: &isDirectory)
        guard exists else {
            let result = CloudMaterializationRootResult(
                root: root,
                exists: false,
                directories_seen: 0,
                files_seen: 0,
                files_read: 0,
                failures: 0,
                aborted: false,
                timed_out: false,
                last_error: nil
            )
            progress("missing root", result, true)
            return result
        }

        var directoriesSeen = isDirectory.boolValue ? 1 : 0
        var filesSeen = 0
        var filesRead = 0
        var failures = 0
        var datalessPlaceholders = 0
        var datalessRecords: [String: CloudPlaceholderRecord] = [:]
        var datalessSamplePaths: [String] = []
        var readFailures = 0
        var readFailureSamplePaths: [String] = []
        var totalDatalessEntries = 0
        var resolvedDatalessPlaceholders = 0
        var downloadRequestFailures = 0
        var placeholderResolutionFailures = 0
        var datalessKindCounts: [String: Int] = [:]
        var placeholderFailureSamplePaths: [String] = []
        var aborted = false
        var timedOut = false
        var lastError: String?
        var lastStatusProgressAt = Date.distantPast
        var lastLogProgressAt = Date.distantPast
        var lastProgressUnits = 0
        let isICloudRoot = root.contains("/Library/Mobile Documents")
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey, .isRegularFileKey, .isUbiquitousItemKey]

        func rememberSample(_ path: String, in samples: inout [String]) {
            if samples.count < 5 {
                samples.append(path)
            }
        }

        func recordReadFailure(_ message: String, samplePath: String? = nil) {
            readFailures += 1
            failures = readFailures
            lastError = message
            rememberSample(samplePath ?? message, in: &readFailureSamplePaths)
        }

        func recordPlaceholderFailure(_ message: String, samplePath: String? = nil, downloadRequest: Bool = false) {
            if downloadRequest {
                downloadRequestFailures += 1
            } else {
                placeholderResolutionFailures += 1
            }
            lastError = message
            rememberSample(samplePath ?? message, in: &placeholderFailureSamplePaths)
        }

        func rememberDatalessPlaceholder(_ placeholder: CloudPlaceholderRecord, url: URL) {
            guard datalessRecords[placeholder.path] == nil else {
                return
            }

            var record = placeholder
            datalessRecords[placeholder.path] = record
            datalessPlaceholders += 1
            totalDatalessEntries += 1
            datalessKindCounts[placeholder.kind.rawValue, default: 0] += 1
            rememberSample(placeholder.path, in: &datalessSamplePaths)

            guard record.isICloudActionable else {
                return
            }

            do {
                try FileManager.default.startDownloadingUbiquitousItem(at: url)
            } catch {
                let message = "\(url.path): unable to request iCloud download: \(error.localizedDescription)"
                record.downloadRequestError = message
                datalessRecords[placeholder.path] = record
                recordPlaceholderFailure(message, samplePath: url.path, downloadRequest: true)
            }
        }

        func currentResult() -> CloudMaterializationRootResult {
            CloudMaterializationRootResult(
                root: root,
                exists: true,
                directories_seen: directoriesSeen,
                files_seen: filesSeen,
                files_read: filesRead,
                dataless_placeholders: datalessPlaceholders,
                read_failures: readFailures,
                failures: failures,
                aborted: aborted,
                timed_out: timedOut,
                last_error: lastError,
                dataless_sample_paths: datalessSamplePaths,
                read_failure_sample_paths: readFailureSamplePaths,
                total_dataless_entries: totalDatalessEntries,
                resolved_dataless_placeholders: resolvedDatalessPlaceholders,
                download_request_failures: downloadRequestFailures,
                placeholder_resolution_failures: placeholderResolutionFailures,
                dataless_kind_counts: datalessKindCounts,
                placeholder_failure_sample_paths: placeholderFailureSamplePaths
            )
        }

        func publishProgress(_ phase: String, forceLog: Bool = false) {
            let now = Date()
            let units = directoriesSeen + filesSeen
            let shouldUpdateStatus = forceLog
                || units - lastProgressUnits >= 500
                || now.timeIntervalSince(lastStatusProgressAt) >= 10
            guard shouldUpdateStatus else {
                return
            }

            let shouldLog = forceLog || now.timeIntervalSince(lastLogProgressAt) >= 60
            lastStatusProgressAt = now
            lastProgressUnits = units
            if shouldLog {
                lastLogProgressAt = now
            }
            progress(phase, currentResult(), shouldLog)
        }

        func refreshDatalessSamplePaths() {
            datalessSamplePaths = Array(datalessRecords.keys.sorted().prefix(5))
        }

        func markPlaceholderResolved(_ path: String) {
            datalessRecords.removeValue(forKey: path)
            datalessPlaceholders = max(0, datalessPlaceholders - 1)
            resolvedDatalessPlaceholders += 1
        }

        func finishRoot() -> CloudMaterializationRootResult {
            if isICloudRoot, !datalessRecords.isEmpty, Date() < deadline, !aborted, !timedOut {
                publishProgress("waiting for iCloud downloads", forceLog: true)
                let waitSeconds = min(10.0, max(0.0, deadline.timeIntervalSinceNow))
                if waitSeconds > 0 {
                    Thread.sleep(forTimeInterval: waitSeconds)
                }

                publishProgress("rescanning placeholders", forceLog: true)
                for path in datalessRecords.keys.sorted() {
                    if Date() >= deadline {
                        timedOut = true
                        lastError = "cloud materialization timed out while rescanning placeholders in \(root)"
                        break
                    }

                    if let reason = materializationAbortReason(for: id) {
                        aborted = true
                        lastError = reason
                        break
                    }

                    let url = URL(fileURLWithPath: path)
                    guard let statSnapshot = FileFlags.snapshot(for: url) else {
                        recordPlaceholderFailure("\(path): unable to stat placeholder during rescan", samplePath: path)
                        publishProgress("rescanning placeholders")
                        continue
                    }

                    guard !FileFlags.isDataless(statSnapshot) else {
                        publishProgress("rescanning placeholders")
                        continue
                    }

                    let values = try? url.resourceValues(forKeys: Set(keys))
                    let resolvedKind = CloudPlaceholderClassifier.kind(values: values, url: url)
                    if resolvedKind == .file {
                        do {
                            let handle = try FileHandle(forReadingFrom: url)
                            _ = try handle.read(upToCount: 1)
                            try? handle.close()
                            filesRead += 1
                            markPlaceholderResolved(path)
                        } catch {
                            recordReadFailure("\(url.path): \(error.localizedDescription)", samplePath: url.path)
                        }
                    } else {
                        markPlaceholderResolved(path)
                    }
                    publishProgress("rescanning placeholders")
                }

                refreshDatalessSamplePaths()
            }

            let result = currentResult()
            progress(timedOut ? "timed out" : (aborted ? "aborted" : "root complete"), result, true)
            return result
        }

        progress("root starting", currentResult(), true)

        if isICloudRoot,
           FileManager.default.isExecutableFile(atPath: "/usr/bin/brctl"),
           Date() < deadline {
            let timeout = min(max(Int(deadline.timeIntervalSinceNow), 1), 900)
            progress("icloud download", currentResult(), true)
            do {
                let result = try CommandRunner.run(
                    "/usr/bin/brctl",
                    arguments: ["download", root],
                    environment: childEnvironment(),
                    timeoutSeconds: timeout
                )
                if result.timedOut {
                    timedOut = true
                    lastError = "brctl download timed out for \(root)"
                } else if result.status != 0 {
                    lastError = sanitizedCommandError(result.stderr)
                }
            } catch {
                lastError = "unable to run brctl download for \(root): \(error.localizedDescription)"
            }
            progress("icloud download complete", currentResult(), true)
        }

        if timedOut {
            let result = currentResult()
            progress("timed out", result, true)
            return result
        }

        publishProgress("reading files", forceLog: true)

        var shouldEnumerateRoot = true
        let rootValues = try? rootURL.resourceValues(forKeys: Set(keys))
        if let rootPlaceholder = CloudPlaceholderClassifier.record(
            for: rootURL,
            root: root,
            values: rootValues,
            statSnapshot: FileFlags.snapshot(for: rootURL)
        ) {
            rememberDatalessPlaceholder(rootPlaceholder, url: rootURL)
            if rootPlaceholder.kind == .directory || rootPlaceholder.kind == .package {
                publishProgress("classifying placeholders", forceLog: true)
                shouldEnumerateRoot = false
            }
        }

        guard shouldEnumerateRoot else {
            return finishRoot()
        }

        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: { url, error in
                let values = try? url.resourceValues(forKeys: Set(keys))
                if let placeholder = CloudPlaceholderClassifier.record(
                    for: url,
                    root: root,
                    values: values,
                    statSnapshot: FileFlags.snapshot(for: url)
                ) {
                    rememberDatalessPlaceholder(placeholder, url: url)
                    return true
                }
                recordReadFailure("\(url.path): \(error.localizedDescription)", samplePath: url.path)
                return true
            }
        ) else {
            recordReadFailure("unable to enumerate \(root)", samplePath: root)
            let result = currentResult()
            progress("enumeration failed", result, true)
            return result
        }

        for case let url as URL in enumerator {
            if Date() >= deadline {
                timedOut = true
                lastError = "cloud materialization timed out while reading \(root)"
                break
            }

            if let reason = materializationAbortReason(for: id) {
                aborted = true
                lastError = reason
                break
            }

            do {
                let values = try url.resourceValues(forKeys: Set(keys))
                if let placeholder = CloudPlaceholderClassifier.record(
                    for: url,
                    root: root,
                    values: values,
                    statSnapshot: FileFlags.snapshot(for: url)
                ) {
                    if placeholder.kind == .directory || placeholder.kind == .package {
                        directoriesSeen += 1
                        enumerator.skipDescendants()
                    } else if placeholder.kind == .file {
                        filesSeen += 1
                    }
                    rememberDatalessPlaceholder(placeholder, url: url)
                    publishProgress("classifying placeholders")
                    continue
                }

                if values.isDirectory == true {
                    directoriesSeen += 1
                    publishProgress("reading files")
                    continue
                }

                guard values.isRegularFile == true else {
                    publishProgress("reading files")
                    continue
                }

                filesSeen += 1
                let handle = try FileHandle(forReadingFrom: url)
                _ = try handle.read(upToCount: 1)
                try? handle.close()
                filesRead += 1
            } catch {
                recordReadFailure("\(url.path): \(error.localizedDescription)", samplePath: url.path)
            }
            publishProgress("reading files")
        }

        return finishRoot()
    }

    private func publishCloudMaterializationProgress(
        id: UUID,
        startedAt: Date,
        roots: [CloudMaterializationRootResult],
        currentRoot: String?,
        currentPhase: String,
        logMessage: String? = nil
    ) {
        let totals = materializationTotals(roots: roots)
        let snapshot = CloudMaterializationSnapshot(
            enabled: Config.cloudMaterializationEnabled,
            started_at: DateFormatters.iso.string(from: startedAt),
            finished_at: nil,
            completed: false,
            aborted: false,
            reason: "running",
            current_root: currentRoot,
            current_phase: currentPhase,
            total_directories_seen: totals.directories,
            total_files_seen: totals.filesSeen,
            total_files_read: totals.filesRead,
            total_failures: totals.failures,
            total_dataless_placeholders: totals.dataless,
            total_read_failures: totals.readFailures,
            total_dataless_entries: totals.datalessEntries,
            total_resolved_dataless_placeholders: totals.resolvedDataless,
            total_download_request_failures: totals.downloadRequestFailures,
            total_placeholder_resolution_failures: totals.placeholderResolutionFailures,
            cloud_coverage: "running",
            roots: roots
        )

        DispatchQueue.main.async {
            guard self.activeMaterializationID == id else {
                return
            }

            self.cloudMaterialization = snapshot
            if let logMessage {
                self.appendLog(logMessage)
            }
            self.writeStatus()
        }
    }

    private func cloudMaterializationLogMessage(
        phase: String,
        result: CloudMaterializationRootResult
    ) -> String {
        var message = "cloud materialization progress phase=\(phase) root=\"\(result.root)\" directories_seen=\(result.directories_seen) files_seen=\(result.files_seen) files_read=\(result.files_read) dataless_placeholders=\(result.dataless_placeholders) read_failures=\(result.read_failures)"
        if let totalDatalessEntries = result.total_dataless_entries, totalDatalessEntries > 0 {
            message += " dataless_entries=\(totalDatalessEntries)"
        }
        if let resolved = result.resolved_dataless_placeholders, resolved > 0 {
            message += " resolved_dataless=\(resolved)"
        }
        if let downloadFailures = result.download_request_failures, downloadFailures > 0 {
            message += " download_request_failures=\(downloadFailures)"
        }
        if let resolutionFailures = result.placeholder_resolution_failures, resolutionFailures > 0 {
            message += " placeholder_resolution_failures=\(resolutionFailures)"
        }
        if let lastError = result.last_error, !lastError.isEmpty {
            message += " last_error=\"\(lastError)\""
        }
        return message
    }

    private func cloudCapacityEstimateLogMessage(_ estimate: CloudCapacityEstimate) -> String {
        var message = "cloud capacity estimate confidence=\(estimate.confidence) ok=\(estimate.ok) icloud_known_bytes=\(estimate.icloud_known_bytes) icloud_unknown_count=\(estimate.icloud_unknown_count) icloud_unknown_fallback_bytes=\(estimate.icloud_unknown_fallback_bytes) fileprovider_advisory_known_bytes=\(estimate.fileprovider_advisory_known_bytes) fileprovider_advisory_unknown_count=\(estimate.fileprovider_advisory_unknown_count) execution_reserve_bytes=\(estimate.execution_reserve_bytes) capacity_api=\(estimate.capacity_api)"
        if !estimate.warnings.isEmpty {
            message += " warnings=\(estimate.warnings.joined(separator: ","))"
        }
        if let reason = estimate.reason {
            message += " reason=\"\(reason)\""
        }
        return message
    }

    private func materializationAbortReason(for id: UUID) -> String? {
        if isMaterializationCancelled(id) {
            return "cloud materialization cancelled"
        }

        guard Config.cloudMaterializationRequiresAllowedNetwork else {
            return nil
        }

        let now = Date()
        materializationControlLock.lock()
        let shouldCheckNetwork = now.timeIntervalSince(lastMaterializationNetworkCheckAt) >= TimeInterval(Config.networkCheckIntervalSeconds)
        if shouldCheckNetwork {
            lastMaterializationNetworkCheckAt = now
        }
        materializationControlLock.unlock()

        guard shouldCheckNetwork else {
            return nil
        }

        let snapshot = NetworkPolicy.current(isExpensive: false, isConstrained: false)
        guard !snapshot.allowed else {
            return nil
        }
        return "network no longer allowed: state=\(snapshot.state) ssid='\(snapshot.ssid ?? "")' reason='\(snapshot.reason)'"
    }

    private func abortedMaterializationSnapshot(reason: String) -> CloudMaterializationSnapshot {
        CloudMaterializationSnapshot(
            enabled: Config.cloudMaterializationEnabled,
            started_at: cloudMaterialization.started_at,
            finished_at: DateFormatters.iso.string(from: Date()),
            completed: false,
            aborted: true,
            reason: reason,
            current_root: nil,
            current_phase: nil,
            total_directories_seen: 0,
            total_files_seen: 0,
            total_files_read: 0,
            total_failures: 0,
            total_dataless_placeholders: 0,
            total_read_failures: 0,
            total_dataless_entries: 0,
            total_resolved_dataless_placeholders: 0,
            total_download_request_failures: 0,
            total_placeholder_resolution_failures: 0,
            cloud_coverage: "blocked",
            roots: []
        )
    }

    private func materializationTotals(
        roots: [CloudMaterializationRootResult]
    ) -> (
        directories: Int,
        filesSeen: Int,
        filesRead: Int,
        failures: Int,
        dataless: Int,
        readFailures: Int,
        datalessEntries: Int,
        resolvedDataless: Int,
        downloadRequestFailures: Int,
        placeholderResolutionFailures: Int
    ) {
        roots.reduce((
            directories: 0,
            filesSeen: 0,
            filesRead: 0,
            failures: 0,
            dataless: 0,
            readFailures: 0,
            datalessEntries: 0,
            resolvedDataless: 0,
            downloadRequestFailures: 0,
            placeholderResolutionFailures: 0
        )) { partial, root in
            (
                directories: partial.directories + root.directories_seen,
                filesSeen: partial.filesSeen + root.files_seen,
                filesRead: partial.filesRead + root.files_read,
                failures: partial.failures + root.failures,
                dataless: partial.dataless + root.dataless_placeholders,
                readFailures: partial.readFailures + root.read_failures,
                datalessEntries: partial.datalessEntries + (root.total_dataless_entries ?? root.dataless_placeholders),
                resolvedDataless: partial.resolvedDataless + (root.resolved_dataless_placeholders ?? 0),
                downloadRequestFailures: partial.downloadRequestFailures + (root.download_request_failures ?? 0),
                placeholderResolutionFailures: partial.placeholderResolutionFailures + (root.placeholder_resolution_failures ?? 0)
            )
        }
    }

    func stopBackup(
        reason: String = "manual stop",
        failureKind: String? = nil,
        failureDetail: String? = nil
    ) {
        guard !viewerOnly else {
            appendLog("stop ignored: menu is in viewer mode because launch agent owns backup control")
            return
        }

        if let operationID = activeOperationID, activeMaterializationID == nil, activeProcess == nil {
            clearOperation(id: operationID)
            lastAbortReason = reason
            appendLog("abort: \(reason); cancelled pending operation")
            updateDerivedState()
            writeStatus()
            return
        }

        if let materializationID = activeMaterializationID {
            markMaterializationCancelled(materializationID)
            activeMaterializationID = nil
            clearOperation()
            lastAbortReason = reason
            appendLog("abort: \(reason); stopping cloud materialization")
            updateDerivedState()
            writeStatus()
            return
        }

        if let process = activeProcess {
            stopReason = reason
            stopFailureKind = failureKind
            stopFailureDetail = failureDetail
            lastAbortReason = reason
            appendLog("abort: \(reason); stopping kopia pid \(process.processIdentifier)")
            process.terminate()

            forceTerminateOwnedProcessAfterGracePeriod(process)
            return
        }

        if let activePID {
            stopReason = reason
            stopFailureKind = failureKind
            stopFailureDetail = failureDetail
            lastAbortReason = reason
            appendLog("abort: \(reason); stopping recovered Kopia pid \(activePID)")
            ProcessInspector.terminate(pids: [activePID])
            removeActiveRunRecord()
            activePIDOwner = nil
            activeRunID = nil

            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                self?.processQueue.async { [weak self] in
                    let stillRunning = ProcessInspector.matchingKopiaSnapshots().contains(where: { $0.pid == activePID })
                    DispatchQueue.main.async {
                        guard let self else {
                            return
                        }
                        guard stillRunning else {
                            self.reconcileLiveKopiaProcesses(reason: "stop-recovered", shouldEvaluateSchedule: false)
                            return
                        }
                        self.appendLog("abort: recovered Kopia pid \(activePID) did not stop after TERM; sending KILL")
                        ProcessInspector.forceTerminate(pids: [activePID])
                        self.reconcileLiveKopiaProcesses(reason: "stop-recovered", shouldEvaluateSchedule: false)
                    }
                }
            }
            self.activePID = nil
            if let failureKind {
                let detail = failureDetail ?? reason
                stopReason = nil
                stopFailureKind = nil
                stopFailureDetail = nil
                recordFailure(reason, kind: failureKind, detail: detail)
                return
            }
            updateDerivedState()
            writeStatus()
            return
        }

        if activePIDOwner == "starting" {
            lastAbortReason = reason
            appendLog("abort: \(reason); clearing active run start marker")
            removeActiveRunRecord()
            activePIDOwner = nil
            activeRunID = nil
            activeOperation = nil
            activeOperationStartedAt = nil
            activeOperationDetail = nil
            updateDerivedState()
            writeStatus()
            return
        }

        if !externalKopiaPIDs.isEmpty {
            appendLog("stop ignored: external Kopia pids are not owned by COPYA pids=\(externalKopiaPIDs.map { String($0) }.joined(separator: ","))")
        }
        updateDerivedState()
        writeStatus()
    }

    private func forceTerminateOwnedProcessAfterGracePeriod(_ process: Process) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard process.isRunning else {
                return
            }
            self?.appendLog("abort: kopia pid \(process.processIdentifier) did not stop after TERM; sending KILL")
            kill(process.processIdentifier, SIGKILL)
        }
    }

    func openLog() {
        NSWorkspace.shared.open(URL(fileURLWithPath: Config.logFile))
    }

    func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    func copyDebugStatus() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(currentStatus()),
              let string = String(data: data, encoding: .utf8) else {
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    func quit() {
        if canStopManual {
            stopBackup(reason: "monitor quitting")
        }
        appendLog("monitor quitting")
        NSApp.terminate(nil)
    }

    var menuTitle: String {
        switch state {
        case .ready:
            return "Ready"
        case .startingBackup:
            return "Starting Backup"
        case .preparingCloudFiles:
            return "Preparing Cloud Files"
        case .syncing:
            return "Syncing"
        case .externalBackupDetected:
            return "External Backup Detected"
        case .paused:
            return "Paused"
        case .needsPermission:
            return "Needs Permission"
        case .needsFullDiskAccess:
            return "Needs Full Disk Access"
        case .needsDiskSpace:
            return "Needs Disk Space"
        case .needsSecret:
            if Config.passwordSource == "onepassword" {
                return "Needs 1Password Unlock"
            }
            if Config.passwordSource == "keychain" {
                return "Needs Keychain Password"
            }
            return "Secret Unavailable"
        case .setupIncomplete:
            return "Setup Required"
        case .cloudDownloadBlocked:
            return "Cloud Download Blocked"
        case .cloudPartial:
            return "Cloud Partial"
        case .backupPartial:
            if lastSnapshotResult == KopiaSnapshotResult.partialActionRequired {
                return "Backup Partial, Needs Attention"
            }
            return "Backup Partial"
        case .failed:
            return "Failed"
        case .disabled:
            return "Disabled"
        }
    }

    var menuSystemImage: String {
        switch state {
        case .ready:
            return "checkmark.circle"
        case .startingBackup:
            return "hourglass.circle"
        case .preparingCloudFiles:
            return "icloud.and.arrow.down"
        case .syncing:
            return "arrow.triangle.2.circlepath.circle"
        case .externalBackupDetected:
            return "person.crop.circle.badge.exclamationmark"
        case .paused:
            return "pause.circle"
        case .needsPermission, .needsFullDiskAccess, .needsDiskSpace, .needsSecret, .setupIncomplete, .cloudDownloadBlocked, .failed:
            return "exclamationmark.triangle"
        case .backupPartial:
            if lastSnapshotResult == KopiaSnapshotResult.partialActionRequired {
                return "exclamationmark.triangle"
            }
            return "checkmark.circle"
        case .cloudPartial:
            return "icloud.slash"
        case .disabled:
            return "wifi.slash"
        }
    }

    var canStartManual: Bool {
        !viewerOnly
            && activeProcess == nil
            && activePID == nil
            && activeRunID == nil
            && activeMaterializationID == nil
            && activeOperationID == nil
            && externalKopiaPIDs.isEmpty
            && setupGate.complete
            && network.allowed
            && diskHealth.ok
    }

    var canStopManual: Bool {
        !viewerOnly
            && (activeProcess != nil
            || activePID != nil
            || activePIDOwner == "starting"
            || activeMaterializationID != nil
            || activeOperationID != nil)
    }

    var canManageLoginAgent: Bool {
        !viewerOnly
    }

    var ssidText: String {
        network.ssid ?? "unknown"
    }

    var nextRunText: String {
        guard let nextRunAt else {
            return "not scheduled"
        }
        return DateFormatters.menu.string(from: nextRunAt)
    }

    var lastSuccessText: String {
        guard let lastSuccessAt else {
            return "never"
        }
        return DateFormatters.menu.string(from: lastSuccessAt)
    }

    var lastSnapshotText: String? {
        guard let lastSnapshotAt else {
            return nil
        }
        let result = lastSnapshotResult ?? "unknown"
        let time = DateFormatters.menu.string(from: lastSnapshotAt)
        if result == KopiaSnapshotResult.clean {
            return "\(time) (clean)"
        }
        let issueCount = lastSnapshotErrorCount ?? 0
        if result == KopiaSnapshotResult.partialActionRequired {
            return "\(time) (partial, \(issueCount) issues need attention)"
        }
        if result == KopiaSnapshotResult.partialTolerated {
            return "\(time) (partial, \(issueCount) tolerated issues)"
        }
        return "\(time) (\(result))"
    }

    var lastSnapshotIssueText: String? {
        guard lastSnapshotResult == KopiaSnapshotResult.partialActionRequired else {
            return nil
        }
        if let sample = lastSnapshotIssueSamples.first {
            if let path = sample.path {
                return "\(sample.category): \(path)"
            }
            return sample.detail
        }
        let actionCount = lastSnapshotActionRequiredCount ?? 0
        guard actionCount > 0 else {
            return nil
        }
        return "\(actionCount) action-required file read issues"
    }

    var activePIDText: String {
        guard let activePID else {
            return "none"
        }
        return String(activePID)
    }

    var activeOperationText: String? {
        guard let activeOperation else {
            return nil
        }
        let detail = activeOperationDetail ?? activeOperation
        let elapsed = durationText(since: activeOperationStartedAt, now: Date())
        return "\(detail), \(elapsed)"
    }

    var externalKopiaPIDsText: String? {
        guard !externalKopiaPIDs.isEmpty else {
            return nil
        }
        return externalKopiaPIDs.map { String($0) }.joined(separator: ",")
    }

    var backupLivenessText: String {
        guard activePID != nil else {
            return "idle"
        }

        let elapsed = viewerBackupElapsedSeconds.map { durationText(seconds: $0) } ?? durationText(since: lastStartAt, now: livenessCheckAt)
        let heartbeatAge = relativeAgeText(since: livenessCheckAt, now: Date())
        let owner = activePIDOwner ?? "unknown"
        return "\(owner), running \(elapsed), checked \(heartbeatAge) ago, \(kopiaActivityMenuText)"
    }

    var kopiaActivityMenuText: String {
        if internalKopiaActivity.confidence == "internal-log"
            || internalKopiaActivity.confidence == "internal-log-mtime" {
            let summary = internalKopiaActivity.summary ?? "Kopia activity"
            if let activityAt = parseDate(internalKopiaActivity.latest_activity_at) {
                return "\(summary) \(relativeAgeText(since: activityAt, now: livenessCheckAt)) ago via Kopia logs"
            }
            return "\(summary) via Kopia logs"
        }

        if let lastKopiaOutputAt {
            return "stdout output \(relativeAgeText(since: lastKopiaOutputAt, now: livenessCheckAt)) ago"
        }

        if activeProcess == nil, activePIDOwner == "recovered" {
            return "internal log activity unavailable after monitor recovery"
        }

        if internalKopiaActivity.confidence == "unavailable"
            || internalKopiaActivity.confidence == "disabled" {
            return "internal log activity unavailable; process still running"
        }

        return "no recent activity observed; process still running"
    }

    var kopiaIssueText: String? {
        guard activeProcess != nil || activePID != nil else {
            return nil
        }

        if kopiaSuppressedDatalessReadErrors == 0 && kopiaOtherOutputReadErrors == 0 {
            return nil
        }

        var parts: [String] = []
        if kopiaSuppressedDatalessReadErrors > 0 {
            parts.append("\(kopiaSuppressedDatalessReadErrors) dataless placeholder reads logged from Kopia stdout")
        }
        if kopiaOtherOutputReadErrors > 0 {
            parts.append("\(kopiaOtherOutputReadErrors) file read issues logged from Kopia stdout")
        }
        return parts.joined(separator: ", ")
    }

    var diskHealthText: String? {
        guard diskHealth.threshold_kind != "unknown" else {
            return nil
        }
        if diskHealth.ok {
            return nil
        }
        return diskHealth.reason ?? "disk space check failed"
    }

    var cloudCapacityEstimateText: String? {
        guard cloudCapacityEstimate.checked_at != nil else {
            return nil
        }

        let estimate = cloudCapacityEstimate
        let requiredBytes = estimate.volumes.reduce(Int64(0)) { $0 + $1.required_bytes }
        let reserveBytes = estimate.volumes.reduce(Int64(0)) { $0 + $1.execution_reserve_bytes }
        let actionableCloudBytes = estimate.icloud_known_bytes + estimate.icloud_unknown_fallback_bytes
        if !estimate.ok {
            return "insufficient, needs \(byteText(requiredBytes)), \(estimate.confidence)"
        }

        var text = "\(byteText(actionableCloudBytes)) cloud + \(byteText(reserveBytes)) reserve, \(estimate.confidence)"
        if estimate.fileprovider_advisory_known_bytes > 0 || estimate.fileprovider_advisory_unknown_count > 0 {
            text += ", FileProvider advisory"
        }
        return text
    }

    var cloudMaterializationText: String {
        if activeMaterializationID != nil {
            let phase = cloudMaterialization.current_phase ?? "running"
            let datalessPlaceholders = cloudMaterialization.total_dataless_placeholders ?? 0
            let datalessEntries = cloudMaterialization.total_dataless_entries ?? datalessPlaceholders
            if let root = cloudMaterialization.current_root {
                let rootName = URL(fileURLWithPath: root).lastPathComponent
                return "\(rootName): \(phase), \(cloudMaterialization.total_files_read)/\(cloudMaterialization.total_files_seen) files, \(datalessPlaceholders)/\(datalessEntries) unresolved placeholders"
            }
            return phase
        }

        guard Config.cloudMaterializationEnabled else {
            return "disabled"
        }

        if cloudMaterialization.completed {
            let datalessPlaceholders = cloudMaterialization.total_dataless_placeholders ?? 0
            let readFailures = cloudMaterialization.total_read_failures ?? cloudMaterialization.total_failures
            let datalessEntries = cloudMaterialization.total_dataless_entries ?? datalessPlaceholders
            let downloadFailures = cloudMaterialization.total_download_request_failures ?? 0
            let resolutionFailures = cloudMaterialization.total_placeholder_resolution_failures ?? 0
            if datalessPlaceholders > 0 || readFailures > 0 || downloadFailures > 0 || resolutionFailures > 0 {
                var parts = [
                    "\(datalessPlaceholders)/\(datalessEntries) unresolved placeholders",
                    "\(readFailures) read failures",
                ]
                if downloadFailures > 0 {
                    parts.append("\(downloadFailures) download request failures")
                }
                if resolutionFailures > 0 {
                    parts.append("\(resolutionFailures) placeholder resolution failures")
                }
                if let sample = firstCloudMaterializationSample {
                    parts.append("sample: \(URL(fileURLWithPath: sample).lastPathComponent)")
                }
                return "partial: \(parts.joined(separator: ", "))"
            }
            return "complete: \(cloudMaterialization.total_files_read) files checked"
        }

        if let reason = cloudMaterialization.reason {
            return reason
        }

        return "not run"
    }

    var firstCloudMaterializationSample: String? {
        for root in cloudMaterialization.roots {
            if let sample = root.read_failure_sample_paths.first {
                return sample
            }
            if let sample = root.placeholder_failure_sample_paths.first {
                return sample
            }
            if let sample = root.dataless_sample_paths.first {
                return sample
            }
        }
        return nil
    }

    private func durationText(since start: Date?, now: Date) -> String {
        guard let start else {
            return "0s"
        }
        return durationText(seconds: Int(now.timeIntervalSince(start)))
    }

    private func durationText(seconds rawSeconds: Int) -> String {
        let seconds = max(0, rawSeconds)
        if seconds < 60 {
            return "\(seconds)s"
        }
        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes)m \(seconds % 60)s"
        }
        let hours = minutes / 60
        return "\(hours)h \(minutes % 60)m"
    }

    private func byteText(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func relativeAgeText(since date: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 {
            return "\(seconds)s"
        }
        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        return "\(hours)h \(minutes % 60)m"
    }

    private func tick() {
        let now = Date()
        livenessCheckAt = now
        let elapsed = now.timeIntervalSince(lastNetworkCheckAt)
        if elapsed >= TimeInterval(Config.networkCheckIntervalSeconds) {
            refreshNetwork(reason: "timer", shouldEvaluateSchedule: true)
        }

        if activeMaterializationID != nil && Config.cloudMaterializationRequiresAllowedNetwork && !network.allowed {
            stopBackup(reason: "network no longer allowed during cloud materialization: state=\(network.state) ssid='\(network.ssid ?? "")' reason='\(network.reason)'")
            return
        }

        if activeOperationID != nil && activeMaterializationID == nil && activeProcess == nil {
            writeStatus()
        }

        if activeProcess == nil
            && activePID == nil
            && activeMaterializationID == nil
            && activeOperationID == nil
            && (lastFailureKind == "disk_space_exhausted" || diskHealth.threshold_kind == "unknown") {
            refreshDiskHealth(
                requiredBytes: Config.minimumExecutionReserveBytes,
                thresholdKind: "start"
            )
            updateDerivedState()
            writeStatus()
        }

        if let process = activeProcess {
            if !process.isRunning {
                handleBackupExit(status: process.terminationStatus)
                return
            }

            let runtimeDiskHealth = refreshDiskHealth(
                requiredBytes: Config.criticalRuntimeFreeSpaceBytes,
                thresholdKind: "runtime"
            )
            if !runtimeDiskHealth.ok {
                let detail = runtimeDiskHealth.reason ?? "disk space below critical runtime threshold"
                stopBackup(
                    reason: "disk space below critical threshold: \(detail)",
                    failureKind: "disk_space_exhausted",
                    failureDetail: detail
                )
                return
            }

            if !network.allowed {
                stopBackup(reason: "network no longer allowed: state=\(network.state) ssid='\(network.ssid ?? "")' reason='\(network.reason)'")
            }
        }

        if activeProcess == nil, activePIDOwner == "recovered", activePID != nil {
            let runtimeDiskHealth = refreshDiskHealth(
                requiredBytes: Config.criticalRuntimeFreeSpaceBytes,
                thresholdKind: "runtime"
            )
            if !runtimeDiskHealth.ok {
                let detail = runtimeDiskHealth.reason ?? "disk space below critical runtime threshold"
                stopBackup(
                    reason: "disk space below critical threshold: \(detail)",
                    failureKind: "disk_space_exhausted",
                    failureDetail: detail
                )
                return
            }

            if !network.allowed {
                stopBackup(reason: "network no longer allowed: state=\(network.state) ssid='\(network.ssid ?? "")' reason='\(network.reason)'")
                return
            }
            reconcileLiveKopiaProcesses(reason: "recovered-poll", shouldEvaluateSchedule: false)
        } else if !externalKopiaPIDs.isEmpty {
            reconcileLiveKopiaProcesses(reason: "external-poll", shouldEvaluateSchedule: false)
        }

        if activeProcess != nil || activePID != nil || activeMaterializationID != nil || activeOperationID != nil || !externalKopiaPIDs.isEmpty {
            refreshInternalKopiaActivity(reason: "tick")
            writeStatus()
        }
    }

    private func refreshNetwork(reason: String, shouldEvaluateSchedule: Bool) {
        let wasAllowed = network.allowed
        network = currentNetworkSnapshot()
        lastNetworkCheckAt = Date()
        let becameAllowed = !wasAllowed && network.allowed

        if shouldEvaluateSchedule {
            evaluateSchedule(becameAllowed: becameAllowed, reason: reason)
        }

        updateDerivedState()
        writeStatus()
    }

    private func currentNetworkSnapshot() -> NetworkSnapshot {
        NetworkPolicy.current(
            isExpensive: pathIsExpensive,
            isConstrained: pathIsConstrained,
            authorization: locationManager.authorizationStatus
        )
    }

    private func evaluateSchedule(becameAllowed: Bool, reason: String) {
        guard startupReady else {
            return
        }
        guard activeProcess == nil else {
            return
        }
        guard activePID == nil else {
            return
        }
        guard activeRunID == nil else {
            return
        }
        guard activeMaterializationID == nil else {
            return
        }
        guard activeOperationID == nil else {
            return
        }
        guard externalKopiaPIDs.isEmpty else {
            return
        }

        let now = Date()

        if network.allowed {
            if lastSuccessAt == nil && lastSnapshotAt == nil && (becameAllowed || reason == "startup") {
                if let nextRunAt,
                   now < nextRunAt,
                   lastFailureAt != nil {
                    return
                }

                startBackup(trigger: "first-allowed-network")
                return
            }

            if let nextRunAt, now >= nextRunAt {
                startBackup(trigger: "scheduled")
                return
            }

            return
        }

        if let nextRunAt, now >= nextRunAt {
            let skipReason = "scheduled backup skipped: network_state=\(network.state) reason='\(network.reason)'"
            lastAbortReason = skipReason
            self.nextRunAt = now.addingTimeInterval(TimeInterval(Config.runIntervalSeconds))
            appendLog("skip: \(skipReason); next_run_at=\(DateFormatters.iso.string(from: self.nextRunAt!))")
        }
    }

    private func handleBackupExit(status: Int32) {
        appendLog("kopia backup exit observed status=\(status)")
        activePipe?.fileHandleForReading.readabilityHandler = nil
        flushKopiaOutputSummary()
        let now = Date()
        let parsedRun = kopiaOutputObservation.finish(
            status: status,
            runID: activeRunID,
            pid: activePID,
            startedAt: lastStartAt,
            completedAt: now
        )
        appendDataToFile(
            "\(DateFormatters.log.string(from: Date())) raw kopia output finished status=\(status)\n".data(using: .utf8) ?? Data(),
            path: Config.rawKopiaLogFile
        )
        activePipe = nil
        activeProcess = nil
        activePID = nil
        activeRunID = nil
        activePIDOwner = nil
        internalKopiaActivity = .inactive()
        lastKopiaActivityHeartbeatLogAt = nil
        lastKopiaActivityHeartbeatSummary = nil
        kopiaOutputObservation = KopiaOutputObservation()
        removeActiveRunRecord()

        if let reason = stopReason {
            lastAbortReason = reason
            nextRunAt = now.addingTimeInterval(TimeInterval(Config.runIntervalSeconds))
            if let stopFailureKind {
                let detail = stopFailureDetail ?? reason
                stopReason = nil
                self.stopFailureKind = nil
                stopFailureDetail = nil
                recordFailure(reason, kind: stopFailureKind, detail: detail)
                return
            }
            appendLog("kopia backup aborted intentionally: \(reason)")
            stopReason = nil
            stopFailureDetail = nil
            completeOneShot(exitCode: status == 0 ? 0 : 1)
        } else if status == 0 {
            lastSuccessAt = now
            lastSuccessCloudCoverage = cloudMaterialization.cloud_coverage ?? inferredCloudCoverage(cloudMaterialization)
            lastFailureAt = nil
            lastFailure = nil
            lastFailureKind = nil
            lastFailureDetail = nil
            lastAbortReason = nil
            fullDiskAccessBlocked = false
            cloudDownloadBlocked = false
            nextRunAt = now.addingTimeInterval(TimeInterval(Config.runIntervalSeconds))
            recordSnapshotResult(parsedRun, completedAt: now)
            appendLog("success: kopia snapshot complete")
            completeOneShot(exitCode: 0)
        } else if parsedRun.snapshot_id != nil,
                  parsedRun.snapshot_result == KopiaSnapshotResult.partialTolerated
                    || parsedRun.snapshot_result == KopiaSnapshotResult.partialActionRequired {
            recordSnapshotResult(parsedRun, completedAt: now)
            nextRunAt = now.addingTimeInterval(TimeInterval(Config.runIntervalSeconds))
            let attention = parsedRun.snapshot_result == KopiaSnapshotResult.partialActionRequired ? " action_required=\(parsedRun.action_required_count)" : ""
            appendLog("partial: kopia snapshot created id=\(parsedRun.snapshot_id ?? "unknown") result=\(parsedRun.snapshot_result) fatal_errors=\(parsedRun.fatal_error_count)\(attention)")
            completeOneShot(exitCode: 1)
        } else {
            let classification = observedKopiaFailure ?? KopiaFailureClassifier.generic(status: status)
            recordFailure(
                classification.message,
                kind: classification.kind,
                detail: classification.detail
            )
            return
        }

        appendLog("kopia backup finished")
        refreshNetwork(reason: "backup-exit", shouldEvaluateSchedule: false)
    }

    private func recordSnapshotResult(_ parsedRun: KopiaParsedRun, completedAt: Date) {
        lastSnapshotAt = completedAt
        lastSnapshotID = parsedRun.snapshot_id
        lastSnapshotRoot = parsedRun.snapshot_root
        lastSnapshotDuration = parsedRun.snapshot_duration
        lastSnapshotResult = parsedRun.snapshot_result
        lastSnapshotErrorCount = parsedRun.fatal_error_count
        lastSnapshotToleratedCount = parsedRun.tolerated_count
        lastSnapshotActionRequiredCount = parsedRun.action_required_count
        lastSnapshotUnclassifiedCount = parsedRun.unclassified_count
        lastSnapshotIssueCounts = parsedRun.categorized_counts
        lastSnapshotIssueSamples = parsedRun.samples
        if parsedRun.snapshot_result == KopiaSnapshotResult.clean {
            lastSnapshotIssueCounts = [:]
            lastSnapshotIssueSamples = []
            lastSnapshotErrorCount = 0
            lastSnapshotToleratedCount = 0
            lastSnapshotActionRequiredCount = 0
            lastSnapshotUnclassifiedCount = 0
        }
        if parsedRun.snapshot_result == KopiaSnapshotResult.partialTolerated
            || parsedRun.snapshot_result == KopiaSnapshotResult.partialActionRequired {
            lastFailureAt = nil
            lastFailure = nil
            lastFailureKind = nil
            lastFailureDetail = nil
            lastAbortReason = nil
            fullDiskAccessBlocked = false
            cloudDownloadBlocked = false
        }
    }

    private func handleRecoveredBackupExit() {
        appendLog("recovered Kopia process exit observed; status unavailable")
        activePID = nil
        activeRunID = nil
        activePIDOwner = nil
        removeActiveRunRecord()

        let now = Date()
        if let reason = stopReason {
            lastAbortReason = reason
            nextRunAt = now.addingTimeInterval(TimeInterval(Config.runIntervalSeconds))
            appendLog("recovered Kopia backup aborted intentionally: \(reason)")
            stopReason = nil
        } else {
            lastFailureAt = now
            lastFailure = "Recovered Kopia process exited; exit status unavailable"
            lastFailureKind = "recovered_exit_unknown"
            lastFailureDetail = "recovered Kopia process exited without a status visible to COPYA"
            nextRunAt = now.addingTimeInterval(TimeInterval(Config.runIntervalSeconds))
            appendLog("warning: recovered Kopia process exited; status unavailable")
        }

        updateDerivedState()
        writeStatus()
    }

    private func recordFailure(
        _ message: String,
        kind: String? = nil,
        detail: String? = nil
    ) {
        clearOperation()
        lastFailureAt = Date()
        lastFailure = message
        lastFailureKind = kind
        lastFailureDetail = detail
        fullDiskAccessBlocked = false
        cloudDownloadBlocked = false
        nextRunAt = Date().addingTimeInterval(TimeInterval(Config.runIntervalSeconds))
        let kindText = kind.map { " kind=\($0)" } ?? ""
        let detailText = detail.map { " detail=\"\($0)\"" } ?? ""
        appendLog("failure\(kindText): \(message)\(detailText)")
        updateDerivedState()
        writeStatus()
        completeOneShot(exitCode: 1)
    }

    private func recordPreflightFailure(_ message: String, operationID: UUID? = nil) {
        clearOperation(id: operationID)
        lastFailureAt = Date()
        lastFailure = message
        lastFailureKind = "preflight_failed"
        lastFailureDetail = message
        fullDiskAccessBlocked = false
        cloudDownloadBlocked = false
        nextRunAt = Date().addingTimeInterval(TimeInterval(Config.preflightFailureRetrySeconds))
        appendLog("failure: \(message); retrying preflight at \(DateFormatters.iso.string(from: nextRunAt!))")
        updateDerivedState()
        writeStatus()
        completeOneShot(exitCode: 1)
    }

    private func recordSecretUnavailable(
        _ message: String,
        detail: String? = nil,
        operationID: UUID? = nil
    ) {
        clearOperation(id: operationID)
        lastFailureAt = Date()
        lastFailure = message
        lastFailureKind = "secret_unavailable"
        lastFailureDetail = detail ?? message
        fullDiskAccessBlocked = false
        cloudDownloadBlocked = false
        nextRunAt = Date().addingTimeInterval(TimeInterval(Config.preflightFailureRetrySeconds))
        let detailText = detail.map { " detail=\"\($0)\"" } ?? ""
        appendLog("secret unavailable: \(message)\(detailText); retrying preflight at \(DateFormatters.iso.string(from: nextRunAt!))")
        updateDerivedState()
        writeStatus()
        completeOneShot(exitCode: 1)
    }

    private func completeOneShot(exitCode: Int32) {
        guard oneShotMode, oneShotExitCode == nil else {
            return
        }
        oneShotExitCode = exitCode
    }

    private func readActiveRunRecord() -> ActiveRunRecord? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: Config.activeRunFile)) else {
            return nil
        }
        return try? JSONDecoder().decode(ActiveRunRecord.self, from: data)
    }

    private func writeActiveRunRecord(_ record: ActiveRunRecord) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(record) else {
            return
        }
        let url = URL(fileURLWithPath: Config.activeRunFile)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: url, options: .atomic)
    }

    private func createActiveRunRecord(_ record: ActiveRunRecord) -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(record) else {
            return false
        }
        let url = URL(fileURLWithPath: Config.activeRunFile)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        do {
            try data.write(to: url, options: .withoutOverwriting)
            return true
        } catch {
            return false
        }
    }

    private func removeActiveRunRecord() {
        try? FileManager.default.removeItem(atPath: Config.activeRunFile)
    }

    private func childEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        for key in [
            "AWS_ACCESS_KEY_ID",
            "AWS_SECRET_ACCESS_KEY",
            "AWS_SESSION_TOKEN",
            "B2_APPLICATION_KEY_ID",
            "B2_APPLICATION_KEY",
        ] {
            environment.removeValue(forKey: key)
        }
        environment["PATH"] = Config.executableSearchPath.joined(separator: ":")
        try? FileManager.default.createDirectory(
            atPath: Config.kopiaHome,
            withIntermediateDirectories: true
        )
        environment["HOME"] = Config.kopiaHome
        environment["USER"] = Config.currentUser
        environment["LOGNAME"] = Config.currentUser
        environment["OP_BIOMETRIC_UNLOCK_ENABLED"] = "true"
        return environment
    }

    private func sanitizedCommandError(_ stderr: String) -> String {
        stderr
            .replacingOccurrences(of: Config.kopiaPasswordRef, with: "<1password-ref>")
            .split(separator: "\n")
            .last
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func updateDerivedState() {
        if activeMaterializationID != nil {
            state = .preparingCloudFiles
            return
        }

        if activeProcess != nil || activePID != nil {
            state = .syncing
            return
        }

        if activePIDOwner == "starting" {
            state = .startingBackup
            return
        }

        if activeOperationID != nil {
            state = activeOperation?.hasPrefix("repository") == true ? .setupIncomplete : .startingBackup
            return
        }

        if !externalKopiaPIDs.isEmpty {
            state = .externalBackupDetected
            return
        }

        refreshSetupGate()
        if !setupGate.complete {
            if setupGate.blockers.contains(.passwordMissing) {
                state = .needsSecret
            } else if setupGate.blockers.contains(.locationPermissionNeeded) {
                state = .needsPermission
            } else if setupGate.blockers.contains(.fullDiskAccessNeeded) {
                state = .needsFullDiskAccess
            } else {
                state = .setupIncomplete
            }
            return
        }

        if fullDiskAccessBlocked {
            state = .needsFullDiskAccess
            return
        }

        if cloudDownloadBlocked {
            state = .cloudDownloadBlocked
            return
        }

        if lastFailureKind == "disk_space_exhausted" && (!diskHealth.ok || !cloudCapacityEstimate.ok) {
            state = .needsDiskSpace
            return
        }

        if lastFailureKind == "secret_unavailable" {
            state = .needsSecret
            return
        }

        switch network.state {
        case "allowed":
            if lastFailureAt != nil {
                state = .failed
            } else if lastSnapshotResult == KopiaSnapshotResult.partialTolerated
                        || lastSnapshotResult == KopiaSnapshotResult.partialActionRequired {
                state = .backupPartial
            } else if lastSuccessCloudCoverage == "partial" {
                state = .cloudPartial
            } else {
                state = .ready
            }
        case "denied":
            state = .paused
        case "missing":
            state = .disabled
        default:
            state = .needsPermission
        }
    }

    private func inferredCloudCoverage(_ snapshot: CloudMaterializationSnapshot) -> String {
        let datalessPlaceholders = snapshot.total_dataless_placeholders ?? 0
        let readFailures = snapshot.total_read_failures ?? snapshot.total_failures
        let downloadFailures = snapshot.total_download_request_failures ?? 0
        let resolutionFailures = snapshot.total_placeholder_resolution_failures ?? 0
        if snapshot.completed
            && datalessPlaceholders == 0
            && readFailures == 0
            && downloadFailures == 0
            && resolutionFailures == 0 {
            return "complete"
        }
        if snapshot.completed {
            return "partial"
        }
        return "blocked"
    }

    private func loadPersistedStatus() {
        if let data = try? Data(contentsOf: URL(fileURLWithPath: Config.statusFile)),
           let status = try? JSONDecoder().decode(StatusSnapshot.self, from: data) {
            lastStartAt = parseDate(status.last_start_at)
            lastSuccessAt = parseDate(status.last_success_at)
            lastSuccessCloudCoverage = status.last_success_cloud_coverage
            lastSnapshotAt = parseDate(status.last_snapshot_at)
            lastSnapshotID = status.last_snapshot_id
            lastSnapshotRoot = status.last_snapshot_root
            lastSnapshotDuration = status.last_snapshot_duration
            lastSnapshotResult = status.last_snapshot_result
            lastSnapshotErrorCount = status.last_snapshot_error_count
            lastSnapshotToleratedCount = status.last_snapshot_tolerated_count
            lastSnapshotActionRequiredCount = status.last_snapshot_action_required_count
            lastSnapshotUnclassifiedCount = status.last_snapshot_unclassified_count
            lastSnapshotIssueCounts = status.last_snapshot_issue_counts ?? [:]
            lastSnapshotIssueSamples = status.last_snapshot_issue_samples ?? []
            lastFailureAt = parseDate(status.last_failure_at)
            lastFailure = status.last_failure
            lastFailureKind = status.last_failure_kind
            lastFailureDetail = status.last_failure_detail
            lastAbortReason = status.last_abort_reason
            nextRunAt = parseDate(status.next_run_at)
            if let statusDiskHealth = status.disk_health {
                diskHealth = statusDiskHealth
            }
            if let statusCloudCapacityEstimate = status.cloud_capacity_estimate {
                cloudCapacityEstimate = statusCloudCapacityEstimate
            }

            if let lastFailure,
               lastFailure.contains("cloud materialization read failures") {
                self.lastFailure = nil
                lastFailureAt = nil
                lastFailureKind = nil
                lastFailureDetail = nil
                lastAbortReason = nil
                nextRunAt = nil
            }
        }
        reconcileFailedSnapshotFromLogIfNeeded()
    }

    private func reconcileFailedSnapshotFromLogIfNeeded() {
        guard lastFailureKind == "file_read_failure",
              lastSnapshotID == nil,
              readActiveRunRecord() == nil,
              let parsedRun = KopiaRunLogReplayer.latestCompletedRun(),
              parsedRun.snapshot_id != nil,
              parsedRun.snapshot_result == KopiaSnapshotResult.partialTolerated
                || parsedRun.snapshot_result == KopiaSnapshotResult.partialActionRequired else {
            return
        }

        let completedAt = parseDate(parsedRun.completed_at) ?? Date()
        recordSnapshotResult(parsedRun, completedAt: completedAt)
        nextRunAt = completedAt.addingTimeInterval(TimeInterval(Config.runIntervalSeconds))
        appendLog("reconciled failed Kopia status from latest snapshot id=\(parsedRun.snapshot_id ?? "unknown") result=\(parsedRun.snapshot_result)")
        updateDerivedState()
        writeStatus()
    }

    private func seedLastSuccessFromLogIfNeededThenReconcile() {
        guard lastSuccessAt == nil else {
            reconcileLiveKopiaProcesses(
                reason: "startup",
                shouldEvaluateSchedule: true,
                markStartupReady: true
            )
            return
        }

        processQueue.async { [weak self] in
            guard let self else {
                return
            }
            let seeded = self.seedLastSuccessFromLog()
            DispatchQueue.main.async {
                if self.lastSuccessAt == nil, let seeded {
                    self.lastSuccessAt = seeded
                    self.nextRunAt = seeded.addingTimeInterval(TimeInterval(Config.runIntervalSeconds))
                    self.appendLog("seeded last_success_at from log tail")
                }
                self.reconcileLiveKopiaProcesses(
                    reason: "startup",
                    shouldEvaluateSchedule: true,
                    markStartupReady: true
                )
            }
        }
    }

    private func seedLastSuccessFromLog() -> Date? {
        let url = URL(fileURLWithPath: Config.logFile)
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        defer {
            try? handle.close()
        }

        let tailBytes: UInt64 = 1024 * 1024
        let endOffset = (try? handle.seekToEnd()) ?? 0
        let startOffset = endOffset > tailBytes ? endOffset - tailBytes : 0
        try? handle.seek(toOffset: startOffset)
        let data = handle.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else {
            return nil
        }

        var seeded: Date?
        for line in text.split(separator: "\n") {
            guard line.contains("success: kopia snapshot complete") else {
                continue
            }
            let prefix = String(line.prefix(24))
            if let date = DateFormatters.log.date(from: prefix) {
                seeded = date
            }
        }
        return seeded
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value else {
            return nil
        }
        return DateFormatters.iso.date(from: value)
    }

    private func dateString(_ date: Date?) -> String? {
        guard let date else {
            return nil
        }
        return DateFormatters.iso.string(from: date)
    }

    private func configSummary() -> ConfigSummary {
        ConfigSummaryFactory.current()
    }

    private func currentStatus() -> StatusSnapshot {
        StatusSnapshot(
            app_version: Config.appVersion,
            updated_at: DateFormatters.iso.string(from: Date()),
            state: state.rawValue,
            network_state: network.state,
            network_ssid: network.ssid,
            network_reason: network.reason,
            network_is_expensive: network.is_expensive,
            network_is_constrained: network.is_constrained,
            next_run_at: dateString(nextRunAt),
            active_operation: activeOperation,
            active_operation_started_at: dateString(activeOperationStartedAt),
            active_operation_detail: activeOperationDetail,
            operation_elapsed_seconds: activeOperationStartedAt == nil ? nil : Int(Date().timeIntervalSince(activeOperationStartedAt!)),
            active_pid: activePID,
            active_run_id: activeRunID,
            active_pid_owner: activePIDOwner,
            external_kopia_pids: externalKopiaPIDs,
            last_start_at: dateString(lastStartAt),
            last_success_at: dateString(lastSuccessAt),
            last_success_cloud_coverage: lastSuccessCloudCoverage,
            last_snapshot_at: dateString(lastSnapshotAt),
            last_snapshot_id: lastSnapshotID,
            last_snapshot_root: lastSnapshotRoot,
            last_snapshot_duration: lastSnapshotDuration,
            last_snapshot_result: lastSnapshotResult,
            last_snapshot_error_count: lastSnapshotErrorCount,
            last_snapshot_tolerated_count: lastSnapshotToleratedCount,
            last_snapshot_action_required_count: lastSnapshotActionRequiredCount,
            last_snapshot_unclassified_count: lastSnapshotUnclassifiedCount,
            last_snapshot_issue_counts: lastSnapshotIssueCounts,
            last_snapshot_issue_samples: lastSnapshotIssueSamples,
            backup_elapsed_seconds: activePID == nil ? nil : Int(livenessCheckAt.timeIntervalSince(lastStartAt ?? livenessCheckAt)),
            last_liveness_check_at: activePID == nil && activeMaterializationID == nil && activeOperationID == nil && externalKopiaPIDs.isEmpty ? nil : dateString(livenessCheckAt),
            last_kopia_output_at: dateString(lastKopiaOutputAt),
            kopia_output_idle_seconds: activeProcess == nil || lastKopiaOutputAt == nil ? nil : Int(livenessCheckAt.timeIntervalSince(lastKopiaOutputAt!)),
            kopia_activity: activePID == nil ? nil : internalKopiaActivity,
            kopia_suppressed_dataless_read_errors: activeProcess == nil ? nil : kopiaSuppressedDatalessReadErrors,
            kopia_other_output_read_errors: activeProcess == nil ? nil : kopiaOtherOutputReadErrors,
            disk_health: diskHealth,
            cloud_capacity_estimate: cloudCapacityEstimate,
            last_failure_at: dateString(lastFailureAt),
            last_failure_kind: lastFailureKind,
            last_failure_detail: lastFailureDetail,
            last_failure: lastFailure,
            last_abort_reason: lastAbortReason,
            protected_data_probe_results: protectedDataProbeResults,
            cloud_materialization: cloudMaterialization,
            kopia_ran_after_materialization: kopiaRanAfterMaterialization,
            setup_gate: setupGate,
            repository_status: repositoryStatus,
            config_summary: configSummary()
        )
    }

    private func writeStatus() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(currentStatus()) else {
            return
        }

        let url = URL(fileURLWithPath: Config.statusFile)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: url, options: .atomic)
    }

    private func appendLog(_ message: String) {
        let line = "\(DateFormatters.log.string(from: Date())) \(message)\n"
        guard let data = line.data(using: .utf8) else {
            return
        }
        appendDataToLog(data)
    }

    private func appendDataToLog(_ data: Data) {
        appendDataToFile(data, path: Config.logFile)
    }

    private func appendDataToFile(_ data: Data, path: String) {
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: url) else {
            return
        }
        defer {
            try? handle.close()
        }
        _ = try? handle.seekToEnd()
        _ = try? handle.write(contentsOf: data)
    }

    private func handleKopiaOutputData(_ data: Data) {
        appendDataToFile(data, path: Config.rawKopiaLogFile)
        guard let text = String(data: data, encoding: .utf8) else {
            return
        }
        DispatchQueue.main.async {
            self.processKopiaOutputText(text)
        }
    }

    private func processKopiaOutputText(_ text: String) {
        lastKopiaOutputAt = Date()
        kopiaOutputBuffer += text.replacingOccurrences(of: "\r", with: "\n")
        while let newlineIndex = kopiaOutputBuffer.firstIndex(of: "\n") {
            let line = String(kopiaOutputBuffer[..<newlineIndex])
            kopiaOutputBuffer.removeSubrange(...newlineIndex)
            processKopiaOutputLine(line)
        }
    }

    private func flushKopiaOutputSummary() {
        if !kopiaOutputBuffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            processKopiaOutputLine(kopiaOutputBuffer)
            kopiaOutputBuffer = ""
        }
        if kopiaSuppressedDatalessReadErrors > 0 {
            appendLog("kopia dataless placeholder read errors suppressed total=\(kopiaSuppressedDatalessReadErrors) raw_log=\"\(Config.rawKopiaLogFile)\"")
        }
        if kopiaOtherOutputReadErrors > 0 {
            appendLog("kopia non-placeholder processing errors total=\(kopiaOtherOutputReadErrors)")
        }
    }

    private func processKopiaOutputLine(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        if isKnownDatalessKopiaReadError(trimmed) {
            kopiaSuppressedDatalessReadErrors += 1
            kopiaOutputObservation.observe(line: trimmed)
            if kopiaSuppressedDatalessReadErrors == 1 || kopiaSuppressedDatalessReadErrors % 500 == 0 {
                appendLog("kopia dataless placeholder read errors suppressed count=\(kopiaSuppressedDatalessReadErrors) raw_log=\"\(Config.rawKopiaLogFile)\"")
            }
            return
        }

        kopiaOutputObservation.observe(line: trimmed)
        if trimmed.contains("Error when processing") {
            kopiaOtherOutputReadErrors += 1
        }
        if let classification = KopiaFailureClassifier.classify(line: trimmed),
           observedKopiaFailure == nil || classification.priority > observedKopiaFailure!.priority {
            observedKopiaFailure = classification
        }
        appendLog(trimmed)
    }

    private func isKnownDatalessKopiaReadError(_ line: String) -> Bool {
        KopiaFileIssueClassifier.classify(line: line)?.category == KopiaIssueCategory.cloudPlaceholder
    }
}

final class CLIAppDelegate: NSObject, NSApplicationDelegate, CLLocationManagerDelegate {
    private let requestPermission: Bool
    private let printStatusJSON: Bool
    private let manager = CLLocationManager()
    private var window: NSWindow?
    private var statusLabel: NSTextField?
    private var finished = false

    init(requestPermission: Bool, printStatusJSON: Bool) {
        self.requestPermission = requestPermission
        self.printStatusJSON = printStatusJSON
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        showWindow(visible: requestPermission)
        NSApp.activate(ignoringOtherApps: requestPermission)

        if printStatusJSON {
            printStatus()
            exit(0)
        }

        if requestPermission {
            guard CLLocationManager.locationServicesEnabled() else {
                printNetworkJSON()
                exit(3)
            }
            manager.requestAlwaysAuthorization()
            manager.startUpdatingLocation()
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
                self?.finish()
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.printNetworkJSON()
                exit(0)
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        updateStatusLabel()
        if manager.authorizationStatus != .notDetermined {
            finish()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        finish()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if manager.authorizationStatus != .notDetermined {
            finish()
        }
    }

    private func showWindow(visible: Bool) {
        let contentRect = visible
            ? NSRect(x: 0, y: 0, width: 480, height: 136)
            : NSRect(x: 0, y: 0, width: 1, height: 1)
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = Config.appName
        window.center()
        window.alphaValue = visible ? 1.0 : 0.01

        if visible {
            let label = NSTextField(labelWithString: "Allow Location access so Kopia can read the current Wi-Fi network name and skip denied networks.")
            label.frame = NSRect(x: 24, y: 58, width: 432, height: 48)
            label.lineBreakMode = .byWordWrapping
            label.maximumNumberOfLines = 2
            label.alignment = .center
            window.contentView?.addSubview(label)

            let statusLabel = NSTextField(labelWithString: "Permission status: \(LocationStatus.name(manager.authorizationStatus))")
            statusLabel.frame = NSRect(x: 24, y: 28, width: 432, height: 20)
            statusLabel.alignment = .center
            window.contentView?.addSubview(statusLabel)
            self.statusLabel = statusLabel
        }

        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    private func updateStatusLabel() {
        statusLabel?.stringValue = "Permission status: \(LocationStatus.name(manager.authorizationStatus))"
    }

    private func finish() {
        guard !finished else {
            return
        }
        finished = true
        manager.stopUpdatingLocation()
        printNetworkJSON()
        exit(LocationStatus.isAuthorized(manager.authorizationStatus) ? 0 : 3)
    }

    private func printNetworkJSON() {
        let network = NetworkPolicy.current(
            isExpensive: false,
            isConstrained: false,
            authorization: manager.authorizationStatus
        )
        printEncoded(network)
    }

    private func printStatus() {
        if let data = try? Data(contentsOf: URL(fileURLWithPath: Config.statusFile)),
           let string = String(data: data, encoding: .utf8) {
            print(string)
            return
        }

        let network = NetworkPolicy.current(
            isExpensive: false,
            isConstrained: false,
            authorization: manager.authorizationStatus
        )
        let state: BackupState
        switch network.state {
        case "allowed":
            state = .ready
        case "denied":
            state = .paused
        case "missing":
            state = .disabled
        default:
            state = .needsPermission
        }
        let status = StatusSnapshot(
            app_version: Config.appVersion,
            updated_at: DateFormatters.iso.string(from: Date()),
            state: state.rawValue,
            network_state: network.state,
            network_ssid: network.ssid,
            network_reason: network.reason,
            network_is_expensive: network.is_expensive,
            network_is_constrained: network.is_constrained,
            next_run_at: nil,
            active_operation: nil,
            active_operation_started_at: nil,
            active_operation_detail: nil,
            operation_elapsed_seconds: nil,
            active_pid: nil,
            active_run_id: nil,
            active_pid_owner: nil,
            external_kopia_pids: [],
            last_start_at: nil,
            last_success_at: nil,
            last_success_cloud_coverage: nil,
            last_snapshot_at: nil,
            last_snapshot_id: nil,
            last_snapshot_root: nil,
            last_snapshot_duration: nil,
            last_snapshot_result: nil,
            last_snapshot_error_count: nil,
            last_snapshot_tolerated_count: nil,
            last_snapshot_action_required_count: nil,
            last_snapshot_unclassified_count: nil,
            last_snapshot_issue_counts: nil,
            last_snapshot_issue_samples: nil,
            backup_elapsed_seconds: nil,
            last_liveness_check_at: nil,
            last_kopia_output_at: nil,
            kopia_output_idle_seconds: nil,
            kopia_activity: nil,
            kopia_suppressed_dataless_read_errors: nil,
            kopia_other_output_read_errors: nil,
            disk_health: DiskHealthSnapshot.unknown(),
            cloud_capacity_estimate: CloudCapacityEstimate.unknown(),
            last_failure_at: nil,
            last_failure_kind: nil,
            last_failure_detail: nil,
            last_failure: nil,
            last_abort_reason: nil,
            protected_data_probe_results: [],
            cloud_materialization: CloudMaterializationSnapshot.empty(),
            kopia_ran_after_materialization: false,
            config_summary: ConfigSummaryFactory.current()
        )
        printEncoded(status)
    }

    private func printEncoded<T: Encodable>(_ value: T) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8) else {
            fputs("unable to encode JSON\n", stderr)
            exit(1)
        }
        print(string)
    }
}

enum LaunchAgentManager {
    static let plistName = "com.freesidenyc.copya.agent.plist"

    static var service: SMAppService {
        SMAppService.agent(plistName: plistName)
    }

    static var statusText: String {
        switch service.status {
        case .notRegistered:
            return "not registered"
        case .enabled:
            return "enabled"
        case .requiresApproval:
            return "requires approval"
        case .notFound:
            return "not found"
        @unknown default:
            return "unknown"
        }
    }

    static func registerAndExit() -> Never {
        do {
            try service.register()
            print("registered \(Config.monitorLaunchdLabel), status=\(statusText)")
            exit(0)
        } catch {
            fputs("unable to register \(Config.monitorLaunchdLabel): \(error)\n", stderr)
            exit(1)
        }
    }

    static func unregisterAndExit() -> Never {
        do {
            try service.unregister()
            print("unregistered \(Config.monitorLaunchdLabel), status=\(statusText)")
            exit(0)
        } catch {
            fputs("unable to unregister \(Config.monitorLaunchdLabel): \(error)\n", stderr)
            exit(1)
        }
    }

    static func printStatusAndExit() -> Never {
        print(statusText)
        exit(0)
    }

    static func openSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

enum CopyaAgentProcess {
    static func isRunning() -> Bool {
        do {
            let result = try CommandRunner.run(
                "/bin/launchctl",
                arguments: [
                    "print",
                    "gui/\(getuid())/\(Config.monitorLaunchdLabel)",
                ],
                timeoutSeconds: 5
            )
            if result.status == 0,
               result.stdout.contains("state = running") || result.stdout.contains("\n\tpid =") {
                return true
            }
        } catch {
            // Fall through to process scanning. Launchctl can be weird before login services settle.
        }

        do {
            let result = try CommandRunner.run(
                "/usr/bin/pgrep",
                arguments: ["-fl", "Contents/MacOS/COPYA"],
                timeoutSeconds: 5
            )
            return result.status == 0
                && result.stdout
                .split(separator: "\n")
                .contains { line in
                    line.contains("Contents/MacOS/COPYA")
                        && !line.contains("pgrep")
                        && !line.contains(String(ProcessInfo.processInfo.processIdentifier))
                }
        } catch {
            return false
        }
    }
}

enum KeychainPasswordStore {
    enum Error: Swift.Error, CustomStringConvertible {
        case notFound
        case invalidData
        case unhandledStatus(OSStatus)

        var description: String {
            switch self {
            case .notFound:
                return "Kopia password is not stored in Keychain"
            case .invalidData:
                return "Kopia password in Keychain was not valid UTF-8"
            case .unhandledStatus(let status):
                return "Keychain returned status \(status)"
            }
        }
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Config.keychainService,
            kSecAttrAccount as String: Config.keychainAccount,
        ]
    }

    static func readPassword() throws -> String {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            throw Error.notFound
        }
        guard status == errSecSuccess else {
            throw Error.unhandledStatus(status)
        }
        guard let data = item as? Data,
              let password = String(data: data, encoding: .utf8) else {
            throw Error.invalidData
        }
        return password.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func hasPassword() -> Bool {
        var query = baseQuery
        query[kSecReturnData as String] = false
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    static func storePassword(_ password: String) throws {
        let data = Data(password.utf8)
        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw Error.unhandledStatus(updateStatus)
        }

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw Error.unhandledStatus(addStatus)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        BackupMonitor.shared.stopBackup(reason: "monitor terminating")
    }
}

enum AppDelegateStore {
    static let shared = AppDelegate()
}

func printEncodedJSON<T: Encodable>(_ value: T) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    guard let data = try? encoder.encode(value),
          let string = String(data: data, encoding: .utf8) else {
        fputs("unable to encode JSON\n", stderr)
        exit(1)
    }
    print(string)
}

func printStatusJSONAndExit() -> Never {
    if let data = try? Data(contentsOf: URL(fileURLWithPath: Config.statusFile)),
       let string = String(data: data, encoding: .utf8) {
        print(string)
        exit(0)
    }

    let network = NetworkPolicy.current(isExpensive: false, isConstrained: false)
    let state: BackupState
    switch network.state {
    case "allowed":
        state = .ready
    case "denied":
        state = .paused
    case "missing":
        state = .disabled
    default:
        state = .needsPermission
    }
    let status = StatusSnapshot(
        app_version: Config.appVersion,
        updated_at: DateFormatters.iso.string(from: Date()),
        state: state.rawValue,
        network_state: network.state,
        network_ssid: network.ssid,
        network_reason: network.reason,
        network_is_expensive: network.is_expensive,
        network_is_constrained: network.is_constrained,
        next_run_at: nil,
        active_operation: nil,
        active_operation_started_at: nil,
        active_operation_detail: nil,
        operation_elapsed_seconds: nil,
        active_pid: nil,
        active_run_id: nil,
        active_pid_owner: nil,
        external_kopia_pids: [],
            last_start_at: nil,
            last_success_at: nil,
            last_success_cloud_coverage: nil,
            last_snapshot_at: nil,
            last_snapshot_id: nil,
            last_snapshot_root: nil,
            last_snapshot_duration: nil,
            last_snapshot_result: nil,
            last_snapshot_error_count: nil,
            last_snapshot_tolerated_count: nil,
            last_snapshot_action_required_count: nil,
            last_snapshot_unclassified_count: nil,
            last_snapshot_issue_counts: nil,
            last_snapshot_issue_samples: nil,
            backup_elapsed_seconds: nil,
        last_liveness_check_at: nil,
        last_kopia_output_at: nil,
        kopia_output_idle_seconds: nil,
        kopia_activity: nil,
        kopia_suppressed_dataless_read_errors: nil,
        kopia_other_output_read_errors: nil,
            disk_health: DiskHealthSnapshot.unknown(),
            cloud_capacity_estimate: CloudCapacityEstimate.unknown(),
            last_failure_at: nil,
        last_failure_kind: nil,
        last_failure_detail: nil,
        last_failure: nil,
        last_abort_reason: nil,
        protected_data_probe_results: [],
        cloud_materialization: CloudMaterializationSnapshot.empty(),
        kopia_ran_after_materialization: false,
        setup_gate: SetupGateResult.evaluate(
            SetupGateInput(
                configExists: Config.configExists,
                sourceExists: FileManager.default.fileExists(atPath: Config.backupSource),
                sourceReadable: FileManager.default.isReadableFile(atPath: Config.backupSource),
                passwordAvailable: KeychainPasswordStore.hasPassword() || Config.passwordSource == "environment",
                repositoryConnected: false,
                networkPolicyNeedsPermission: Config.networkPolicyEnabled && !network.allowed,
                fullDiskAccessAcceptable: Config.limitedBackupAcknowledged,
                activeWorkRunning: false
            )
        ),
        repository_status: RepositoryStatusSnapshot.unknown(),
        config_summary: ConfigSummaryFactory.current()
    )
    printEncodedJSON(status)
    exit(0)
}

func printLatestKopiaClassificationAndExit() -> Never {
    guard let latest = KopiaRunLogReplayer.latestCompletedRun() else {
        fputs("unable to find a complete COPYA-owned Kopia run in \(Config.rawKopiaLogFile)\n", stderr)
        exit(1)
    }
    printEncodedJSON(latest)
    exit(0)
}

func printKopiaClassificationAndExit(logFile: String) -> Never {
    guard let latest = KopiaRunLogReplayer.latestCompletedRun(logFile: logFile) else {
        fputs("unable to find a complete COPYA-owned Kopia run in \(logFile)\n", stderr)
        exit(1)
    }
    printEncodedJSON(latest)
    exit(0)
}

func printRuntimeConfigAndExit() -> Never {
    printEncodedJSON(Config.runtime)
    exit(0)
}

func writeDefaultRuntimeConfigAndExit() -> Never {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    do {
        let url = URL(fileURLWithPath: Config.configFile)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(RuntimeConfig.defaults(home: Config.home))
        try data.write(to: url, options: .withoutOverwriting)
        print(Config.configFile)
        exit(0)
    } catch CocoaError.fileWriteFileExists {
        fputs("config already exists at \(Config.configFile)\n", stderr)
        exit(73)
    } catch {
        fputs("unable to write default config at \(Config.configFile): \(error)\n", stderr)
        exit(1)
    }
}

func storeKeychainPasswordAndExit() -> Never {
    let data = FileHandle.standardInput.readDataToEndOfFile()
    guard let password = String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines),
          !password.isEmpty else {
        fputs("read the Kopia password from stdin, but it was empty\n", stderr)
        exit(64)
    }

    do {
        try KeychainPasswordStore.storePassword(password)
        print("stored Kopia password in Keychain")
        exit(0)
    } catch {
        fputs("unable to store Kopia password in Keychain: \(error)\n", stderr)
        exit(1)
    }
}

func runBackupOnceAndExit(arguments: ArraySlice<String>) -> Never {
    var timeoutSeconds = 3600
    var iterator = arguments.makeIterator()
    while let argument = iterator.next() {
        switch argument {
        case "--timeout":
            guard let value = iterator.next(), let parsed = Int(value), parsed > 0 else {
                fputs("usage: \(Config.appName) --backup-once [--timeout <seconds>]\n", stderr)
                exit(64)
            }
            timeoutSeconds = parsed
        default:
            fputs("usage: \(Config.appName) --backup-once [--timeout <seconds>]\n", stderr)
            exit(64)
        }
    }

    BackupMonitor.shared.runOneShotBackupAndExit(timeoutSeconds: timeoutSeconds)
}

func runAgentAndExit() -> Never {
    let app = NSApplication.shared
    app.delegate = AppDelegateStore.shared
    app.setActivationPolicy(.accessory)
    BackupMonitor.shared.start()
    app.run()
    exit(1)
}

func runCLI(requestPermission: Bool = false, printStatusJSON: Bool = false) -> Never {
    let app = NSApplication.shared
    let delegate = CLIAppDelegate(requestPermission: requestPermission, printStatusJSON: printStatusJSON)
    app.delegate = delegate
    app.run()
    exit(1)
}

func runCLIIfNeeded() {
    if ProcessInfo.processInfo.environment["COPYA_AGENT"] == "1" {
        runAgentAndExit()
    }

    let arguments = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("-psn_") }
    guard let command = arguments.first else {
        return
    }

    switch command {
    case "--network-json":
        runCLI()
    case "--status-json":
        printStatusJSONAndExit()
    case "--bundle-path":
        print(Bundle.main.bundlePath)
        exit(0)
    case "--config-json":
        printRuntimeConfigAndExit()
    case "--write-default-config":
        writeDefaultRuntimeConfigAndExit()
    case "--register-login-agent":
        LaunchAgentManager.registerAndExit()
    case "--unregister-login-agent":
        LaunchAgentManager.unregisterAndExit()
    case "--login-agent-status":
        LaunchAgentManager.printStatusAndExit()
    case "--store-password-in-keychain":
        storeKeychainPasswordAndExit()
    case "--backup-once":
        runBackupOnceAndExit(arguments: arguments.dropFirst())
    case "--agent":
        runAgentAndExit()
    case "--classify-last-kopia-errors":
        printLatestKopiaClassificationAndExit()
    case "--classify-kopia-log":
        guard arguments.count == 2 else {
            fputs("usage: \(Config.appName) --classify-kopia-log <path>\n", stderr)
            exit(64)
        }
        printKopiaClassificationAndExit(logFile: String(arguments.dropFirst().first ?? ""))
    case "--request-location":
        runCLI(requestPermission: true)
    default:
        fputs("usage: \(Config.appName) [--network-json] [--status-json] [--bundle-path] [--config-json] [--write-default-config] [--register-login-agent] [--unregister-login-agent] [--login-agent-status] [--store-password-in-keychain] [--backup-once [--timeout <seconds>]] [--agent] [--classify-last-kopia-errors] [--classify-kopia-log <path>] [--request-location]\n", stderr)
        exit(64)
    }
}

@main
struct KopiaBackupMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var monitor = BackupMonitor.shared

    init() {
        runCLIIfNeeded()
        if CopyaAgentProcess.isRunning() {
            BackupMonitor.shared.startViewer()
        } else {
            BackupMonitor.shared.start()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if !BackupMonitor.shared.setupGate.complete {
                    SetupPreferencesWindowController.shared.show()
                }
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            Text(Config.appName)
                .font(.headline)
            Text(monitor.menuTitle)
            Divider()
            Text("SSID: \(monitor.ssidText)")
            Text("Network: \(monitor.network.reason)")
            Text("Launch agent: \(LaunchAgentManager.statusText)")
            Text("Setup: \(monitor.setupGate.summary)")
            Text("Repository: \(monitor.repositoryStatus.state.rawValue)")
            if monitor.network.is_expensive || monitor.network.is_constrained {
                Text("macOS marks this network as \(monitor.network.is_constrained ? "constrained" : "expensive")")
            }
            Divider()
            Text("Last success: \(monitor.lastSuccessText)")
            if let lastSnapshot = monitor.lastSnapshotText {
                Text("Last snapshot: \(lastSnapshot)")
            }
            Text("Next run: \(monitor.nextRunText)")
            Text("Active PID: \(monitor.activePIDText)")
            if let operation = monitor.activeOperationText {
                Text("Operation: \(operation)")
            }
            if monitor.activePID != nil {
                Text("Backup: \(monitor.backupLivenessText)")
            }
            if let externalPIDs = monitor.externalKopiaPIDsText {
                Text("External Kopia PIDs: \(externalPIDs)")
            }
            if let kopiaIssue = monitor.kopiaIssueText {
                Text(kopiaIssue)
            }
            if let diskHealth = monitor.diskHealthText {
                Text("Disk: \(diskHealth)")
            }
            if let cloudEstimate = monitor.cloudCapacityEstimateText {
                Text("Cloud estimate: \(cloudEstimate)")
            }
            Text("Cloud prep: \(monitor.cloudMaterializationText)")
            if let failure = monitor.lastFailure {
                Divider()
                Text("Last failure: \(failure)")
            }
            if let snapshotIssue = monitor.lastSnapshotIssueText {
                Divider()
                Text("Snapshot issue: \(snapshotIssue)")
            }
            if let abort = monitor.lastAbortReason {
                Text("Last abort: \(abort)")
            }
            Divider()
            Button("Setup & Preferences...") {
                SetupPreferencesWindowController.shared.show()
            }
            Divider()
            Button("Start Backup Now") {
                monitor.startBackup(trigger: "manual")
            }
            .disabled(!monitor.canStartManual)
            Button("Stop Backup") {
                monitor.stopBackup(reason: "manual stop")
            }
            .disabled(!monitor.canStopManual)
            Button("Check Network") {
                monitor.checkNetworkNow()
            }
            Button("Grant Wi-Fi Permission") {
                monitor.requestLocationPermission()
            }
            Button("Open Full Disk Access") {
                monitor.openFullDiskAccessSettings()
            }
            Button("Enable at Login") {
                do {
                    try LaunchAgentManager.service.register()
                    monitor.checkNetworkNow()
                } catch {
                    monitor.recordManualActionFailure("Unable to enable login agent: \(error.localizedDescription)")
                }
            }
            .disabled(!monitor.canManageLoginAgent)
            Button("Disable Login Agent") {
                do {
                    try LaunchAgentManager.service.unregister()
                    monitor.checkNetworkNow()
                } catch {
                    monitor.recordManualActionFailure("Unable to disable login agent: \(error.localizedDescription)")
                }
            }
            .disabled(!monitor.canManageLoginAgent)
            Button("Open Login Items") {
                LaunchAgentManager.openSettings()
            }
            Divider()
            Button("Open Log") {
                monitor.openLog()
            }
            Button("Copy Debug Status") {
                monitor.copyDebugStatus()
            }
            Divider()
            Button("Quit Monitor") {
                monitor.quit()
            }
        } label: {
            Label(Config.appName, systemImage: monitor.menuSystemImage)
        }
    }
}
