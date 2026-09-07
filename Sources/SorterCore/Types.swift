import Foundation
import Darwin

public struct Category: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var detail: String
    public init(id: String = UUID().uuidString, name: String, detail: String) { self.id = id; self.name = name; self.detail = detail }
    public static let defaults = [
        Category(id: "invoices", name: "Invoices", detail: "Bills, receipts, payment requests and tax invoices."),
        Category(id: "work", name: "Work", detail: "Project plans, business correspondence, meeting notes and professional deliverables."),
        Category(id: "research", name: "Research", detail: "Academic papers, experiments, studies, literature reviews and technical research."),
        Category(id: "images", name: "Images", detail: "Photographs and image files."),
        Category(id: "installers", name: "Installers", detail: "Disk images and installation packages."),
        Category(id: "archives", name: "Archives", detail: "Compressed archives."),
        Category(id: "review", name: "Needs Review", detail: "Unsupported, ambiguous, unreadable or uncertain files.")
    ]
}
public struct Settings: Codable, Equatable, Sendable {
    public var source: URL
    public var destination: URL
    public var categories: [Category]
    public var useAI: Bool
    public var settleSeconds: Double
    public init(source: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads"), destination: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/Sorted Files"), categories: [Category] = Category.defaults, useAI: Bool = true, settleSeconds: Double = 15) {
        self.source = source; self.destination = destination; self.categories = categories; self.useAI = useAI; self.settleSeconds = settleSeconds
    }
    public func validate() throws {
        guard categories.contains(where: { $0.id == "review" }), (1...16).contains(categories.count) else { throw SorterError.message("Keep Needs Review and at most 16 categories.") }
        var names = Set<String>(); var ids = Set<String>()
        for c in categories {
            let n = c.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard n == c.name, !n.isEmpty, n.count <= 64, !n.hasPrefix("."), !n.contains("/"), !n.contains(":"), !n.contains("\\"), !n.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }), c.detail.count <= 300, ids.insert(c.id).inserted, names.insert(n.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)).inserted else { throw SorterError.message("Category names must be unique, plain folder names (1–64 characters); descriptions at most 300 characters.") }
        }
        try FileSafety.validateDirectory(source)
        try FileSafety.validatePath(destination)
        let s = source.standardizedFileURL.path, d = destination.standardizedFileURL.path
        guard s != d, !s.hasPrefix(d + "/") else { throw SorterError.message("Source cannot be the destination or inside it.") }
        guard settleSeconds >= 5 else { throw SorterError.message("The settling period must be at least 5 seconds.") }
    }
    public var review: Category { categories.first(where: { $0.id == "review" })! }
}
public enum SorterError: LocalizedError {
    case message(String)
    public var errorDescription: String? { if case .message(let s) = self { return s }; return nil }
}
public struct Fingerprint: Codable, Equatable, Sendable {
    public var device: Int32; public var inode: UInt64; public var size: Int64
    public var modifiedSeconds: Int64; public var modifiedNanos: Int64
    public var changedSeconds: Int64; public var changedNanos: Int64
    public init(_ url: URL) throws {
        var st = stat()
        guard lstat(url.path, &st) == 0, st.st_mode & S_IFMT == S_IFREG else { throw SorterError.message("Not a regular file: \(url.lastPathComponent)") }
        device = st.st_dev; inode = st.st_ino; size = st.st_size
        modifiedSeconds = Int64(st.st_mtimespec.tv_sec); modifiedNanos = Int64(st.st_mtimespec.tv_nsec)
        changedSeconds = Int64(st.st_ctimespec.tv_sec); changedNanos = Int64(st.st_ctimespec.tv_nsec)
    }
    public var modified: Date { Date(timeIntervalSince1970: Double(modifiedSeconds) + Double(modifiedNanos)/1e9) }
    public func sameIdentity(as other: Fingerprint) -> Bool { device == other.device && inode == other.inode && size == other.size && modifiedSeconds == other.modifiedSeconds && modifiedNanos == other.modifiedNanos }
}
public struct Decision: Sendable {
    public var categoryID: String; public var reason: String; public var method: String
    public init(_ categoryID: String, _ reason: String, method: String = "Rule") { self.categoryID = categoryID; self.reason = reason; self.method = method }
}
public struct Proposal: Identifiable, Sendable {
    public let id: UUID
    public var source: URL; public var destination: URL; public var fingerprint: Fingerprint
    public var categoryID: String; public var reason: String; public var method: String
    public var approved: Bool = false
    public init(source: URL, destination: URL, fingerprint: Fingerprint, decision: Decision) {
        id = UUID(); self.source = source; self.destination = destination; self.fingerprint = fingerprint
        categoryID = decision.categoryID; reason = decision.reason; method = decision.method
    }
}
public struct ScanResult: Sendable {
    public var proposals: [Proposal] = []; public var skipped: [String] = []; public var waiting: Int = 0
}
public struct MoveRecord: Codable, Identifiable, Sendable {
    public var id: UUID = UUID(); public var date: Date = Date()
    public var original: URL; public var destination: URL; public var fingerprint: Fingerprint
    public var digest: String; public var reason: String; public var state: String = "pending"
    public var undoDestination: URL?; public var note: String?
    public init(original: URL, destination: URL, fingerprint: Fingerprint, digest: String, reason: String) {
        self.original = original; self.destination = destination; self.fingerprint = fingerprint; self.digest = digest; self.reason = reason
    }
}
