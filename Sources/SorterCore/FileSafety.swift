import Foundation
import CryptoKit
import Darwin

public enum FileSafety {
    public static let temporaryExtensions: Set<String> = ["download", "crdownload", "part", "partial", "tmp", "temp", "opdownload", "filepart"]
    public static func validatePath(_ url: URL) throws {
        var cursor = URL(fileURLWithPath: "/", isDirectory: true)
        for component in url.pathComponents.dropFirst() {
            guard component != ".", component != ".." else { throw SorterError.message("Choose an absolute folder path without traversal components.") }
            cursor.appendPathComponent(component)
            var st = stat()
            if lstat(cursor.path, &st) == 0 {
                guard st.st_mode & S_IFMT != S_IFLNK else { throw SorterError.message("Symbolic links are not allowed in folder paths: \(cursor.path)") }
                let values = try cursor.resourceValues(forKeys: [.isAliasFileKey])
                guard values.isAliasFile != true else { throw SorterError.message("Alias folders are not supported.") }
            } else if errno != ENOENT { throw SorterError.message("Cannot inspect \(cursor.path): \(String(cString: strerror(errno)))") }
        }
    }
    public static func validateDirectory(_ url: URL) throws {
        try validatePath(url)
        let v = try url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        guard v.isDirectory == true, v.isPackage != true else { throw SorterError.message("Choose an ordinary folder: \(url.path)") }
    }
    public static func skipReason(_ url: URL, destination: URL) -> String? {
        let path = url.standardizedFileURL.path, d = destination.standardizedFileURL.path
        if path == d || path.hasPrefix(d + "/") { return "Destination folder" }
        let name = url.lastPathComponent.lowercased()
        if name.hasPrefix(".") || name.hasPrefix("~$") || name.hasSuffix("~") { return "Hidden or temporary file" }
        if temporaryExtensions.contains(url.pathExtension.lowercased()) { return "Incomplete download / temporary file" }
        guard let v = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .isAliasFileKey, .isPackageKey, .isHiddenKey, .ubiquitousItemDownloadingStatusKey, .isUbiquitousItemKey]) else { return "Cannot inspect file" }
        if v.isSymbolicLink == true || v.isAliasFile == true { return "Link or alias" }
        if v.isPackage == true || v.isRegularFile != true { return "Folder or application bundle" }
        if v.isHidden == true { return "Hidden file" }
        if v.isUbiquitousItem == true && v.ubiquitousItemDownloadingStatus != .current { return "Cloud placeholder is not locally downloaded" }
        return nil
    }
    public static func digest(_ url: URL) throws -> String {
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW)
        guard fd >= 0 else { throw SorterError.message("Cannot read file safely.") }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        var hash = SHA256()
        while let block = try handle.read(upToCount: 1_048_576), !block.isEmpty { hash.update(data: block) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
    // Preserve the filename; use a unique enclosing folder on collision.
    public static func collisionSafe(_ requested: URL, reserved: Set<String> = []) -> URL {
        if !exists(requested) && !reserved.contains(requested.path) { return requested }
        return requested.deletingLastPathComponent().appendingPathComponent("Duplicates/\(UUID().uuidString)", isDirectory: true).appendingPathComponent(requested.lastPathComponent)
    }
    public static func exists(_ url: URL) -> Bool { var st = stat(); return lstat(url.path, &st) == 0 }
    public static func exclusiveRename(_ source: URL, _ destination: URL) throws {
        // Kernel-enforced no-replace, including races after the preview.
        guard renamex_np(source.path, destination.path, UInt32(RENAME_EXCL)) == 0 else {
            if errno == EXDEV { throw SorterError.message("This prototype only moves within one volume. Choose a destination on the source volume.") }
            throw SorterError.message("Move refused: \(String(cString: strerror(errno)))")
        }
        for folder in [source.deletingLastPathComponent(), destination.deletingLastPathComponent()] {
            let fd = open(folder.path, O_RDONLY); if fd >= 0 { _ = fsync(fd); close(fd) }
        }
    }
    public static func hasOpenWriter(_ url: URL) throws -> Bool {
        let result = try LocalProcess.run("/usr/sbin/lsof", ["-F", "fa", "--", url.path], limit: 100_000, timeout: 4, acceptedExitCodes: [0, 1])
        return result.components(separatedBy: .newlines).contains { $0 == "aw" || $0 == "au" }
    }
}

public enum LocalProcess {
    // No shell, network clients, archive extraction or executable document content.
    public static func run(_ executable: String, _ arguments: [String], limit: Int = 4_000_000, timeout: Double = 8, acceptedExitCodes: Set<Int32> = [0]) throws -> String {
        let p = Process(); p.executableURL = URL(fileURLWithPath: executable); p.arguments = arguments
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
        try p.run()
        let watchdog = DispatchWorkItem { if p.isRunning { kill(p.processIdentifier, SIGKILL) } }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: watchdog)
        defer { watchdog.cancel(); try? pipe.fileHandleForReading.close() }
        var data = Data()
        while let chunk = try pipe.fileHandleForReading.read(upToCount: 65_536), !chunk.isEmpty {
            data.append(chunk)
            if data.count > limit { kill(p.processIdentifier, SIGKILL); p.waitUntilExit(); throw SorterError.message("Extraction exceeds the local size limit.") }
        }
        p.waitUntilExit()
        guard acceptedExitCodes.contains(p.terminationStatus) else { throw SorterError.message("Local extraction or file readiness check failed or timed out.") }
        return String(decoding: data, as: UTF8.self)
    }
}

public struct StabilityTracker: Sendable {
    private var seen: [String: (Fingerprint, Date)] = [:]
    public init() {}
    public mutating func isReady(_ url: URL, fingerprint: Fingerprint, now: Date = Date(), interval: Double) -> Bool {
        defer { if seen[url.path]?.0 != fingerprint { seen[url.path] = (fingerprint, now) } }
        guard let prior = seen[url.path], prior.0 == fingerprint else { return false }
        return now.timeIntervalSince(prior.1) >= interval && now.timeIntervalSince(fingerprint.modified) >= interval
    }
    public mutating func prune(paths: Set<String>) { seen = seen.filter { paths.contains($0.key) } }
}
