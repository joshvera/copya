import Foundation

public enum KopiaRepositoryMode: String, Codable, CaseIterable, Identifiable {
    case create
    case connect

    public var id: String { rawValue }
}

public struct KopiaProcessSpec: Equatable {
    public var arguments: [String]
    public var environment: [String: String]

    public init(arguments: [String], environment: [String: String]) {
        self.arguments = arguments
        self.environment = environment
    }

    public var redactedDisplay: String {
        arguments.joined(separator: " ")
    }
}

public struct BackblazeB2S3RepositoryRequest: Equatable {
    public var mode: KopiaRepositoryMode
    public var bucket: String
    public var endpoint: String
    public var region: String
    public var prefix: String
    public var accessKeyID: String
    public var applicationKey: String
    public var configFile: String?

    public init(
        mode: KopiaRepositoryMode,
        bucket: String,
        endpoint: String,
        region: String,
        prefix: String = "",
        accessKeyID: String,
        applicationKey: String,
        configFile: String? = nil
    ) {
        self.mode = mode
        self.bucket = bucket
        self.endpoint = endpoint
        self.region = region
        self.prefix = prefix
        self.accessKeyID = accessKeyID
        self.applicationKey = applicationKey
        self.configFile = configFile
    }

    public var resolvedEndpoint: String {
        let trimmedEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedEndpoint.isEmpty {
            return trimmedEndpoint
        }
        let trimmedRegion = region.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRegion.isEmpty else {
            return ""
        }
        return "s3.\(trimmedRegion).backblazeb2.com"
    }
}

public struct FilesystemRepositoryRequest: Equatable {
    public var mode: KopiaRepositoryMode
    public var path: String
    public var configFile: String?

    public init(mode: KopiaRepositoryMode, path: String, configFile: String? = nil) {
        self.mode = mode
        self.path = path
        self.configFile = configFile
    }
}

public enum KopiaRepositoryCommand {
    public static func statusArguments(configFile: String?) -> [String] {
        var arguments = globalArguments(configFile: configFile)
        arguments += ["repository", "status", "--json"]
        return arguments
    }

    public static func policyShowArguments(configFile: String?, target: String) -> [String] {
        var arguments = globalArguments(configFile: configFile)
        arguments += ["policy", "show", "--json", target]
        return arguments
    }

    public static func policySetArguments(
        configFile: String?,
        target: String,
        addIgnorePatterns: [String],
        ignoreCacheDirs: Bool?
    ) -> [String] {
        var arguments = globalArguments(configFile: configFile)
        arguments += ["policy", "set", target]
        for pattern in addIgnorePatterns {
            arguments += ["--add-ignore", pattern]
        }
        if let ignoreCacheDirs {
            arguments += ["--ignore-cache-dirs", ignoreCacheDirs ? "true" : "false"]
        }
        return arguments
    }

    public static func cacheInfoPathArguments(configFile: String?) -> [String] {
        var arguments = globalArguments(configFile: configFile)
        arguments += ["cache", "info", "--path"]
        return arguments
    }

    public static func backblazeB2S3Spec(
        request: BackblazeB2S3RepositoryRequest,
        baseEnvironment: [String: String],
        kopiaPassword: String
    ) -> KopiaProcessSpec {
        var arguments = globalArguments(configFile: request.configFile)
        arguments += ["repository", request.mode.rawValue, "s3"]
        arguments += ["--bucket", request.bucket]
        arguments += ["--endpoint", request.resolvedEndpoint]
        if !request.region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            arguments += ["--region", request.region]
        }
        if !request.prefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            arguments += ["--prefix", request.prefix]
        }

        var environment = baseEnvironment
        environment["KOPIA_PASSWORD"] = kopiaPassword
        environment["AWS_ACCESS_KEY_ID"] = request.accessKeyID
        environment["AWS_SECRET_ACCESS_KEY"] = request.applicationKey
        return KopiaProcessSpec(arguments: arguments, environment: environment)
    }

    public static func filesystemSpec(
        request: FilesystemRepositoryRequest,
        baseEnvironment: [String: String],
        kopiaPassword: String
    ) -> KopiaProcessSpec {
        var arguments = globalArguments(configFile: request.configFile)
        arguments += ["repository", request.mode.rawValue, "filesystem", "--path", request.path]
        var environment = baseEnvironment
        environment["KOPIA_PASSWORD"] = kopiaPassword
        return KopiaProcessSpec(arguments: arguments, environment: environment)
    }

    private static func globalArguments(configFile: String?) -> [String] {
        guard let configFile, !configFile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        return ["--config-file", configFile]
    }
}

