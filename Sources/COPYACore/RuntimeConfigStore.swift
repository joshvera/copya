import Foundation

public enum RuntimeConfigStoreError: Error, Equatable, CustomStringConvertible {
    case readFailed(String)
    case parseFailed(String)
    case writeFailed(String)

    public var description: String {
        switch self {
        case .readFailed(let message):
            return "read failed: \(message)"
        case .parseFailed(let message):
            return "parse failed: \(message)"
        case .writeFailed(let message):
            return "write failed: \(message)"
        }
    }
}

public final class RuntimeConfigStore<Value: Codable> {
    private let path: String
    private let defaults: Value
    private let requireValid: Bool
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let fileManager: FileManager

    public init(
        path: String,
        defaults: Value,
        requireValid: Bool = false,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder(),
        fileManager: FileManager = .default
    ) {
        self.path = path
        self.defaults = defaults
        self.requireValid = requireValid
        self.decoder = decoder
        self.encoder = encoder
        self.fileManager = fileManager
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public var configPath: String {
        path
    }

    public var exists: Bool {
        fileManager.fileExists(atPath: path)
    }

    public func load() throws -> Value {
        let url = URL(fileURLWithPath: path)
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            if requireValid {
                throw RuntimeConfigStoreError.readFailed(error.localizedDescription)
            }
            return defaults
        }

        do {
            return try decoder.decode(Value.self, from: data)
        } catch {
            if requireValid {
                throw RuntimeConfigStoreError.parseFailed(error.localizedDescription)
            }
            return defaults
        }
    }

    public func save(_ value: Value, permissions: Int16 = 0o600) throws {
        let url = URL(fileURLWithPath: path)
        let directory = url.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try encoder.encode(value)
            let temporaryURL = directory.appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp")
            try data.write(to: temporaryURL, options: .atomic)
            chmod(temporaryURL.path, mode_t(permissions))

            if fileManager.fileExists(atPath: url.path) {
                _ = try fileManager.replaceItemAt(url, withItemAt: temporaryURL)
            } else {
                try fileManager.moveItem(at: temporaryURL, to: url)
            }
            chmod(url.path, mode_t(permissions))
        } catch {
            throw RuntimeConfigStoreError.writeFailed(error.localizedDescription)
        }
    }
}
