import Foundation
import UIKit
import MetricKit
import MachO
import Network

// MARK: - Crash reporting (bughq)
//
// `crashReporting` in craft.config.json turns this on: the app's crashes,
// hangs and uncaught JavaScript errors become bughq events (https://bughq.org,
// or a self-hosted host), sent from an on-disk outbox so a crash or an error
// captured offline is delivered when the phone is next online.
//
// Three ways a failure is caught, because no single one sees everything:
//
//  * In process, at the moment of the crash: POSIX signal handlers (a Swift
//    trap is SIGTRAP, a bad pointer SIGSEGV/SIGBUS) and the uncaught
//    NSException handler. They write a small report file and let the crash
//    continue, so iOS still records it. The report is sent on the next launch.
//    The signal handler runs with the process in an unknown state, so it only
//    touches memory allocated at install time and calls async-signal-safe
//    functions (open, write, close, vm_read_overwrite): no Swift strings, no
//    arrays, no allocation.
//  * MetricKit: iOS's own crash and hang diagnostics (MXCrashDiagnostic,
//    MXHangDiagnostic), delivered on a later launch. It sees what an in-process
//    handler cannot (a watchdog kill, a crash in a frame the handler could not
//    walk) and is the only source of hangs. A crash both paths saw is sent once:
//    the in-process report records its signature and the MetricKit copy is
//    dropped.
//  * JavaScript: an uncaught exception in a native screen or the app script
//    (JavaScriptCore's exceptionHandler, CraftNativeScreen.swift), and events
//    the page or a screen hands over through `craft.crashReporter.capture`.
//
// Frames are sent as `image + offset` with the image's UUID. bughq turns them
// into function names and lines with the dSYM symbols uploaded from the build
// (Xcode Cloud's ci_post_xcodebuild.sh), so nothing here needs the symbols.
//
// Only the app's own user id (`craft.crashReporter.setUser`) identifies a
// person. No email, name or health data is read or sent.

/// Report file written by the signal handler, read on the next launch.
private let craftCrashMaxFrames = 128
private let craftCrashMaxImagesWithCrashInfo = 64

// Everything the signal handler reads, allocated at install time.
private var craftCrashPath: UnsafeMutablePointer<CChar>?
private var craftCrashScratch: UnsafeMutablePointer<UInt8>?
private var craftCrashFrames: UnsafeMutablePointer<UInt64>?
private var craftCrashInfoSections: UnsafeMutablePointer<UInt64>?
private var craftCrashInfoCount: Int32 = 0
private var craftCrashInProgress: Int32 = 0
private var craftCrashExceptionRecorded: Int32 = 0
private var craftCrashPreviousActions: UnsafeMutablePointer<sigaction>?
private var craftCrashAltStack: UnsafeMutableRawPointer?
private var craftPreviousExceptionHandler: (@convention(c) (NSException) -> Void)?
/// The signals a crash arrives as. A switch rather than an array, so the
/// handler can read it without touching a Swift collection.
private let craftCrashSignalCount = 7
@inline(__always)
private func craftCrashSignalAt(_ index: Int) -> Int32 {
    switch index {
    case 0: return SIGABRT
    case 1: return SIGBUS
    case 2: return SIGFPE
    case 3: return SIGILL
    case 4: return SIGSEGV
    case 5: return SIGTRAP
    default: return SIGSYS
    }
}

/// Strips pointer-authentication bits from a return address. Apps build arm64
/// (no PAC), but system libraries on an arm64e phone sign theirs.
@inline(__always)
private func craftStrip(_ address: UInt64) -> UInt64 {
    #if targetEnvironment(simulator)
    return address
    #else
    return address & 0x0000_000F_FFFF_FFFF
    #endif
}

@inline(__always)
private func craftWriteBytes(_ fd: Int32, _ bytes: UnsafePointer<UInt8>, _ count: Int) {
    var written = 0
    while written < count {
        let n = Darwin.write(fd, bytes + written, count - written)
        if n <= 0 { return }
        written += n
    }
}

/// Writes a static C string (a literal: no allocation).
@inline(__always)
private func craftWriteLiteral(_ fd: Int32, _ text: StaticString) {
    craftWriteBytes(fd, text.utf8Start, text.utf8CodeUnitCount)
}

/// Writes `value` as lowercase hex, through the preallocated scratch buffer.
private func craftWriteHex(_ fd: Int32, _ value: UInt64) {
    guard let scratch = craftCrashScratch else { return }
    let digits: StaticString = "0123456789abcdef"
    var v = value
    var i = 31
    repeat {
        scratch[i] = digits.utf8Start[Int(v & 0xF)]
        v >>= 4
        i -= 1
    } while v != 0 && i > 1
    scratch[i] = UInt8(ascii: "x")
    scratch[i - 1] = UInt8(ascii: "0")
    craftWriteBytes(fd, UnsafePointer(scratch + (i - 1)), 32 - (i - 1))
}

private func craftWriteDecimal(_ fd: Int32, _ value: Int64) {
    guard let scratch = craftCrashScratch else { return }
    var v = value < 0 ? UInt64(-value) : UInt64(value)
    var i = 31
    repeat {
        scratch[i] = UInt8(ascii: "0") + UInt8(v % 10)
        v /= 10
        i -= 1
    } while v != 0 && i > 0
    if value < 0 { scratch[i] = UInt8(ascii: "-"); i -= 1 }
    craftWriteBytes(fd, UnsafePointer(scratch + i + 1), 31 - i)
}

/// Reads `size` bytes at `address` without faulting on a bad pointer.
@inline(__always)
private func craftSafeRead(_ address: UInt64, _ into: UnsafeMutableRawPointer, _ size: Int) -> Bool {
    var outSize: vm_size_t = 0
    let result = vm_read_overwrite(mach_task_self_, vm_address_t(address), vm_size_t(size), vm_address_t(UInt(bitPattern: into)), &outSize)
    return result == KERN_SUCCESS && outSize == vm_size_t(size)
}

