import Foundation

/// Persistent consent and exclusions. Captured only once per source, not at every launch.
public struct ArrivalState: Codable, Sendable {
    public var source: URL
    public var enabled: Bool
    public var originalFiles: [String: Fingerprint]
    public var unreadablePaths: Set<String>

    public init(source: URL, enabled: Bool) throws {
        try FileSafety.validateDirectory(source)
        self.source = source; self.enabled = enabled
        originalFiles = [:]; unreadablePaths = []
        for url in try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil) {
            ignore(url)
        }
    }
    public mutating func ignore(_ url: URL) {
        if let fingerprint = try? Fingerprint(url) { originalFiles[url.path] = fingerprint }
        else { unreadablePaths.insert(url.path) }
    }
    public func excludedPaths() throws -> Set<String> {
        var paths = unreadablePaths
        let identities = Set(originalFiles.values.map { "\($0.device):\($0.inode)" })
        for url in try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil) {
            // Original files remain excluded after edits or renames within the source.
            // A genuinely new file with the same filename has a different identity.
            guard let current = try? Fingerprint(url) else { continue }
            if identities.contains("\(current.device):\(current.inode)") { paths.insert(url.path) }
        }
        return paths
    }
    public static func load(journal: Journal, source: URL, defaultEnabled: Bool) throws -> ArrivalState {
        let file = journal.folder.appendingPathComponent("automation.json")
        if FileSafety.exists(file) {
            try FileSafety.validatePath(file)
            let state = try JSONDecoder().decode(ArrivalState.self, from: Data(contentsOf: file))
            if state.source.standardizedFileURL.path == source.standardizedFileURL.path { return state }
        }
        let state = try ArrivalState(source: source, enabled: defaultEnabled)
        try state.save(journal: journal)
        return state
    }
    public func save(journal: Journal) throws { try journal.save(self, to: journal.folder.appendingPathComponent("automation.json")) }
}
