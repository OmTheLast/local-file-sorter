import Foundation
import Darwin

public final class Journal: @unchecked Sendable {
    public let folder: URL
    private let lockFD: Int32
    public init(folder: URL) throws {
        self.folder = folder
        try FileSafety.validatePath(folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        lockFD = open(folder.appendingPathComponent("session.lock").path, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
        guard lockFD >= 0 else { throw SorterError.message("Cannot create history lock.") }
        guard flock(lockFD, LOCK_EX | LOCK_NB) == 0 else { close(lockFD); throw SorterError.message("Another sorter is using this history. Close it first.") }
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("moves"), withIntermediateDirectories: true)
    }
    deinit { flock(lockFD, LOCK_UN); close(lockFD) }
    public func save<T: Encodable>(_ value: T, to url: URL) throws {
        try FileSafety.validatePath(url)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW)
        guard fd >= 0 else { throw SorterError.message("Cannot flush persistent history.") }
        defer { close(fd) }
        guard fsync(fd) == 0 else { throw SorterError.message("Cannot flush persistent history.") }
        let parent = open(url.deletingLastPathComponent().path, O_RDONLY)
        if parent >= 0 { _ = fsync(parent); close(parent) }
    }
    public func save(_ record: MoveRecord) throws { try save(record, to: folder.appendingPathComponent("moves/\(record.id.uuidString).json")) }
    public func records() throws -> [MoveRecord] {
        let urls = try FileManager.default.contentsOfDirectory(at: folder.appendingPathComponent("moves"), includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }
        return try urls.map { url in
            try FileSafety.validatePath(url)
            return try JSONDecoder().decode(MoveRecord.self, from: Data(contentsOf: url))
        }.sorted { $0.date > $1.date }
    }
    public func loadSettings() throws -> Settings? {
        let url = folder.appendingPathComponent("settings.json")
        guard FileSafety.exists(url) else { return nil }
        try FileSafety.validatePath(url)
        return try JSONDecoder().decode(Settings.self, from: Data(contentsOf: url))
    }
    public func saveSettings(_ settings: Settings) throws { try settings.validate(); try save(settings, to: folder.appendingPathComponent("settings.json")) }
    public func recover() throws {
        for var record in try records() where ["pending", "undoPending"].contains(record.state) {
            let isUndo = record.state == "undoPending"
            let from = isUndo ? record.destination : record.original
            let to = isUndo ? record.undoDestination : record.destination
            if let to, matches(to, record: record), !FileSafety.exists(from) {
                record.state = isUndo ? "undone" : "moved"; record.note = "Recovered completed operation after interruption."
            } else if matches(from, record: record), to.map({ !FileSafety.exists($0) }) == true {
                record.state = isUndo ? "moved" : "cancelled"; record.note = "Interrupted before rename; file was left in place."
            } else {
                record.state = "attention"; record.note = "Interrupted operation is ambiguous. Inspect both paths manually; no automatic changes made."
            }
            try save(record)
        }
    }
    private func matches(_ url: URL, record: MoveRecord) -> Bool {
        guard (try? FileSafety.validatePath(url)) != nil, let fp = try? Fingerprint(url), record.fingerprint.sameIdentity(as: fp), let digest = try? FileSafety.digest(url) else { return false }
        return digest == record.digest
    }
}

