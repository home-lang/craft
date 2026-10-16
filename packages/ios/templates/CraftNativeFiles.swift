import CryptoKit
import Foundation
import ImageIO
import PhotosUI
import UIKit
import UniformTypeIdentifiers

// `craft.files` on a native screen: a photo picked from the library (or taken
// with the camera), a file downloaded for the share sheet, and those files
// sent as a multipart form through the screen's `fetch`.
//
// A file is a path in the app's temporary directory (tmp/craft-files/<id>/
// <name>), described to JavaScript as `{ path, name, type, size }`. Its bytes
// never cross the bridge: a picked photo goes from the picker to disk to the
// upload without becoming a base64 string in JavaScriptCore, so a photo costs
// what its file costs rather than a third more, twice over, in the screen's
// memory. `fetch` and the share sheet take the path; only files made here are
// read back for a form, so a screen cannot post an arbitrary file of the app's.

enum CraftNativeFiles {
    /// The longest side of a picked photo unless the screen asks otherwise:
    /// sharp on any phone screen and in a share card, a few hundred kilobytes
    /// as JPEG, where the original can be 48 megapixels of HEIC.
    static let defaultMaxPixels = 2048
    static let largestMaxPixels = 8192
    static let defaultQuality = 0.85
    /// The part of a refused download's answer handed back, for its error.
    static let errorBodyLimit = 64 * 1024