/// The messages iOS's crash reporter would show: a Swift runtime trap writes
/// "Fatal error: Unexpectedly found nil…" into its image's `__crash_info`
/// section before trapping, and that is the only place it survives.
private func craftWriteCrashInfoMessages(_ fd: Int32) {
    guard let sections = craftCrashInfoSections, let scratch = craftCrashScratch else { return }
    // crashreporter_annotations_t: version, message (+8), signature_string,
    // backtrace, message2 (+32). Two plain calls, not a loop over an array
    // literal, which would allocate.
    for index in 0..<Int(craftCrashInfoCount) {
        craftWriteCrashInfoString(fd, sections[index] + 8, scratch)
        craftWriteCrashInfoString(fd, sections[index] + 32, scratch)
    }
}

private func craftWriteCrashInfoString(_ fd: Int32, _ field: UInt64, _ scratch: UnsafeMutablePointer<UInt8>) {
    var pointer: UInt64 = 0
    guard craftSafeRead(field, &pointer, 8), pointer != 0 else { return }
    craftWriteLiteral(fd, "message ")
    // Copied in 32-byte reads so a short string near the end of a page cannot fault.
    var offset: UInt64 = 0
    while offset < 1024 {
        guard craftSafeRead(pointer + offset, scratch, 32) else { break }
        var length = 0
        while length < 32 && scratch[length] != 0 && scratch[length] != 10 { length += 1 }
        craftWriteBytes(fd, scratch, length)
        if length < 32 { break }
        offset += 32
    }
    craftWriteLiteral(fd, "\n")
}

/// Walks the crashed thread's frame-pointer chain from its saved registers.
private func craftCollectFrames(_ context: UnsafeMutableRawPointer?) -> Int {
    guard let frames = craftCrashFrames, let context else { return 0 }
    let uc = context.assumingMemoryBound(to: ucontext_t.self)
    guard let mcontext = uc.pointee.uc_mcontext else { return 0 }
    #if arch(arm64)
    let pc = UInt64(mcontext.pointee.__ss.__pc)
    var fp = UInt64(mcontext.pointee.__ss.__fp)
    let lr = UInt64(mcontext.pointee.__ss.__lr)
    #elseif arch(x86_64)
    let pc = UInt64(mcontext.pointee.__ss.__rip)
    var fp = UInt64(mcontext.pointee.__ss.__rbp)
    let lr: UInt64 = 0
    #else
    return 0
    #endif
    var count = 0
    frames[count] = craftStrip(pc); count += 1
    var record: (UInt64, UInt64) = (0, 0)
    var first = true
    while count < craftCrashMaxFrames, fp != 0, fp & 0x7 == 0 {
        guard craftSafeRead(fp, &record, 16) else { break }
        let returnAddress = craftStrip(record.1)
        // In a leaf function the caller is only in the link register: the
        // first saved return address then belongs to the caller's caller.
        if first, lr != 0, craftStrip(lr) != returnAddress, craftStrip(lr) != frames[0], count < craftCrashMaxFrames {
            frames[count] = craftStrip(lr); count += 1
        }
        first = false
        if returnAddress == 0 { break }
        frames[count] = returnAddress; count += 1
        if record.0 <= fp { break } // stacks grow down; a frame pointer must move up
        fp = record.0
    }
    return count
}

private func craftSignalHandler(_ signal: Int32, _ info: UnsafeMutablePointer<__siginfo>?, _ context: UnsafeMutableRawPointer?) {
    let first = craftCrashInProgress == 0
    craftCrashInProgress = 1
    if first, craftCrashExceptionRecorded == 0, let path = craftCrashPath {
        let fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        if fd >= 0 {
            craftWriteLiteral(fd, "craft-crash 1\nkind signal\nsignal ")
            craftWriteDecimal(fd, Int64(signal))
            craftWriteLiteral(fd, "\ncode ")
            craftWriteDecimal(fd, Int64(info?.pointee.si_code ?? 0))
            craftWriteLiteral(fd, "\naddress ")
            craftWriteHex(fd, UInt64(UInt(bitPattern: info?.pointee.si_addr)))
            craftWriteLiteral(fd, "\ntime ")
            craftWriteDecimal(fd, Int64(time(nil)))
            craftWriteLiteral(fd, "\n")
            craftWriteCrashInfoMessages(fd)
            let count = craftCollectFrames(context)
            if let frames = craftCrashFrames {
                for index in 0..<count {
                    craftWriteLiteral(fd, "frame ")
                    craftWriteHex(fd, frames[index])
                    craftWriteLiteral(fd, "\n")
                }
            }
            close(fd)
        }
    }
    // Hand the signal back to whoever had it before (or the default action),
    // so the process still dies the way iOS expects and MetricKit sees it.
    var restored = false
    if let previous = craftCrashPreviousActions {
        for index in 0..<craftCrashSignalCount where craftCrashSignalAt(index) == signal {
            sigaction(signal, previous + index, nil)
            restored = true
        }
    }
    if !restored { Darwin.signal(signal, SIG_DFL) }
    raise(signal)
}

private func craftUncaughtException(_ exception: NSException) {
    CraftCrashReporter.shared.recordUncaughtException(exception)
    craftPreviousExceptionHandler?(exception)
}

/// A binary loaded in this process, as a crash's frames are mapped to it.
private struct CraftImage: Codable {
    let name: String
    let uuid: String
    let base: UInt64
    let size: UInt64
    let inApp: Bool
}

