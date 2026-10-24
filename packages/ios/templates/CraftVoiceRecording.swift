import AVFoundation
import Foundation
import UIKit

/// One owner at a time, including the asynchronous permission prompt. A late
/// permission answer cannot start recording after its screen/account left.
final class CraftVoiceRecording {
    static let shared = CraftVoiceRecording()
    private var owner: String?
    private var recorder: AVAudioRecorder?
    private var file: URL?
    private var backgroundObserver: NSObjectProtocol?

    private init() {
        backgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in self?.clear() }
    }

    private func clear() {
        owner = nil
        recorder?.stop()
        recorder = nil
        if let file { CraftNativeFiles.remove(file.path) }
        file = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func perform(method: String, args: [Any], completion: @escaping (Result<Any, CraftNativeActionError>) -> Void) {
        DispatchQueue.main.async { self.performOnMain(method: method, args: args, completion: completion) }
    }

    private func performOnMain(method: String, args: [Any], completion: @escaping (Result<Any, CraftNativeActionError>) -> Void) {
        func fail(_ code: String, _ message: String) { completion(.failure(CraftNativeActionError(code: code, message: message))) }
        guard let key = args.first as? String, UUID(uuidString: key) != nil else { fail("INVALID_ARGUMENT", "A recording owner UUID is required"); return }
        if method == "cancel" {
            if owner == key { clear() }
            completion(.success(true))
            return
        }
        if method == "stop" {
            guard owner == key, let file else { fail("RECORDING_NOT_FOUND", "This recording is no longer available"); return }
            recorder?.stop()
            recorder = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            guard let audio = try? AVAudioFile(forReading: file), audio.length > 0 else { clear(); fail("EMPTY_RECORDING", "The recording was empty"); return }
            let duration = Double(audio.length) / audio.processingFormat.sampleRate
            completion(.success(CraftNativeFiles.describe(file, type: "audio/mp4", extra: ["durationSeconds": duration])))
            return
        }
        guard method == "start" else { fail("UNKNOWN_ACTION", "Unknown voice recording action"); return }
        guard owner == nil else { fail("RECORDING_BUSY", "Another microphone session is still active"); return }
        let options = args.count > 1 ? args[1] as? [String: Any] ?? [:] : [:]
        let seconds = (options["maxSeconds"] as? NSNumber)?.doubleValue ?? 300
        guard seconds.isFinite, seconds >= 1, seconds <= 300 else { fail("INVALID_ARGUMENT", "Recordings are limited to five minutes"); return }
        owner = key
        AVAudioSession.sharedInstance().requestRecordPermission { allowed in
            DispatchQueue.main.async {
                guard self.owner == key else { fail("RECORDING_CANCELLED", "Recording was cancelled"); return }
                guard allowed else { self.clear(); fail("PERMISSION_DENIED", "Microphone permission was refused"); return }
                do {
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.record, mode: .measurement)
                    try session.setActive(true)
                    let file = try CraftNativeFiles.newFile(named: "voice-feedback.m4a")
                    self.file = file
                    let recorder = try AVAudioRecorder(url: file, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 16000, AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 32000])
                    self.recorder = recorder
                    guard recorder.record(forDuration: max(0.5, seconds - 0.25)) else { throw CraftNativeActionError(code: "RECORDING_FAILED", message: "The microphone could not start") }
                    completion(.success(true))
                }
                catch { self.clear(); fail("RECORDING_FAILED", "The microphone could not start") }
            }
        }
    }
}