    static var root: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("craft-files", isDirectory: true)
    }

    private static let lock = NSLock()
    private static var swept = false
    /// The picker on screen, kept alive until it answers. One at a time.
    private static var activePicker: NSObject?

    // MARK: Files of our own

    /// A new file called `name`, in a folder of its own so two files can share
    /// a name (the share sheet shows it).
    static func newFile(named name: String) throws -> URL {
        sweepOnce()
        let folder = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent(safeName(name))
    }

    /// The file at `path` when it is one made here and still there, else nil.
    static func owned(_ path: String) -> URL? {
        let url = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath()
        let base = root.standardizedFileURL.resolvingSymlinksInPath().path + "/"
        var isDirectory: ObjCBool = false
        guard url.path.hasPrefix(base),
              FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else { return nil }
        return url
    }

    /// A file name with no path in it.
    static func safeName(_ name: String) -> String {
        let parts = name.components(separatedBy: CharacterSet(charactersIn: "/\\:\u{0}\r\n"))
        var cleaned = parts.joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        while cleaned.hasPrefix(".") { cleaned.removeFirst() }
        return cleaned.isEmpty ? "file" : String(cleaned.prefix(120))
    }

    static func describe(_ url: URL, type: String, extra: [String: Any] = [:]) -> [String: Any] {
        let size = ((try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? NSNumber)?.intValue ?? 0
        var info: [String: Any] = ["path": url.path, "name": url.lastPathComponent, "type": type, "size": size]
        for (key, value) in extra { info[key] = value }
        return info
    }

    /// Forget a file made here. True when there was one.
    @discardableResult
    static func remove(_ path: String) -> Bool {
        guard let url = owned(path) else { return false }
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
        return true
    }

    /// Files from earlier launches that nobody removed: the system clears tmp
    /// eventually, this clears what is a day old the first time a file is made.
    private static func sweepOnce() {
        lock.lock()
        let first = !swept
        swept = true
        lock.unlock()
        guard first else { return }
        let fm = FileManager.default
        let dayAgo = Date().addingTimeInterval(-86_400)
        let folders = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.creationDateKey])) ?? []
        for folder in folders {
            let created = (try? folder.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
            if created < dayAgo { try? fm.removeItem(at: folder) }
        }
    }

    // MARK: Picking a photo

    /// A photo from the library (PHPickerViewController: no permission asked,
    /// the person sees only the picker) or, with `source: 'camera'` and the
    /// camera enabled, a new one (UIImagePickerController). Saved as a JPEG no
    /// larger than `maxPixels` on its longest side, upright, with no metadata
    /// (no location) left in it. Answers the file, or null when the person
    /// closed the picker. Main thread.
    static func pickImage(_ options: [String: Any], cameraEnabled: Bool, done: @escaping (Result<Any, CraftNativeActionError>) -> Void) {
        let maxPixels = min(largestMaxPixels, max(64, (options["maxPixels"] as? NSNumber)?.intValue ?? defaultMaxPixels))
        let quality = min(1, max(0.1, (options["quality"] as? NSNumber)?.doubleValue ?? defaultQuality))
        let source = options["source"] as? String ?? "library"
        guard activePicker == nil else {
            done(.failure(CraftNativeActionError(code: "BUSY", message: "A picker is already open")))
            return
        }
        let finish: (Result<Any, CraftNativeActionError>) -> Void = { result in
            DispatchQueue.main.async {
                activePicker = nil
                done(result)
            }
        }

        if source == "camera" {
            guard cameraEnabled else {
                done(.failure(CraftNativeActionError(code: "CAPABILITY_DISABLED", message: "The camera is disabled")))
                return
            }
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                done(.failure(CraftNativeActionError(code: "UNAVAILABLE", message: "This device has no camera")))
                return
            }
            let delegate = CameraDelegate(maxPixels: maxPixels, quality: quality, done: finish)
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = delegate
            activePicker = delegate
            if !CraftPresenter.present(picker, from: nil) {
                activePicker = nil
                done(.failure(CraftNativeActionError(code: "PICKER_ERROR", message: "Unable to present the camera")))
            }
            return
        }
        guard source == "library" else {
            done(.failure(CraftNativeActionError(code: "INVALID_ARGUMENT", message: "files.pickImage source is 'library' or 'camera'")))
            return
        }

        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        // The file as it is (HEIC stays HEIC): it is decoded once, below, at the size wanted.
        configuration.preferredAssetRepresentationMode = .current
        let delegate = LibraryDelegate(maxPixels: maxPixels, quality: quality, done: finish)
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = delegate
        activePicker = delegate
        if !CraftPresenter.present(picker, from: nil) {
            activePicker = nil
            done(.failure(CraftNativeActionError(code: "PICKER_ERROR", message: "Unable to present the photo picker")))
        }
    }

    /// Decode `source` at no more than `maxPixels` on its longest side, turned
    /// upright, and write it as a JPEG. ImageIO's thumbnail reads only what
    /// that size needs, so a huge original never sits in memory whole.
    static func writeJPEG(from source: CGImageSource, maxPixels: Int, quality: Double, name: String) -> Result<Any, CraftNativeActionError> {
        let thumbnail: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnail as CFDictionary) else {
            return .failure(CraftNativeActionError(code: "DECODE_ERROR", message: "The photo could not be read"))
        }
        return writeJPEG(image, quality: quality, name: name)
    }

    static func writeJPEG(_ image: CGImage, quality: Double, name: String) -> Result<Any, CraftNativeActionError> {
        do {
            let url = try newFile(named: name)
            guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
                return .failure(CraftNativeActionError(code: "WRITE_ERROR", message: "The photo could not be saved"))
            }
            CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
            guard CGImageDestinationFinalize(destination) else {
                return .failure(CraftNativeActionError(code: "WRITE_ERROR", message: "The photo could not be saved"))
            }
            return .success(describe(url, type: "image/jpeg", extra: ["width": image.width, "height": image.height]))
        } catch {
            return .failure(CraftNativeActionError(code: "WRITE_ERROR", message: error.localizedDescription))
        }
    }

    /// `IMG_1234.jpg` for the picker's `IMG_1234`, `photo.jpg` without one.
    static func jpegName(_ suggested: String?) -> String {
        var base = safeName(suggested ?? "photo")
        if let dot = base.lastIndex(of: "."), dot > base.startIndex { base = String(base[..<dot]) }
        return "\(base).jpg"
    }

    private final class LibraryDelegate: NSObject, PHPickerViewControllerDelegate {
        let maxPixels: Int
        let quality: Double
        let done: (Result<Any, CraftNativeActionError>) -> Void

        init(maxPixels: Int, quality: Double, done: @escaping (Result<Any, CraftNativeActionError>) -> Void) {
            self.maxPixels = maxPixels
            self.quality = quality
            self.done = done
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider else {
                done(.success(NSNull()))
                return
            }
            guard provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else {
                done(.failure(CraftNativeActionError(code: "DECODE_ERROR", message: "That is not a photo")))
                return
            }
            let name = CraftNativeFiles.jpegName(provider.suggestedName)
            let (maxPixels, quality, done) = (self.maxPixels, self.quality, self.done)
            // The file is only there for the length of this callback.
            provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
                guard let url, let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
                    done(.failure(CraftNativeActionError(code: "DECODE_ERROR", message: error?.localizedDescription ?? "The photo could not be read")))
                    return
                }
                done(CraftNativeFiles.writeJPEG(from: source, maxPixels: maxPixels, quality: quality, name: name))
            }
        }
    }

    private final class CameraDelegate: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let maxPixels: Int
        let quality: Double
        let done: (Result<Any, CraftNativeActionError>) -> Void

        init(maxPixels: Int, quality: Double, done: @escaping (Result<Any, CraftNativeActionError>) -> Void) {
            self.maxPixels = maxPixels
            self.quality = quality
            self.done = done
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            guard let image = info[.originalImage] as? UIImage else {
                done(.failure(CraftNativeActionError(code: "DECODE_ERROR", message: "The photo could not be read")))
                return
            }
            // Drawn at the size wanted, which also turns it upright.
            let longest = max(image.size.width * image.scale, image.size.height * image.scale)
            let factor = min(1, CGFloat(maxPixels) / max(1, longest))
            let size = CGSize(width: (image.size.width * image.scale * factor).rounded(), height: (image.size.height * image.scale * factor).rounded())
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            let drawn = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            guard let cgImage = drawn.cgImage else {
                done(.failure(CraftNativeActionError(code: "DECODE_ERROR", message: "The photo could not be read")))
                return
            }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            done(CraftNativeFiles.writeJPEG(cgImage, quality: quality, name: "IMG_\(formatter.string(from: Date())).jpg"))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            done(.success(NSNull()))
        }
    }

    // MARK: Picking a video

    /// System pickers grant access to just the selected video. Copy it while
    /// the provider's URL is valid; no movie bytes cross JavaScriptCore.
    static func pickVideo(_ options: [String: Any], done: @escaping (Result<Any, CraftNativeActionError>) -> Void) {
        guard activePicker == nil else {
            done(.failure(CraftNativeActionError(code: "BUSY", message: "A picker is already open")))
            return
        }
        let limit = min(512 * 1024 * 1024, max(1, (options["maxBytes"] as? NSNumber)?.intValue ?? 512 * 1024 * 1024))
        let finish: (Result<Any, CraftNativeActionError>) -> Void = { result in
            DispatchQueue.main.async { activePicker = nil; done(result) }
        }
        if options["source"] as? String == "files" {
            let delegate = VideoDocumentDelegate(limit: limit, done: finish)
            var types: [UTType] = [.movie]
            if let webm = UTType(filenameExtension: "webm") { types.append(webm) }
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
            picker.allowsMultipleSelection = false
            picker.delegate = delegate
            activePicker = delegate
            if !CraftPresenter.present(picker, from: nil) {
                activePicker = nil
                done(.failure(CraftNativeActionError(code: "PICKER_ERROR", message: "Unable to present the video picker")))
            }
        } else {
            var configuration = PHPickerConfiguration()
            configuration.filter = .videos
            configuration.selectionLimit = 1
            configuration.preferredAssetRepresentationMode = .current
            let delegate = VideoLibraryDelegate(limit: limit, done: finish)
            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = delegate
            activePicker = delegate
            if !CraftPresenter.present(picker, from: nil) {
                activePicker = nil
                done(.failure(CraftNativeActionError(code: "PICKER_ERROR", message: "Unable to present the video picker")))
            }
        }
    }

    static func copyVideo(_ source: URL, limit: Int) -> Result<Any, CraftNativeActionError> {
        let ext = source.pathExtension.lowercased()
        let types = ["mp4": "video/mp4", "m4v": "video/x-m4v", "mov": "video/quicktime", "webm": "video/webm"]
        guard let type = types[ext] else {
            return .failure(CraftNativeActionError(code: "INVALID_VIDEO", message: "Choose an MP4, MOV or WebM video."))
        }
        do {
            let size = ((try FileManager.default.attributesOfItem(atPath: source.path))[.size] as? NSNumber)?.intValue ?? 0
            guard size > 0, size <= limit else {
                return .failure(CraftNativeActionError(code: "FILE_TOO_LARGE", message: "Choose a nonempty video under \(limit / 1024 / 1024)MB."))
            }
            let destination = try newFile(named: source.lastPathComponent)
            do { try FileManager.default.copyItem(at: source, to: destination) }
            catch { try? FileManager.default.removeItem(at: destination.deletingLastPathComponent()); throw error }
            return .success(describe(destination, type: type))
        } catch {
            return .failure(CraftNativeActionError(code: "READ_ERROR", message: error.localizedDescription))
        }
    }

    private final class VideoLibraryDelegate: NSObject, PHPickerViewControllerDelegate {
        let limit: Int
        let done: (Result<Any, CraftNativeActionError>) -> Void
        init(limit: Int, done: @escaping (Result<Any, CraftNativeActionError>) -> Void) { self.limit = limit; self.done = done }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider else { done(.success(NSNull())); return }
            let (limit, done) = (self.limit, self.done)
            provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                guard let url else {
                    done(.failure(CraftNativeActionError(code: "READ_ERROR", message: error?.localizedDescription ?? "The video could not be read")))
                    return
                }
                done(CraftNativeFiles.copyVideo(url, limit: limit))
            }
        }
    }

    private final class VideoDocumentDelegate: NSObject, UIDocumentPickerDelegate {
        let limit: Int
        let done: (Result<Any, CraftNativeActionError>) -> Void
        init(limit: Int, done: @escaping (Result<Any, CraftNativeActionError>) -> Void) { self.limit = limit; self.done = done }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { done(.success(NSNull())) }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { done(.success(NSNull())); return }
            let (limit, done) = (self.limit, self.done)
            DispatchQueue.global(qos: .userInitiated).async {
                let granted = url.startAccessingSecurityScopedResource()
                defer { if granted { url.stopAccessingSecurityScopedResource() } }
                done(CraftNativeFiles.copyVideo(url, limit: limit))
            }
        }
    }

    // MARK: Sending files

    /// A multipart/form-data body from a screen's `FormData`: parts are
    /// `{ name, value }` or `{ name, path, filename?, type? }`, a file made
    /// here. Answers the body and its boundary.
    static func multipart(_ parts: [Any]) -> Result<(URL, String), CraftNativeActionError> {
        let boundary = "craft-\(UUID().uuidString)"
        var temporary: URL?
        do {
            let destination = try newFile(named: "upload.multipart")
            temporary = destination
            FileManager.default.createFile(atPath: destination.path, contents: nil)
            let output = try FileHandle(forWritingTo: destination)
            defer { try? output.close() }
            func append(_ text: String) throws { try output.write(contentsOf: Data(text.utf8)) }
            for item in parts {
                guard let part = item as? [String: Any], let name = part["name"] as? String else {
                    throw CraftNativeActionError(code: "INVALID_ARGUMENT", message: "A form part needs a name")
                }
                try append("--\(boundary)\r\n")
                if let path = part["path"] as? String {
                    guard let url = owned(path) else {
                        throw CraftNativeActionError(code: "INVALID_ARGUMENT", message: "A form file must be one craft.files made, and still there")
                    }
                    let filename = (part["filename"] as? String).map(safeName) ?? url.lastPathComponent
                    let type = (part["type"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "application/octet-stream"
                    try append("Content-Disposition: form-data; name=\"\(quoted(name))\"; filename=\"\(quoted(filename))\"\r\n")
                    try append("Content-Type: \(type.replacingOccurrences(of: "\r", with: "").replacingOccurrences(of: "\n", with: ""))\r\n\r\n")
                    let input = try FileHandle(forReadingFrom: url)
                    defer { try? input.close() }
                    while let chunk = try input.read(upToCount: 64 * 1024), !chunk.isEmpty {
                        try output.write(contentsOf: chunk)
                    }
                    try append("\r\n")
                } else {
                    try append("Content-Disposition: form-data; name=\"\(quoted(name))\"\r\n\r\n")
                    try append(part["value"] as? String ?? "")
                    try append("\r\n")
                }
            }
            try append("--\(boundary)--\r\n")
            return .success((destination, boundary))
        } catch {
            if let temporary { remove(temporary.path) }
            return .failure((error as? CraftNativeActionError) ?? CraftNativeActionError(code: "WRITE_ERROR", message: error.localizedDescription))
        }
    }

    /// A name inside a quoted header value, escaped as browsers send it.
    static func quoted(_ value: String) -> String {
        value.replacingOccurrences(of: "\"", with: "%22").replacingOccurrences(of: "\r", with: "%0D").replacingOccurrences(of: "\n", with: "%0A")
    }

    /// Keep a downloaded body as a file made here: the name the screen gave,
    /// else the server's (`Content-Disposition`), else the address's.
    static func keepDownload(at location: URL, response: HTTPURLResponse, name: String?) -> Result<Any, CraftNativeActionError> {
        let chosen = name.flatMap { $0.isEmpty ? nil : $0 } ?? response.suggestedFilename ?? "download"
        do {
            let url = try newFile(named: chosen)
            try FileManager.default.moveItem(at: location, to: url)
            let type = (response.mimeType ?? "application/octet-stream")
            return .success(describe(url, type: type, extra: ["ok": true, "status": response.statusCode]))
        } catch {
            return .failure(CraftNativeActionError(code: "WRITE_ERROR", message: error.localizedDescription))
        }
    }

    /// What a screen made itself (a CSV export, a route it built) written as
    /// a file for the share sheet: `data` is text (`encoding: 'utf8'`, the
    /// default, so a CSV crosses the bridge once and no larger) or base64
    /// (`encoding: 'base64'`, for bytes). What is already on a server is
    /// `download`ed instead, straight to disk.
    static func write(name: String, data: Any?, options: [String: Any]) -> Result<Any, CraftNativeActionError> {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(CraftNativeActionError(code: "INVALID_ARGUMENT", message: "files.write needs a file name"))
        }
        guard let text = data as? String else {
            return .failure(CraftNativeActionError(code: "INVALID_ARGUMENT", message: "files.write needs its contents as a string"))
        }
        let bytes: Data
        switch options["encoding"] as? String ?? "utf8" {
        case "utf8":
            bytes = Data(text.utf8)
        case "base64":
            guard let decoded = Data(base64Encoded: text.filter { !$0.isWhitespace }) else {
                return .failure(CraftNativeActionError(code: "INVALID_ARGUMENT", message: "files.write was given base64 it could not read"))
            }
            bytes = decoded
        default:
            return .failure(CraftNativeActionError(code: "INVALID_ARGUMENT", message: "files.write encoding is 'utf8' or 'base64'"))
        }
        let type = (options["type"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "application/octet-stream"
        do {
            let url = try newFile(named: name)
            try bytes.write(to: url, options: .atomic)
            return .success(describe(url, type: type))
        } catch {
            return .failure(CraftNativeActionError(code: "WRITE_ERROR", message: error.localizedDescription))
        }
    }

    /// A refused download: its status and the start of its answer, so the
    /// screen can say what the server said. No file is kept.
    static func refusedDownload(at location: URL?, response: HTTPURLResponse) -> [String: Any] {
        var text = ""
        if let location, let handle = try? FileHandle(forReadingFrom: location) {
            let data = handle.readData(ofLength: errorBodyLimit)
            try? handle.close()
            text = String(decoding: data, as: UTF8.self)
        }
        return ["ok": false, "status": response.statusCode, "body": text]
    }
}

// `craft.media` on a native screen: video and audio kept on the phone for
// when there is no signal (a gym's basement, a plane). Not tmp/craft-files,
// which iOS and the sweep above both empty: Application Support/craft-media,
// left out of iCloud backups because every file can be fetched again. A file
// is named by its address's SHA-256, so the native `Video` element finds the
// copy of the URL it was given and plays it instead, with no lookup in
// JavaScript. The screen decides what to keep (`keep`) and what to drop
// (`prune`); nothing is evicted behind its back.
enum CraftNativeMedia {
    static var root: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("craft-media", isDirectory: true)
    }

    private static let lock = NSLock()
    /// Addresses being fetched now, so a second `keep` waits for the first.
    private static var inFlight: [String: [(Result<Any, CraftNativeActionError>) -> Void]] = [:]

    /// Where `address`'s copy lives (whether or not it is there yet). The
    /// extension is the address's, because AVPlayer reads the type from it.
    static func file(for address: String) -> URL {
        let digest = SHA256.hash(data: Data(address.utf8)).map { String(format: "%02x", $0) }.joined()
        let ext = URL(string: address)?.pathExtension.lowercased() ?? ""
        let safe = ext.range(of: "^[a-z0-9]{1,5}$", options: .regularExpression) != nil ? ext : "bin"
        return root.appendingPathComponent("\(digest).\(safe)")
    }

    /// The copy of `address` on this phone, or nil.
    static func local(_ address: String) -> URL? {
        guard !address.isEmpty else { return nil }
        let url = file(for: address)
        return ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) > 0 ? url : nil
    }

    static func describe(_ address: String, _ url: URL) -> [String: Any] {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return ["ok": true, "url": address, "path": url.path, "size": size]
    }

    /// Joins a fetch of `address` already under way; true when one was.
    static func join(_ address: String, _ done: @escaping (Result<Any, CraftNativeActionError>) -> Void) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if inFlight[address] != nil {
            inFlight[address]!.append(done)
            return true
        }
        inFlight[address] = [done]
        return false
    }

    static func finish(_ address: String, _ result: Result<Any, CraftNativeActionError>) {
        lock.lock()
        let waiting = inFlight.removeValue(forKey: address) ?? []
        lock.unlock()
        for done in waiting { done(result) }
    }

    /// A finished download moved into place (atomically, so a half-written
    /// file is never played), or a refusal with the server's status.
    static func store(_ address: String, at location: URL, response: HTTPURLResponse) -> Result<Any, CraftNativeActionError> {
        guard response.statusCode == 200 else {
            return .success(["ok": false, "url": address, "status": response.statusCode])
        }
        let fm = FileManager.default
        // Commit and prune share a lock; neither can remove a file being committed.
        lock.lock()
        defer { lock.unlock() }
        let staging = root.appendingPathComponent(UUID().uuidString + ".part")
        defer { try? fm.removeItem(at: staging) }
        do {
            // URL resource values can retain a previous size when a retry
            // reuses a temporary location. Validate the current file itself.
            let size = (try fm.attributesOfItem(atPath: location.path)[.size] as? NSNumber)?.int64Value ?? 0
            // URLSession normally rejects a truncated transfer; also guard this boundary.
            let expected = response.expectedContentLength
            let encoded = response.value(forHTTPHeaderField: "Content-Encoding")
            if size <= 0 || (encoded == nil && expected >= 0 && size != expected) {
                return .failure(CraftNativeActionError(code: "NETWORK_ERROR", message: "media.keep received an incomplete file"))
            }
            var folder = root
            if !fm.fileExists(atPath: folder.path) {
                try fm.createDirectory(at: folder, withIntermediateDirectories: true)
                var values = URLResourceValues()
                values.isExcludedFromBackup = true
                try? folder.setResourceValues(values)
            }
            let target = file(for: address)
            try fm.moveItem(at: location, to: staging)
            _ = try? fm.removeItem(at: target)
            try fm.moveItem(at: staging, to: target)
            return .success(describe(address, target))
        }
        catch {
            return .failure(CraftNativeActionError(code: "IO_ERROR", message: "media.keep could not store the file: \(error.localizedDescription)"))
        }
    }

    /// Removes every copy whose address is not in `keep`; answers how many.
    static func prune(keep: [String]) -> Int {
        lock.lock()
        defer { lock.unlock() }
        let wanted = Set(keep.map { file(for: $0).lastPathComponent })
        let files = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        var removed = 0
        let active = Set(inFlight.keys.map { file(for: $0).lastPathComponent })
        for url in files where !wanted.contains(url.lastPathComponent) && !active.contains(url.lastPathComponent) {
            if (try? FileManager.default.removeItem(at: url)) != nil { removed += 1 }
        }
        return removed
    }

    /// What the kept copies come to, in bytes, and how many there are.
    static func usage() -> [String: Any] {
        let files = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        let kept = files.filter { $0.pathExtension != "part" }
        let bytes = kept.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        return ["files": kept.count, "bytes": bytes]
    }
}
