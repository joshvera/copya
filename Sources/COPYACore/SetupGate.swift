import Foundation

public enum SetupGateBlocker: String, Codable, CaseIterable, Equatable {
    case configMissing = "config_missing"
    case sourceMissing = "source_missing"
    case sourceUnreadable = "source_unreadable"
    case passwordMissing = "password_missing"
    case repositoryNotConnected = "repository_not_connected"
    case locationPermissionNeeded = "location_permission_needed"
    case fullDiskAccessNeeded = "full_disk_access_needed"
    case activeWorkRunning = "active_work_running"

    public var userText: String {
        switch self {
        case .configMissing:
            return "COPYA preferences have not been saved"
        case .sourceMissing:
            return "Backup source does not exist"
        case .sourceUnreadable:
            return "Backup source is not readable"
        case .passwordMissing:
            return "Kopia password is not stored in Keychain"
        case .repositoryNotConnected:
            return "Kopia repository is not connected"
        case .locationPermissionNeeded:
            return "Wi-Fi permission is required for network policy"
        case .fullDiskAccessNeeded:
            return "Full Disk Access is needed, or limited backup must be acknowledged"
        case .activeWorkRunning:
            return "COPYA is already running backup or repository work"
        }
    }
}

public struct SetupGateInput: Equatable {
    public var configExists: Bool
    public var sourceExists: Bool
    public var sourceReadable: Bool
    public var passwordAvailable: Bool
    public var repositoryConnected: Bool
    public var networkPolicyNeedsPermission: Bool
    public var fullDiskAccessAcceptable: Bool
    public var activeWorkRunning: Bool

    public init(
        configExists: Bool,
        sourceExists: Bool,
        sourceReadable: Bool,
        passwordAvailable: Bool,
        repositoryConnected: Bool,
        networkPolicyNeedsPermission: Bool,
        fullDiskAccessAcceptable: Bool,
        activeWorkRunning: Bool
    ) {
        self.configExists = configExists
        self.sourceExists = sourceExists
        self.sourceReadable = sourceReadable
        self.passwordAvailable = passwordAvailable
        self.repositoryConnected = repositoryConnected
        self.networkPolicyNeedsPermission = networkPolicyNeedsPermission
        self.fullDiskAccessAcceptable = fullDiskAccessAcceptable
        self.activeWorkRunning = activeWorkRunning
    }
}

public struct SetupGateResult: Codable, Equatable {
    public var complete: Bool
    public var blockers: [SetupGateBlocker]

    public init(complete: Bool, blockers: [SetupGateBlocker]) {
        self.complete = complete
        self.blockers = blockers
    }

    public static func evaluate(_ input: SetupGateInput) -> SetupGateResult {
        var blockers: [SetupGateBlocker] = []
        if !input.configExists {
            blockers.append(.configMissing)
        }
        if !input.sourceExists {
            blockers.append(.sourceMissing)
        } else if !input.sourceReadable {
            blockers.append(.sourceUnreadable)
        }
        if !input.passwordAvailable {
            blockers.append(.passwordMissing)
        }
        if !input.repositoryConnected {
            blockers.append(.repositoryNotConnected)
        }
        if input.networkPolicyNeedsPermission {
            blockers.append(.locationPermissionNeeded)
        }
        if !input.fullDiskAccessAcceptable {
            blockers.append(.fullDiskAccessNeeded)
        }
        if input.activeWorkRunning {
            blockers.append(.activeWorkRunning)
        }
        return SetupGateResult(complete: blockers.isEmpty, blockers: blockers)
    }

    public var summary: String {
        if complete {
            return "Setup complete"
        }
        return blockers.first?.userText ?? "Setup incomplete"
    }
}