final class CraftCrashReporter: NSObject, MXMetricManagerSubscriber {
    static let shared = CraftCrashReporter()
    static let sdkName = "bughq.craft.ios"

    private(set) var enabled = false
    private var settings: CraftConfig.CrashReporting?
    private let queue = DispatchQueue(label: "dev.craft.crash-reporter", qos: .utility)
    private var directory: URL!
    private var outbox: URL!
    private var pathMonitor: NWPathMonitor?
    private var online = true
    private var flushing = false
    private var retryAt = Date.distantPast
    private var failures = 0
    private var breadcrumbs: [[String: Any]] = []
    private var breadcrumbsDirty = false
    private var userId: String?
    private var lastJavaScriptError: (key: String, at: Date)?
    private lazy var urlSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    let sessionId = UUID().uuidString.lowercased()
    let sessionStart = Date()
    private let executableName = Bundle.main.executableURL?.lastPathComponent ?? ""
    private let bundlePath = Bundle.main.bundlePath

    var appVersion: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "" }
    var appBuild: String { Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "" }
    var release: String {
        if let given = settings?.release, !given.isEmpty { return given }
        return appBuild.isEmpty ? appVersion : "\(appVersion)+\(appBuild)"
    }
    var environment: String { settings?.environment ?? "production" }

    // MARK: Start

    /// Installs everything. Called first thing in didFinishLaunching, so a
    /// crash during the rest of launch is caught too.
    func start(_ config: CraftConfig) {
        guard !enabled, let settings = config.crashReporting, !settings.key.isEmpty else { return }
        self.settings = settings
        enabled = true
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = support.appendingPathComponent("craft-crash", isDirectory: true)
        outbox = directory.appendingPathComponent("outbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: outbox, withIntermediateDirectories: true)
        userId = UserDefaults.standard.string(forKey: "craft.crash.user")

        installInProcessHandlers()
        queue.async {
            // The previous launch's crash first: its report names images,
            // breadcrumbs and a session that this launch is about to replace.
            self.collectPreviousCrash()
            self.recordSession()
            self.pruneOutbox()
            if settings.sessions != false { self.enqueueSession(status: "ok") }
        }
        MXMetricManager.shared.add(self)
        startNetworkMonitor()
        let center = NotificationCenter.default
        center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self] _ in
            self?.queue.async { self?.flush() }
        }
        center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: nil) { [weak self] _ in
            self?.queue.async { self?.saveBreadcrumbs() }
        }
        #if DEBUG
        scheduleDebugCrashTest()
        #endif
    }

    private func installInProcessHandlers() {
        let path = directory.appendingPathComponent("pending.crash").path
        craftCrashPath = strdup(path)
        craftCrashScratch = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
        craftCrashFrames = UnsafeMutablePointer<UInt64>.allocate(capacity: craftCrashMaxFrames)
        craftCrashInfoSections = UnsafeMutablePointer<UInt64>.allocate(capacity: craftCrashMaxImagesWithCrashInfo)
        craftCrashInfoCount = 0

        // Its own stack, so a stack overflow can still run the handler.
        let stackSize = Int(SIGSTKSZ) * 4
        craftCrashAltStack = UnsafeMutableRawPointer.allocate(byteCount: stackSize, alignment: 16)
        var stack = stack_t(ss_sp: craftCrashAltStack, ss_size: stackSize, ss_flags: 0)
        sigaltstack(&stack, nil)

        let previous = UnsafeMutablePointer<sigaction>.allocate(capacity: craftCrashSignalCount)
        for index in 0..<craftCrashSignalCount {
            let signal = craftCrashSignalAt(index)
            var action = sigaction()
            action.__sigaction_u.__sa_sigaction = craftSignalHandler
            action.sa_flags = SA_SIGINFO | SA_ONSTACK
            sigemptyset(&action.sa_mask)
            sigaction(signal, &action, previous + index)
        }
        craftCrashPreviousActions = previous

        craftPreviousExceptionHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler(craftUncaughtException)
    }

    /// Called on the crashing thread for an uncaught Objective-C exception,
    /// before abort(). The process is still sane, so this may allocate; it
    /// writes the same report file the signal handler would, and tells the
    /// handler (which abort() reaches next) that the crash is recorded.
    func recordUncaughtException(_ exception: NSException) {
        guard enabled, craftCrashPath != nil else { return }
        var lines = ["craft-crash 1", "kind nsexception", "signal \(SIGABRT)", "time \(Int(Date().timeIntervalSince1970))"]
        lines.append("exception \(exception.name.rawValue)")
        if let reason = exception.reason {
            lines.append("message \(reason.replacingOccurrences(of: "\n", with: " ").prefix(1024))")
        }
        for address in exception.callStackReturnAddresses.prefix(craftCrashMaxFrames) {
            lines.append("frame 0x\(String(craftStrip(address.uint64Value), radix: 16))")
        }
        try? (lines.joined(separator: "\n") + "\n").write(toFile: directory.appendingPathComponent("pending.crash").path, atomically: false, encoding: .utf8)
        craftCrashExceptionRecorded = 1
    }

    // MARK: Session

    /// This launch's facts the next launch needs to read a crash: the loaded
    /// images (their addresses change every launch) and the session's release.
    private func recordSession() {
        var images: [CraftImage] = []
        var sections = 0
        for index in 0..<_dyld_image_count() {
            guard let header = _dyld_get_image_header(index), let rawName = _dyld_get_image_name(index) else { continue }
            let path = String(cString: rawName)
            let info = Self.imageInfo(header)
            images.append(CraftImage(
                name: (path as NSString).lastPathComponent,
                uuid: info.uuid,
                base: UInt64(UInt(bitPattern: header)),
                size: info.textSize,
                inApp: path.hasPrefix(bundlePath)
            ))
            var size: UInt = 0
            let header64 = UnsafeRawPointer(header).assumingMemoryBound(to: mach_header_64.self)
            if sections < craftCrashMaxImagesWithCrashInfo,
               let section = getsectiondata(header64, "__DATA", "__crash_info", &size), size >= 40 {
                craftCrashInfoSections?[sections] = UInt64(UInt(bitPattern: section))
                sections += 1
                craftCrashInfoCount = Int32(sections)
            }
        }
        let info: [String: Any] = [
            "id": sessionId,
            "startedAt": Self.iso(sessionStart),
            "release": release,
            "version": appVersion,
            "build": appBuild,
            "environment": environment,
        ]
        write(info, to: "session.json")
        if let data = try? JSONEncoder().encode(images) {
            try? data.write(to: directory.appendingPathComponent("images.json"), options: .atomic)
        }
        breadcrumbs = []
        breadcrumbsDirty = true
        saveBreadcrumbs()
    }

    private static func imageInfo(_ header: UnsafePointer<mach_header>) -> (uuid: String, textSize: UInt64) {
        var uuid = ""
        var textSize: UInt64 = 0
        let is64 = header.pointee.magic == MH_MAGIC_64
        var cursor = UnsafeRawPointer(header) + (is64 ? MemoryLayout<mach_header_64>.size : MemoryLayout<mach_header>.size)
        for _ in 0..<header.pointee.ncmds {
            let command = cursor.assumingMemoryBound(to: load_command.self).pointee
            if command.cmd == LC_UUID {
                let bytes = cursor.assumingMemoryBound(to: uuid_command.self).pointee.uuid
                uuid = UUID(uuid: bytes).uuidString
            } else if command.cmd == LC_SEGMENT_64 {
                let segment = cursor.assumingMemoryBound(to: segment_command_64.self).pointee
                let name = withUnsafeBytes(of: segment.segname) { String(decoding: $0.prefix(while: { $0 != 0 }), as: UTF8.self) }
                if name == "__TEXT" { textSize = segment.vmsize }
            }
            cursor += Int(command.cmdsize)
        }
        return (uuid, textSize)
    }

    // MARK: The previous launch's crash

    private func collectPreviousCrash() {
        let reportURL = directory.appendingPathComponent("pending.crash")
        guard let text = try? String(contentsOf: reportURL, encoding: .utf8) else { return }
        try? FileManager.default.removeItem(at: reportURL)
        let previousSession = read("session.json") ?? [:]
        let previousCrumbs = (try? JSONSerialization.jsonObject(with: Data(contentsOf: directory.appendingPathComponent("breadcrumbs.json")))) as? [[String: Any]] ?? []
        let images = (try? JSONDecoder().decode([CraftImage].self, from: Data(contentsOf: directory.appendingPathComponent("images.json")))) ?? []

        var signal: Int32 = 0
        var code = 0
        var faultAddress = ""
        var kind = "signal"
        var exceptionName: String?
        var messages: [String] = []
        var addresses: [UInt64] = []
        var crashedAt = Date()
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            switch parts[0] {
            case "kind": kind = parts[1]
            case "signal": signal = Int32(parts[1]) ?? 0
            case "code": code = Int(parts[1]) ?? 0
            case "address": faultAddress = parts[1]
            case "time": crashedAt = Date(timeIntervalSince1970: TimeInterval(parts[1]) ?? Date().timeIntervalSince1970)
            case "exception": exceptionName = parts[1]
            case "message": if !parts[1].isEmpty { messages.append(parts[1]) }
            case "frame": if let value = UInt64(parts[1].dropFirst(2), radix: 16) { addresses.append(value) }
            default: break
            }
        }
        let frames = addresses.map { frame(for: $0, in: images) }
        let signalName = Self.signalName(signal)
        let type = exceptionName ?? signalName
        // A runtime's own words when it trapped on purpose (Swift's "Fatal
        // error: …", an assertion); an abort's first annotation otherwise.
        // Never the simulator's device banner, which some image's
        // __crash_info carries on every simulator process.
        let deliberate = messages.first(where: { $0.localizedCaseInsensitiveContains("fatal error") || $0.contains("Assertion failed") || $0.contains("Precondition failed") })
        let annotation = signal == SIGABRT ? messages.first(where: { !$0.hasPrefix("CoreSimulator") }) : nil
        var message: String = deliberate ?? annotation ?? ""
        if message.isEmpty {
            message = Self.signalDescription(signal, code: code, address: faultAddress)
        }
        var exception: [String: Any] = [
            "mechanism": kind == "nsexception" ? "nsexception" : "signal",
            "handled": false,
            "signal": signalName,
            "frames": frames,
        ]
        if kind == "signal", !faultAddress.isEmpty { exception["code"] = "\(Self.signalCodeName(signal, code)) at \(faultAddress)" }
        let release = previousSession["release"] as? String ?? self.release
        var event = baseEvent(release: release, sessionId: previousSession["id"] as? String, sessionStart: previousSession["startedAt"] as? String)
        event["type"] = type
        event["message"] = message
        event["level"] = "fatal"
        event["timestamp"] = Self.iso(crashedAt)
        event["exception"] = exception
        event["breadcrumbs"] = Array(previousCrumbs.suffix(50))
        let mechanism: String = exception["mechanism"] as? String ?? "signal"
        event["tags"] = ["mechanism": mechanism]
        if let version = previousSession["version"] as? String, let build = previousSession["build"] as? String {
            var contexts = event["contexts"] as? [String: Any] ?? [:]
            var app = contexts["app"] as? [String: Any] ?? [:]
            app["version"] = version
            app["build"] = build
            contexts["app"] = app
            event["contexts"] = contexts
        }
        rememberCrashSignature(frames: frames, release: release)
        enqueue("errors", event)
    }

    private func frame(for address: UInt64, in images: [CraftImage]) -> [String: Any] {
        var frame: [String: Any] = ["instruction_addr": "0x\(String(address, radix: 16))"]
        if let image = images.first(where: { address >= $0.base && address < $0.base + max($0.size, 1) }) {
            frame["image"] = image.name
            frame["image_uuid"] = image.uuid
            frame["image_offset"] = address - image.base
            frame["in_app"] = image.inApp
        } else {
            frame["in_app"] = false
        }
        return frame
    }

    // MARK: MetricKit

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        queue.async {
            for payload in payloads {
                for crash in payload.crashDiagnostics ?? [] { self.handleMetricKit(crash.jsonRepresentation(), hang: false) }
                for hang in payload.hangDiagnostics ?? [] { self.handleMetricKit(hang.jsonRepresentation(), hang: true) }
            }
        }
    }

    /// One MetricKit diagnostic, from its JSON form (the same shape on every
    /// iOS version, and testable from a recorded payload).
    func handleMetricKit(_ json: Data, hang: Bool) {
        guard let diagnostic = (try? JSONSerialization.jsonObject(with: json)) as? [String: Any] else { return }
        let meta = diagnostic["diagnosticMetaData"] as? [String: Any] ?? [:]
        let tree = diagnostic["callStackTree"] as? [String: Any] ?? [:]
        let stacks = tree["callStacks"] as? [[String: Any]] ?? []
        let attributed = stacks.first(where: { $0["threadAttributed"] as? Bool == true }) ?? stacks.first
        var frames: [[String: Any]] = []
        var node = (attributed?["callStackRootFrames"] as? [[String: Any]])?.first
        while let current = node, frames.count < craftCrashMaxFrames {
            let name = current["binaryName"] as? String ?? "???"
            var frame: [String: Any] = [
                "image": name,
                "in_app": name == executableName || bundledFrameworkNames.contains(name),
            ]
            if let uuid = current["binaryUUID"] as? String { frame["image_uuid"] = uuid }
            if let offset = (current["offsetIntoBinaryTextSegment"] as? NSNumber)?.uint64Value { frame["image_offset"] = offset }
            if let address = (current["address"] as? NSNumber)?.uint64Value { frame["instruction_addr"] = "0x\(String(address, radix: 16))" }
            frames.append(frame)
            node = (current["subFrames"] as? [[String: Any]])?.first
        }
        guard !frames.isEmpty else { return }
        let version = meta["appVersion"] as? String ?? appVersion
        let build = meta["appBuildVersion"] as? String ?? appBuild
        let release = settings?.release.flatMap { $0.isEmpty ? nil : $0 } ?? (build.isEmpty ? version : "\(version)+\(build)")

        var event = baseEvent(release: release, sessionId: nil, sessionStart: nil)
        var contexts = event["contexts"] as? [String: Any] ?? [:]
        var app = contexts["app"] as? [String: Any] ?? [:]
        app["version"] = version
        app["build"] = build
        contexts["app"] = app
        if let device = meta["deviceType"] as? String {
            var deviceContext = contexts["device"] as? [String: Any] ?? [:]
            deviceContext["model"] = device
            contexts["device"] = deviceContext
        }
        if let os = meta["osVersion"] as? String {
            contexts["os"] = ["name": "iOS", "version": os]
            event["os"] = os.replacingOccurrences(of: "iPhone OS", with: "iOS")
        }
        event["contexts"] = contexts
        event["tags"] = ["mechanism": hang ? "metrickit-hang" : "metrickit"]

        if hang {
            let duration = meta["hangDuration"] as? String ?? ""
            event["type"] = "AppHang"
            event["message"] = duration.isEmpty ? "The app stopped responding" : "The app stopped responding for \(duration)"
            event["level"] = "error"
            event["exception"] = ["mechanism": "hang", "handled": true, "frames": frames]
        } else {
            if isKnownCrash(frames: frames, release: release) { return }
            let signal = (meta["signal"] as? NSNumber)?.int32Value ?? 0
            let reason = (diagnostic["objectiveCexceptionReason"] ?? meta["objectiveCexceptionReason"]) as? [String: Any]
            let exceptionName = reason?["exceptionName"] as? String
            event["type"] = exceptionName ?? Self.signalName(signal)
            event["message"] = (reason?["composedMessage"] as? String)
                ?? (meta["terminationReason"] as? String)
                ?? Self.signalDescription(signal, code: 0, address: "")
            event["level"] = "fatal"
            var exception: [String: Any] = ["mechanism": "metrickit", "handled": false, "signal": Self.signalName(signal), "frames": frames]
            if let type = (meta["exceptionType"] as? NSNumber)?.intValue { exception["code"] = Self.machExceptionName(type) }
            event["exception"] = exception
        }
        enqueue("errors", event)
    }

    private lazy var bundledFrameworkNames: Set<String> = {
        let frameworks = Bundle.main.privateFrameworksURL
        let names = (try? FileManager.default.contentsOfDirectory(atPath: frameworks?.path ?? "")) ?? []
        return Set(names.map { ($0 as NSString).deletingPathExtension })
    }()

    // A crash the in-process handler already reported (same release, same top
    // in-app frames) is not sent again when MetricKit delivers its copy.
    private func signature(frames: [[String: Any]], release: String) -> String? {
        let top = frames.filter { $0["in_app"] as? Bool == true }.prefix(4).compactMap { frame -> String? in
            guard let uuid = frame["image_uuid"] as? String, let offset = frame["image_offset"] as? UInt64 else { return nil }
            return "\(uuid.uppercased())+\(offset)"
        }
        return top.isEmpty ? nil : "\(release)|\(top.joined(separator: ","))"
    }

    private func rememberCrashSignature(frames: [[String: Any]], release: String) {
        guard let signature = signature(frames: frames, release: release) else { return }
        var known = UserDefaults.standard.dictionary(forKey: "craft.crash.signatures") as? [String: Double] ?? [:]
        let cutoff = Date().addingTimeInterval(-14 * 86_400).timeIntervalSince1970
        known = known.filter { $0.value > cutoff }
        known[signature] = Date().timeIntervalSince1970
        UserDefaults.standard.set(known, forKey: "craft.crash.signatures")
    }

    private func isKnownCrash(frames: [[String: Any]], release: String) -> Bool {
        guard let signature = signature(frames: frames, release: release) else { return false }
        let known = UserDefaults.standard.dictionary(forKey: "craft.crash.signatures") as? [String: Double] ?? [:]
        return known[signature] != nil
    }

    // MARK: JavaScript

    /// An uncaught exception in a native screen or the app script. The screen
    /// keeps running (or falls back to the web page), so this is an error, not
    /// a crash.
    func captureJavaScript(name: String?, message: String, stack: String, route: String, isAppScript: Bool) {
        guard enabled else { return }
        queue.async {
            let key = "\(name ?? "")|\(message)|\(stack.prefix(200))"
            if let last = self.lastJavaScriptError, last.key == key, Date().timeIntervalSince(last.at) < 5 { return }
            self.lastJavaScriptError = (key, Date())
            var event = self.baseEvent(release: self.release, sessionId: self.sessionId, sessionStart: Self.iso(self.sessionStart))
            let type: String = name.flatMap { $0.isEmpty ? nil : $0 } ?? "Error"
            event["type"] = type
            event["message"] = message
            if !stack.isEmpty, stack != "undefined" { event["stack"] = stack }
            event["level"] = "error"
            event["url"] = "app://\(route)"
            event["breadcrumbs"] = Array(self.breadcrumbs.suffix(50))
            event["tags"] = ["mechanism": "jsc", "runtime": isAppScript ? "app-script" : "screen", "route": route]
            event["framework"] = "stx-native"
            self.enqueue("errors", event)
        }
    }

    /// An event the page or a screen built (with @bughq/sdk) and handed over,
    /// so it shares the outbox, the session and the device context.
    func capture(_ given: [String: Any]) {
        guard enabled else { return }
        queue.async {
            var event = self.baseEvent(release: self.release, sessionId: self.sessionId, sessionStart: Self.iso(self.sessionStart))
            for (key, value) in given where !(value is NSNull) {
                switch key {
                case "key", "project", "session", "release", "environment", "os", "platform": continue
                case "contexts":
                    // The device's own facts win over what a web view guesses.
                    var contexts = value as? [String: Any] ?? [:]
                    for (name, context) in event["contexts"] as? [String: Any] ?? [:] { contexts[name] = context }
                    event["contexts"] = contexts
                case "user":
                    if self.userId == nil { event["user"] = value }
                default:
                    event[key] = value
                }
            }
            if event["type"] == nil { event["type"] = "Error" }
            if event["message"] == nil { return }
            self.enqueue("errors", event)
        }
    }

    /// Send what is queued now (the page asked, e.g. before a sign-out).
    func requestFlush() {
        guard enabled else { return }
        queue.async { self.flush() }
    }

    func setUser(_ id: String?) {
        let value = id.flatMap { $0.isEmpty ? nil : String($0.prefix(128)) }
        userId = value
        UserDefaults.standard.set(value, forKey: "craft.crash.user")
    }

    func addBreadcrumb(_ crumb: [String: Any]) {
        guard enabled else { return }
        queue.async {
            var crumb = crumb
            if crumb["timestamp"] == nil { crumb["timestamp"] = Self.iso(Date()) }
            if let message = crumb["message"] as? String, message.count > 300 { crumb["message"] = String(message.prefix(300)) }
            self.breadcrumbs.append(crumb)
            if self.breadcrumbs.count > 100 { self.breadcrumbs.removeFirst(self.breadcrumbs.count - 100) }
            // Kept on disk, so a crash's report carries the trail that led to it.
            if !self.breadcrumbsDirty {
                self.breadcrumbsDirty = true
                self.queue.asyncAfter(deadline: .now() + 1) { self.saveBreadcrumbs() }
            }
        }
    }

    /// A screen came on screen.
    func screenAppeared(_ route: String) {
        addBreadcrumb(["type": "navigation", "category": "navigation", "message": route, "data": ["to": route]])
    }

    /// A request a native screen made failed or was refused.
    func requestFailed(method: String, url: URL, status: Int?, error: String?) {
        var data: [String: Any] = ["method": method, "url": Self.maskURL(url)]
        if let status { data["status"] = status }
        if let error { data["error"] = error }
        addBreadcrumb(["type": "http", "category": "fetch", "level": status.map { $0 >= 500 ? "error" : "warning" } ?? "error", "data": data])
    }

    /// The path with ids templated and no query string: which call failed, not
    /// whose data it carried.
    static func maskURL(_ url: URL) -> String {
        let path = url.path.split(separator: "/", omittingEmptySubsequences: false).map { segment -> String in
            let s = String(segment)
            if s.isEmpty { return s }
            if s.allSatisfy(\.isNumber) { return "{n}" }
            if s.count >= 4, s.contains(where: \.isLetter), s.contains(where: \.isNumber) { return "{id}" }
            return s
        }.joined(separator: "/")
        return "\(url.host ?? "")\(path)\(url.query == nil ? "" : "?…")"
    }

    private func saveBreadcrumbs() {
        guard breadcrumbsDirty, let directory else { return }
        breadcrumbsDirty = false
        if let data = try? JSONSerialization.data(withJSONObject: breadcrumbs) {
            try? data.write(to: directory.appendingPathComponent("breadcrumbs.json"), options: .atomic)
        }
    }

    /// What JavaScript is told about the reporter and the device.
    func context() -> [String: Any] {
        var info = baseEvent(release: release, sessionId: sessionId, sessionStart: Self.iso(sessionStart))
        info["enabled"] = enabled
        info.removeValue(forKey: "key")
        return info
    }

    // MARK: Events

    private func baseEvent(release: String, sessionId: String?, sessionStart: String?) -> [String: Any] {
        let device = UIDevice.current
        let info = Bundle.main.infoDictionary
        let appName: String = info?["CFBundleDisplayName"] as? String ?? info?["CFBundleName"] as? String ?? ""
        // Typed, not inline: against `Any`, `Locale.current.identifier` picks
        // iOS 16's `identifier(_:)` method and stores a function.
        let locale: String = Locale.current.identifier
        var event: [String: Any] = [
            "platform": "ios",
            "release": release,
            "environment": environment,
            "os": "iOS \(device.systemVersion)",
            "framework": "craft",
            "timestamp": Self.iso(Date()),
            "sdk": ["name": Self.sdkName, "version": craftVersion],
            "contexts": [
                "app": [
                    "id": Bundle.main.bundleIdentifier ?? "",
                    "name": appName,
                    "version": appVersion,
                    "build": appBuild,
                ],
                "device": [
                    "model": Self.deviceModel(),
                    "family": device.model,
                    "simulator": Self.isSimulator,
                    "locale": locale,
                ],
                "os": ["name": "iOS", "version": device.systemVersion],
            ],
        ]
        if let sessionId { event["session"] = ["id": sessionId, "startedAt": sessionStart ?? Self.iso(self.sessionStart)] }
        if let userId { event["user"] = ["id": userId] }
        return event
    }

    private var craftVersion: String { "{{CRAFT_VERSION}}" }

    private func enqueue(_ endpoint: String, _ body: [String: Any]) {
        // Through jsonSafe first: a `[String: Any]` built in Swift can hold an
        // Optional (a `??` inferred against `Any`), and a page's event can hold
        // anything at all. Either made the whole event invalid JSON, and it was
        // dropped without a word.
        let item: [String: Any] = ["endpoint": endpoint, "body": Self.jsonSafe(body)]
        guard let outbox, JSONSerialization.isValidJSONObject(item),
              let data = try? JSONSerialization.data(withJSONObject: item) else {
            CraftNativeConsole.write("error", category: "crash-reporter", message: "dropped an \(endpoint) event that is not JSON")
            return
        }
        let name = String(format: "%013.0f-%@.json", Date().timeIntervalSince1970 * 1000, UUID().uuidString)
        try? data.write(to: outbox.appendingPathComponent(name), options: .atomic)
        flush()
    }

    private func enqueueSession(status: String) {
        var session: [String: Any] = [
            "id": sessionId,
            "release": release,
            "environment": environment,
            "platform": "ios",
            "status": status,
            "started_at": Self.iso(sessionStart),
        ]
        if let userId { session["user_id"] = userId }
        enqueue("sessions", ["sessions": [session]])
    }

    /// At most 200 queued items and none older than 14 days: a phone that is
    /// offline for a month sends its recent history, not everything.
    private func pruneOutbox() {
        guard let outbox else { return }
        let files = ((try? FileManager.default.contentsOfDirectory(atPath: outbox.path)) ?? []).filter { $0.hasSuffix(".json") }.sorted()
        let cutoff = (Date().timeIntervalSince1970 - 14 * 86_400) * 1000
        for (index, name) in files.enumerated() {
            let stamp = Double(name.prefix(13)) ?? 0
            if index < files.count - 200 || stamp < cutoff {
                try? FileManager.default.removeItem(at: outbox.appendingPathComponent(name))
            }
        }
    }

    // MARK: Delivery

    private func startNetworkMonitor() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            self.queue.async {
                let wasOnline = self.online
                self.online = path.status == .satisfied
                if self.online && !wasOnline {
                    // Back online: whatever waited goes now.
                    self.retryAt = .distantPast
                    self.failures = 0
                    self.flush()
                }
            }
        }
        monitor.start(queue: queue)
        pathMonitor = monitor
    }

    /// Sends the outbox, oldest first, one at a time. Runs on `queue`.
    func flush() {
        guard enabled, !flushing, online, Date() >= retryAt, let outbox, let settings else { return }
        let files = ((try? FileManager.default.contentsOfDirectory(atPath: outbox.path)) ?? []).filter { $0.hasSuffix(".json") }.sorted()
        guard let next = files.first else { return }
        let fileURL = outbox.appendingPathComponent(next)
        guard let data = try? Data(contentsOf: fileURL),
              let item = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let endpoint = item["endpoint"] as? String, var body = item["body"] as? [String: Any] else {
            try? FileManager.default.removeItem(at: fileURL)
            flush()
            return
        }
        body["key"] = settings.key
        let host = (settings.host?.isEmpty == false ? settings.host! : "https://bughq.org").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(host)/\(endpoint == "sessions" ? "sessions" : "errors")"),
              let payload = try? JSONSerialization.data(withJSONObject: body) else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(settings.key, forHTTPHeaderField: "X-BugHQ-Key")
        request.httpBody = payload
        flushing = true
        urlSession.dataTask(with: request) { [weak self] _, response, error in
            guard let self else { return }
            self.queue.async {
                self.flushing = false
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                if error == nil, (200..<300).contains(status) || ((400..<500).contains(status) && status != 408 && status != 429) {
                    // Delivered, or refused for good (a 4xx will not change on retry).
                    try? FileManager.default.removeItem(at: fileURL)
                    self.failures = 0
                    self.flush()
                } else {
                    // Offline, rate limited or the server is down: back off and keep it.
                    self.failures += 1
                    let delay = min(3600, 15 * pow(2, Double(min(self.failures, 8))))
                    self.retryAt = Date().addingTimeInterval(delay)
                    self.queue.asyncAfter(deadline: .now() + delay) { self.flush() }
                }
            }
        }.resume()
    }

    // MARK: Helpers

    /// `value` as something JSONSerialization accepts: Optionals unwrapped
    /// (nil is null), integers of every width as numbers, dates as ISO
    /// strings, and anything else as its description.
    static func jsonSafe(_ value: Any) -> Any {
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            guard let wrapped = mirror.children.first?.value else { return NSNull() }
            return jsonSafe(wrapped)
        }
        switch value {
        case let dictionary as [String: Any]:
            return dictionary.mapValues { jsonSafe($0) }
        case let dictionary as NSDictionary:
            var out: [String: Any] = [:]
            for (key, item) in dictionary { out[String(describing: key)] = jsonSafe(item) }
            return out
        case let array as [Any]:
            return array.map { jsonSafe($0) }
        case is String, is NSString, is NSNull:
            return value
        case let flag as Bool:
            return flag
        case let number as NSNumber:
            return number
        case let number as UInt64:
            return NSNumber(value: number)
        case let number as Int64:
            return NSNumber(value: number)
        case let number as UInt32:
            return NSNumber(value: number)
        case let number as Int32:
            return NSNumber(value: number)
        case let number as Double:
            return number.isFinite ? NSNumber(value: number) : NSNull()
        case let date as Date:
            return iso(date)
        case let url as URL:
            return url.absoluteString
        default:
            return String(describing: value)
        }
    }

    private func write(_ object: [String: Any], to name: String) {
        if let data = try? JSONSerialization.data(withJSONObject: object) {
            try? data.write(to: directory.appendingPathComponent(name), options: .atomic)
        }
    }

    private func read(_ name: String) -> [String: Any]? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(name)) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    static func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    /// `iPhone17,1`, not `iPhone`.
    static func deviceModel() -> String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return simulated }
        var system = utsname()
        uname(&system)
        return withUnsafeBytes(of: system.machine) { String(decoding: $0.prefix(while: { $0 != 0 }), as: UTF8.self) }
    }

    static func signalName(_ signal: Int32) -> String {
        switch signal {
        case SIGABRT: return "SIGABRT"
        case SIGBUS: return "SIGBUS"
        case SIGFPE: return "SIGFPE"
        case SIGILL: return "SIGILL"
        case SIGSEGV: return "SIGSEGV"
        case SIGTRAP: return "SIGTRAP"
        case SIGSYS: return "SIGSYS"
        case SIGKILL: return "SIGKILL"
        case 0: return "Crash"
        default: return "Signal \(signal)"
        }
    }

    static func signalCodeName(_ signal: Int32, _ code: Int) -> String {
        switch (signal, Int32(code)) {
        case (SIGSEGV, SEGV_MAPERR): return "SEGV_MAPERR"
        case (SIGSEGV, SEGV_ACCERR): return "SEGV_ACCERR"
        case (SIGBUS, BUS_ADRALN): return "BUS_ADRALN"
        case (SIGBUS, BUS_ADRERR): return "BUS_ADRERR"
        case (SIGFPE, FPE_INTDIV): return "FPE_INTDIV"
        case (SIGILL, ILL_ILLOPC): return "ILL_ILLOPC"
        default: return "code \(code)"
        }
    }

    static func signalDescription(_ signal: Int32, code: Int, address: String) -> String {
        switch signal {
        case SIGSEGV, SIGBUS: return address.isEmpty ? "Bad memory access" : "Bad memory access at \(address)"
        case SIGTRAP: return "The app stopped at a runtime trap"
        case SIGABRT: return "The app aborted"
        case SIGILL: return "Illegal instruction"
        case SIGFPE: return "Arithmetic error"
        case SIGKILL: return "The app was killed"
        default: return "The app crashed with \(signalName(signal))"
        }
    }

    static func machExceptionName(_ type: Int) -> String {
        switch type {
        case 1: return "EXC_BAD_ACCESS"
        case 2: return "EXC_BAD_INSTRUCTION"
        case 3: return "EXC_ARITHMETIC"
        case 6: return "EXC_BREAKPOINT"
        case 10: return "EXC_CRASH"
        case 11: return "EXC_RESOURCE"
        case 12: return "EXC_GUARD"
        default: return "EXC_\(type)"
        }
    }

    // MARK: Debug-only test crash

    #if DEBUG
    /// `-CraftCrashTest swift|signal|exception|js` as a launch argument (e.g.
    /// `xcrun simctl launch <device> <bundle id> -CraftCrashTest swift`)
    /// crashes the app, or throws in the app script, a few seconds after
    /// launch, to check the whole pipeline. Compiled into Debug builds only:
    /// a Release build has no code here and no way to reach it.
    private func scheduleDebugCrashTest() {
        guard let kind = UserDefaults.standard.string(forKey: "CraftCrashTest") else { return }
        NSLog("[craft crash] test %@ scheduled", kind)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            self.addBreadcrumb(["type": "debug", "category": "crash-test", "message": "Crash test: \(kind)"])
            self.queue.sync { self.saveBreadcrumbs() }
            switch kind {
            case "signal":
                let pointer = UnsafeMutablePointer<Int>(bitPattern: 0x10)!
                pointer.pointee = 1
            case "exception":
                _ = NSArray().object(at: 4)
            case "js":
                CraftHybrid.shared.debugThrowInAppScript("Craft crash reporter test error")
            default:
                let missing: [String: Int] = [:]
                _ = missing["crash-test"]!
            }
        }
    }
    #endif
}