public actor SorterEngine {
    private var stability = StabilityTracker()
    private let journal: Journal
    public init(journal: Journal) { self.journal = journal }
    public func scan(settings: Settings, excluding: Set<String> = []) async throws -> ScanResult {
        try settings.validate()
        let urls = try FileManager.default.contentsOfDirectory(at: settings.source, includingPropertiesForKeys: nil).sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        var result = ScanResult(); var reserved = Set<String>()
        stability.prune(paths: Set(urls.map(\.path)))
        for url in urls {
            if excluding.contains(url.path) { continue }
            try Task.checkCancellation()
            if let reason = FileSafety.skipReason(url, destination: settings.destination) { result.skipped.append("\(url.lastPathComponent): \(reason)"); continue }
            do {
                let fp = try Fingerprint(url)
                guard stability.isReady(url, fingerprint: fp, interval: settings.settleSeconds) else { result.waiting += 1; continue }
                guard try !FileSafety.hasOpenWriter(url) else { result.waiting += 1; continue }
                let decision = await Classifier.classify(url, settings: settings)
                guard try Fingerprint(url) == fp else { result.waiting += 1; continue }
                let category = settings.categories.first { $0.id == decision.categoryID } ?? settings.review
                let requested = settings.destination.appendingPathComponent(category.name).appendingPathComponent(url.lastPathComponent)
                let destination = FileSafety.collisionSafe(requested, reserved: reserved); reserved.insert(destination.path)
                result.proposals.append(Proposal(source: url, destination: destination, fingerprint: fp, decision: decision))
            } catch {
                // Cannot prove readiness: keep in source, visibly report instead of moving.
                result.skipped.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return result
    }
    public func move(_ proposal: Proposal, settings: Settings) throws -> MoveRecord {
        try settings.validate()
        _ = try journal.records() // Refuse new moves if persistent history is unreadable.
        guard proposal.approved else { throw SorterError.message("This file has not been approved.") }
        guard proposal.source.deletingLastPathComponent().standardizedFileURL.path == settings.source.standardizedFileURL.path, FileSafety.skipReason(proposal.source, destination: settings.destination) == nil else { throw SorterError.message("File is outside the source or no longer eligible.") }
        guard let category = settings.categories.first(where: { $0.id == proposal.categoryID }) else { throw SorterError.message("Category changed; refresh the preview.") }
        try FileSafety.validatePath(proposal.source)
        let fp = try Fingerprint(proposal.source)
        guard fp == proposal.fingerprint, Date().timeIntervalSince(fp.modified) >= settings.settleSeconds, try !FileSafety.hasOpenWriter(proposal.source) else { throw SorterError.message("File changed or is still being written; refresh the preview.") }
        let fd = open(proposal.source.path, O_RDONLY | O_NOFOLLOW)
        guard fd >= 0 else { throw SorterError.message("Cannot lock source file.") }
        defer { flock(fd, LOCK_UN); close(fd) }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { throw SorterError.message("File is busy; retry later.") }
        let digest = try FileSafety.digest(proposal.source)
        guard try Fingerprint(proposal.source) == fp else { throw SorterError.message("File changed while being verified.") }
        let base = settings.destination.appendingPathComponent(category.name)
        // Accept the preview path only when it is in the selected category and preserves the filename.
        guard proposal.destination.path.hasPrefix(base.path + "/"), proposal.destination.lastPathComponent == proposal.source.lastPathComponent else { throw SorterError.message("Invalid preview destination.") }
        let destination = FileSafety.collisionSafe(proposal.destination)
        try FileSafety.validatePath(destination)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileSafety.validateDirectory(destination.deletingLastPathComponent())
        var record = MoveRecord(original: proposal.source, destination: destination, fingerprint: fp, digest: digest, reason: proposal.reason)
        try journal.save(record) // Write-ahead journal must succeed before touching the file.
        do {
            guard try Fingerprint(proposal.source) == fp else { throw SorterError.message("File changed before move.") }
            try FileSafety.exclusiveRename(proposal.source, destination)
        } catch {
            record.state = "cancelled"; record.note = error.localizedDescription; try journal.save(record); throw error
        }
        record.state = "moved"
        // If persistence fails here, the pending record remains recoverable on the next launch.
        try journal.save(record)
        return record
    }
    public func undo(_ id: UUID) throws -> MoveRecord {
        guard var record = try journal.records().first(where: { $0.id == id }), record.state == "moved" else { throw SorterError.message("This move cannot be undone automatically.") }
        try FileSafety.validatePath(record.destination); try FileSafety.validatePath(record.original)
        guard let current = try? Fingerprint(record.destination), record.fingerprint.sameIdentity(as: current), try FileSafety.digest(record.destination) == record.digest, try !FileSafety.hasOpenWriter(record.destination) else { throw SorterError.message("Sorted file changed, is missing or busy; undo left it untouched.") }
        let restore = FileSafety.collisionSafe(record.original)
        try FileSafety.validatePath(restore)
        try FileManager.default.createDirectory(at: restore.deletingLastPathComponent(), withIntermediateDirectories: true)
        record.state = "undoPending"; record.undoDestination = restore; try journal.save(record)
        do {
            guard try Fingerprint(record.destination) == current else { throw SorterError.message("File changed during undo.") }
            try FileSafety.exclusiveRename(record.destination, restore)
        } catch { record.state = "moved"; record.note = error.localizedDescription; try journal.save(record); throw error }
        record.state = "undone"; record.note = restore == record.original ? "Restored to original location." : "Original location was occupied; restored with original filename in Duplicates."
        try journal.save(record); return record
    }
}
