import Foundation

public enum KopiaWorkKind: String, Codable, Equatable {
    case backup
    case cloudMaterialization = "cloud_materialization"
    case repositoryStatus = "repository_status"
    case repositorySetup = "repository_setup"
}

public struct KopiaWorkToken: Equatable {
    public let id: UUID
    public let kind: KopiaWorkKind
}

public final class KopiaWorkCoordinator {
    private let lock = NSLock()
    private var active: KopiaWorkToken?

    public init() {}

    public func begin(_ kind: KopiaWorkKind) -> KopiaWorkToken? {
        lock.lock()
        defer { lock.unlock() }
        guard active == nil else {
            return nil
        }
        let token = KopiaWorkToken(id: UUID(), kind: kind)
        active = token
        return token
    }

    public func finish(_ token: KopiaWorkToken) {
        lock.lock()
        defer { lock.unlock() }
        if active == token {
            active = nil
        }
    }

    public var activeKind: KopiaWorkKind? {
        lock.lock()
        defer { lock.unlock() }
        return active?.kind
    }
}
