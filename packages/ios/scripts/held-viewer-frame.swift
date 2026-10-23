// Public-only extraction of an actual recorded frame during a synthesized hold.
// Encoding finishes later; capture timing comes from decoded PTS and both bounds
// on the recording's first frame, never the process launch timestamp alone.
import Foundation
import AVFoundation
import CoreVideo
import CryptoKit
import ImageIO
import UniformTypeIdentifiers

enum FrameFailure: Error, CustomStringConvertible {
    case invalid(String)
    var description: String { switch self { case .invalid(let message): return message } }
}

func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw FrameFailure.invalid(message) }
}

func digest(_ path: String) throws -> String {
    let file = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
    defer { try? file.close() }
    var hash = SHA256()
    while let bytes = try file.read(upToCount: 1_048_576), !bytes.isEmpty { hash.update(data: bytes) }
    return hash.finalize().map { String(format: "%02x", $0) }.joined()
}

func timeData(_ time: CMTime) throws -> [String: Any] {
    try require(time.isNumeric && time.timescale > 0 && CMTimeGetSeconds(time).isFinite,
                "Decoded frame has an invalid media timestamp")
    try require(time.value >= -9_007_199_254_740_991 && time.value <= 9_007_199_254_740_991,
                "Decoded media timestamp exceeds the exact JSON integer range")
    return ["value": time.value, "timescale": time.timescale]
}

func decodedReader(_ asset: AVAsset, _ track: AVAssetTrack, range: CMTimeRange? = nil) throws -> (AVAssetReader, AVAssetReaderTrackOutput) {
    let reader = try AVAssetReader(asset: asset)
    if let range { reader.timeRange = range }
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
    output.alwaysCopiesSampleData = false
    try require(reader.canAdd(output), "Cannot decode the recorded video track")
    reader.add(output)
    try require(reader.startReading(), "AVFoundation could not start decoding the recording")
    return (reader, output)
}

let arguments = CommandLine.arguments
guard arguments.count == 8 else {
    fputs("Expected movie, PNG, receipt, recordSpawnWall, recordingStartedObservedWall, synthesisWall, releasedWall\n", stderr)
    exit(2)
}
let movie = arguments[1], png = arguments[2], receiptPath = arguments[3]
var receipt: [String: Any] = ["verified": false, "movie": movie, "png": png,
                             "extractStartedWall": Date().timeIntervalSince1970,
                             "timingRule": "Both first-frame wall bounds plus actual decoded PTS offset must be strictly inside Synthesize to END."]
do {
    try require([movie, png, receiptPath].allSatisfy { ($0 as NSString).isAbsolutePath }, "Evidence paths must be absolute")
    try require(!FileManager.default.fileExists(atPath: png) && !FileManager.default.fileExists(atPath: receiptPath), "Refusing to overwrite retained frame evidence")
    let values = arguments[4...7].compactMap(Double.init)
    try require(values.count == 4 && values.allSatisfy { $0.isFinite && $0 > 0 }, "Invalid recording or hold wall clocks")
    let spawn = values[0], ready = values[1], synthesis = values[2], end = values[3]
    receipt.merge(["recordSpawnWall": spawn, "recordingStartedObservedWall": ready, "synthesisWall": synthesis, "releasedWall": end]) { _, next in next }
    try require(spawn <= ready && ready <= synthesis && end - synthesis >= 5.5,
                "Recording must acknowledge its first frame before the six-second synthesized hold")
    receipt["movieSha256"] = try digest(movie)
    let asset = AVURLAsset(url: URL(fileURLWithPath: movie))
    let tracks = try await asset.loadTracks(withMediaType: .video)
    guard let track = tracks.first else { throw FrameFailure.invalid("Recording has no video track") }
    let (originReader, originOutput) = try decodedReader(asset, track)
    guard let originSample = originOutput.copyNextSampleBuffer() else { throw FrameFailure.invalid("Recording has no decoded video frame") }
    let firstPTS = CMSampleBufferGetPresentationTimeStamp(originSample)
    receipt["firstPTS"] = try timeData(firstPTS)
    originReader.cancelReading()
    let firstSeconds = CMTimeGetSeconds(firstPTS)
    // Only this media interval can possibly qualify. Decoding it, rather than
    // a whole long core-suite movie, preserves the actual frame requirement.
    let lowerOffset = max(0, synthesis - spawn)
    let upperOffset = end - ready
    try require(upperOffset > lowerOffset, "First-frame wall uncertainty leaves no qualifying hold interval")
    let range = CMTimeRange(start: CMTimeAdd(firstPTS, CMTime(seconds: lowerOffset, preferredTimescale: 1_000_000_000)),
                            duration: CMTime(seconds: upperOffset - lowerOffset, preferredTimescale: 1_000_000_000))
    let (reader, output) = try decodedReader(asset, track, range: range)
    var decoded: [[String: Any]] = []
    var selected: CMTime?
    var closest = Double.infinity
    while let sample = output.copyNextSampleBuffer() {
        let pts = CMSampleBufferGetPresentationTimeStamp(sample)
        decoded.append(try timeData(pts))
        let offset = CMTimeGetSeconds(pts) - firstSeconds
        let earliest = spawn + offset, latest = ready + offset
        if offset >= 0 && earliest > synthesis && latest < end {
            let distance = abs((earliest + latest) / 2 - (synthesis + end) / 2)
            if distance < closest { selected = pts; closest = distance }
        }
    }
    receipt["decodedPTS"] = decoded
    try require(reader.status == .completed, "AVFoundation did not complete decoding the hold interval")
    guard let selected else { throw FrameFailure.invalid("No decoded frame has its whole capture interval inside the hold") }
    receipt["selectedPTS"] = try timeData(selected)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    let (image, actual) = try await generator.image(at: selected)
    receipt["actualPTS"] = try timeData(actual)
    try require(CMTimeCompare(actual, selected) == 0, "Extracted actual PTS differs from the selected decoded frame")
    let offset = CMTimeGetSeconds(actual) - firstSeconds
    let earliest = spawn + offset, latest = ready + offset
    try require(earliest > synthesis && latest < end, "Extracted frame uncertainty is outside the synthesized hold")
    receipt.merge(["frameWallEarliest": earliest, "frameWallLatest": latest, "frameOffsetFromFirstPTS": offset,
                   "width": image.width, "height": image.height]) { _, next in next }
    guard let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: png) as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw FrameFailure.invalid("Cannot create the extracted PNG")
    }
    CGImageDestinationAddImage(destination, image, nil)
    try require(CGImageDestinationFinalize(destination), "Could not finalize the extracted PNG")
    receipt["pngSha256"] = try digest(png)
    receipt["verified"] = true
    receipt["visualReviewRequired"] = "The actual extracted PNG must show Apple's system Large Content Viewer."
}
catch { receipt["error"] = String(describing: error) }
receipt["extractFinishedWall"] = Date().timeIntervalSince1970
do {
    let bytes = try JSONSerialization.data(withJSONObject: receipt, options: [.prettyPrinted, .sortedKeys])
    try bytes.write(to: URL(fileURLWithPath: receiptPath), options: .withoutOverwriting)
}
catch { fputs("Could not retain frame receipt: \(error)\n", stderr); exit(2) }
if receipt["verified"] as? Bool != true {
    fputs("\(receipt["error"] ?? "Frame evidence did not qualify")\n", stderr)
    exit(1)
}
