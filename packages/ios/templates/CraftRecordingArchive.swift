import CryptoKit
import Foundation
import Darwin

/// Immutable completed recordings and durable acknowledgement tombstones.
/// IDs are opaque values; their SHA-256, never caller path text, names a file.
enum CraftRecordingArchive {
    typealias Writer = (Data, URL) throws -> Void
    static func writeAtomically(_ data: Data, _ url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let temporary = url.deletingLastPathComponent().appendingPathComponent(".craft-atomic-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporary) }
        try data.write(to: temporary, options: .withoutOverwriting)
        let file = try FileHandle(forWritingTo: temporary)
        do { try file.synchronize(); try file.close() }
        catch { try? file.close(); throw error }
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: temporary.path)
        var protected = temporary
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try protected.setResourceValues(values)
        let result = temporary.path.withCString { source in url.path.withCString { destination in Darwin.rename(source, destination) } }
        if result != 0 { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
    }

    private static func url(_ directory: URL, _ kind: String, _ id: String, acknowledged: Bool = false) -> URL {
        let digest = SHA256.hash(data: Data(id.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent("craft-\(kind)-\(acknowledged ? "ack" : "completed")-\(digest).json")
    }
    static func isAcknowledged(_ directory: URL, _ kind: String, _ id: String) throws -> Bool {
        let marker = url(directory, kind, id, acknowledged: true)
        guard FileManager.default.fileExists(atPath: marker.path) else { return false }
        guard try Data(contentsOf: marker) == Data(id.utf8) else {
            throw CraftNativeActionError(code: "RECORDING_STORAGE_ERROR", message: "Invalid recording acknowledgement")
        }
        return true
    }
    static func read(_ directory: URL, _ kind: String, _ id: String) throws -> [String: Any]? {
        if try isAcknowledged(directory, kind, id) {
            try acknowledge(directory, kind, id)
            throw CraftNativeActionError(code: "RECORDING_NOT_FOUND", message: "This recording has been acknowledged")
        }
        let source = url(directory, kind, id)
        guard FileManager.default.fileExists(atPath: source.path) else { return nil }
        let data = try Data(contentsOf: source)
        guard let value = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              value["id"] as? String == id, value["active"] as? Bool == false,
              value[kind == "location" ? "locations" : "samples"] is [[String: Any]] else {
            throw CraftNativeActionError(code: "RECORDING_STORAGE_ERROR", message: "Invalid completed recording archive")
        }
        return value
    }
    static func save(_ directory: URL, _ kind: String, _ state: [String: Any], samples: [[String: Any]], writer: Writer = writeAtomically) throws {
        guard let id = state["id"] as? String else { return }
        if try isAcknowledged(directory, kind, id) { try acknowledge(directory, kind, id); return }
        if try read(directory, kind, id) != nil { return }
        var completed = state
        completed["active"] = false
        completed["paused"] = false
        completed["sampleCount"] = samples.count
        completed[kind == "location" ? "locations" : "samples"] = samples
        try writer(JSONSerialization.data(withJSONObject: completed), url(directory, kind, id))
    }
    static func acknowledge(_ directory: URL, _ kind: String, _ id: String) throws {
        let marker = url(directory, kind, id, acknowledged: true)
        if try !isAcknowledged(directory, kind, id) { try writeAtomically(Data(id.utf8), marker) }
        let archive = url(directory, kind, id)
        if FileManager.default.fileExists(atPath: archive.path) { try FileManager.default.removeItem(at: archive) }
    }
}