public struct KopiaPolicySnapshot: Decodable, Equatable {
    public var files: KopiaPolicyFiles

    public init(files: KopiaPolicyFiles) {
        self.files = files
    }
}

public struct KopiaPolicyFiles: Decodable, Equatable {
    public var ignore: [String]
    public var ignoreCacheDirs: Bool?

    public init(ignore: [String], ignoreCacheDirs: Bool?) {
        self.ignore = ignore
        self.ignoreCacheDirs = ignoreCacheDirs
    }

    private enum CodingKeys: String, CodingKey {
        case ignore
        case ignoreCacheDirs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ignore = try container.decodeIfPresent([String].self, forKey: .ignore) ?? []
        ignoreCacheDirs = try container.decodeIfPresent(Bool.self, forKey: .ignoreCacheDirs)
    }
}

public struct KopiaPolicyReconciliation: Equatable {
    public var missingIgnorePatterns: [String]
    public var shouldEnableIgnoreCacheDirs: Bool

    public init(missingIgnorePatterns: [String], shouldEnableIgnoreCacheDirs: Bool) {
        self.missingIgnorePatterns = missingIgnorePatterns
        self.shouldEnableIgnoreCacheDirs = shouldEnableIgnoreCacheDirs
    }

    public var requiresUpdate: Bool {
        !missingIgnorePatterns.isEmpty || shouldEnableIgnoreCacheDirs
    }
}

public enum KopiaPolicyReconciler {
    public static func reconcile(
        files: KopiaPolicyFiles,
        managedIgnorePatterns: [String],
        userIgnorePatterns: [String]
    ) -> KopiaPolicyReconciliation {
        let desiredPatterns = orderedUnique(managedIgnorePatterns + userIgnorePatterns)
        let existingPatterns = Set(files.ignore)
        let missingPatterns = desiredPatterns.filter { !existingPatterns.contains($0) }
        return KopiaPolicyReconciliation(
            missingIgnorePatterns: missingPatterns,
            shouldEnableIgnoreCacheDirs: files.ignoreCacheDirs != true
        )
    }

    public static func orderedUnique(_ patterns: [String]) -> [String] {
        var seen = Set<String>()
        var unique: [String] = []
        for pattern in patterns {
            let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else {
                continue
            }
            seen.insert(trimmed)
            unique.append(trimmed)
        }
        return unique
    }
}

public enum RepositoryConnectionState: String, Codable, Equatable {
    case unknown
    case connected
    case disconnected
    case missingPassword = "missing_password"
    case failed
}

public struct RepositoryStatusSnapshot: Codable, Equatable {
    public var checkedAt: String?
    public var state: RepositoryConnectionState
    public var detail: String?

    public init(checkedAt: String?, state: RepositoryConnectionState, detail: String?) {
        self.checkedAt = checkedAt
        self.state = state
        self.detail = detail
    }

    public static func unknown() -> RepositoryStatusSnapshot {
        RepositoryStatusSnapshot(checkedAt: nil, state: .unknown, detail: nil)
    }

    public var connected: Bool {
        state == .connected
    }
}

public enum RepositoryStatusClassifier {
    public static func classify(status: Int32, stdout: String, stderr: String, timedOut: Bool) -> RepositoryConnectionState {
        if timedOut {
            return .failed
        }
        if status == 0 {
            return .connected
        }
        let combined = (stdout + "\n" + stderr).lowercased()
        if combined.contains("password") || combined.contains("kopia_password") {
            return .missingPassword
        }
        if combined.contains("repository") || combined.contains("unable") || combined.contains("not") {
            return .disconnected
        }
        return .failed
    }
}
