import CryptoKit
import Foundation

/// The existing Storage API's durable, process-wide serialized backing store.
/// Tombstones prevent an old UserDefaults value from reappearing after removal.
enum CraftPersistentStorage {
    private static let lock = NSRecursiveLock()
    private static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("craft-native-storage")
    }
    private static func path(_ key: String, directory: URL) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(digest + ".json")
    }
    static func get(_ key: String, prefix: String, storageDirectory: URL? = nil) throws -> Data? {
        lock.lock(); defer { lock.unlock() }
        let source = path(key, directory: storageDirectory ?? directory)
        if FileManager.default.fileExists(atPath: source.path) {
            guard let saved = try JSONSerialization.jsonObject(with: Data(contentsOf: source)) as? [String: Any], saved["key"] as? String == key else {
                throw CraftNativeActionError(code: "STORAGE_CORRUPT", message: "Invalid stored value")
            }
            if saved["deleted"] as? Bool == true { return nil }
            guard let value = saved["value"] else { throw CraftNativeActionError(code: "STORAGE_CORRUPT", message: "Missing stored value") }
            return try JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed)
        }
        guard let legacy = UserDefaults.standard.data(forKey: prefix + key) else { return nil }
        // Reading a valid legacy checkpoint must survive a full disk. Migration
        // can be retried on a later read; only a successful set promises a new
        // durable checkpoint and permits the application to acknowledge it.
        do { try set(key, data: legacy, prefix: prefix, storageDirectory: storageDirectory) }
        catch { print("Unable to migrate an existing storage value: \(error)") }
        return legacy
    }
    static func set(_ key: String, data: Data?, prefix: String, storageDirectory: URL? = nil, writer: CraftRecordingArchive.Writer = CraftRecordingArchive.writeAtomically) throws {
        lock.lock(); defer { lock.unlock() }
        var entry: [String: Any] = ["key": key, "deleted": data == nil]
        if let data { entry["value"] = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) }
        try writer(JSONSerialization.data(withJSONObject: entry), path(key, directory: storageDirectory ?? directory))
        if let data { UserDefaults.standard.set(data, forKey: prefix + key) }
        else { UserDefaults.standard.removeObject(forKey: prefix + key) }
    }
    static func keys(prefix: String) throws -> [String] {
        lock.lock(); defer { lock.unlock() }
        var result = Set(UserDefaults.standard.dictionaryRepresentation().keys.filter { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) })
        if FileManager.default.fileExists(atPath: directory.path) {
            for source in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) where source.pathExtension == "json" {
                guard let entry = try JSONSerialization.jsonObject(with: Data(contentsOf: source)) as? [String: Any], let key = entry["key"] as? String else {
                    throw CraftNativeActionError(code: "STORAGE_CORRUPT", message: "Invalid stored value")
                }
                if entry["deleted"] as? Bool == true { result.remove(key) } else { result.insert(key) }
            }
        }
        return result.sorted()
    }
    static func clear(prefix: String) throws {
        lock.lock(); defer { lock.unlock() }
        for key in try keys(prefix: prefix) { try set(key, data: nil, prefix: prefix) }
    }
}
