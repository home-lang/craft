import XCTest
@testable import NativeRender

/// Heart Rate Measurement (0x2A37) decoding, and the HeartRate module's gate.
/// A real strap needs a phone; the payloads here are the ones straps send.
@MainActor
final class HeartRateUnitTests: XCTestCase {
    func testAUint8RateWithNothingElse() {
        XCTAssertEqual(CraftHeartRateMeasurement.parse([0x00, 72]), CraftHeartRateMeasurement(bpm: 72, sensorContact: nil, energyExpended: nil, rrIntervals: []))
    }

    func testAUint16Rate() {
        XCTAssertEqual(CraftHeartRateMeasurement.parse([0x01, 0x2C, 0x01])?.bpm, 300)
    }

    func testSensorContactOnlyWhenTheStrapReportsIt() {
        XCTAssertEqual(CraftHeartRateMeasurement.parse([0x06, 80])?.sensorContact, true)
        XCTAssertEqual(CraftHeartRateMeasurement.parse([0x04, 80])?.sensorContact, false)
        XCTAssertNil(CraftHeartRateMeasurement.parse([0x02, 80])?.sensorContact)
    }

    func testEnergyThenRRIntervalsInMilliseconds() {
        // 150 bpm, 258 kJ, RR 1024/1024 s and 512/1024 s.
        let reading = CraftHeartRateMeasurement.parse([0x18, 150, 0x02, 0x01, 0x00, 0x04, 0x00, 0x02])
        XCTAssertEqual(reading?.bpm, 150)
        XCTAssertEqual(reading?.energyExpended, 258)
        XCTAssertEqual(reading?.rrIntervals, [1000, 500])
        // A trailing odd byte is not half an interval.
        XCTAssertEqual(CraftHeartRateMeasurement.parse([0x10, 60, 0x00, 0x04, 0x01])?.rrIntervals, [1000])
    }

    func testAPayloadShorterThanItsFlagsSayIsNoReading() {
        XCTAssertNil(CraftHeartRateMeasurement.parse([UInt8]()))
        XCTAssertNil(CraftHeartRateMeasurement.parse([0x01, 0x2C]))
        XCTAssertNil(CraftHeartRateMeasurement.parse([0x08, 60, 0x01]))
    }

    func testTheSimulatorsPayloadsDecodeLikeAStraps() {
        let reading = CraftHeartRateMeasurement.parse(CraftHeartRateMeasurement.encode(bpm: 142, sensorContact: true, rrIntervals: [422.5]))
        XCTAssertEqual(reading?.bpm, 142)
        XCTAssertEqual(reading?.sensorContact, true)
        XCTAssertEqual(reading?.rrIntervals.first ?? 0, 422.5, accuracy: 1)
        XCTAssertEqual(CraftHeartRateMeasurement.parse(CraftHeartRateMeasurement.encode(bpm: 260))?.bpm, 260)
    }

    func testTheSimulatorsBeatsVaryWithTheBreathAndGiveItsRate() {
        var reached: Double = 0
        let intervals = CraftHeartRate.simulatedIntervals(rate: 60, from: &reached, until: 30_000, noise: { 0 })
        XCTAssertGreaterThanOrEqual(reached, 30_000)
        XCTAssertEqual(intervals.reduce(0, +), reached, accuracy: 0.001)
        // About a second apart at 60 bpm, closer on the in-breath and wider on the out-breath.
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        XCTAssertEqual(mean, 1000, accuracy: 15)
        XCTAssertGreaterThan((intervals.max() ?? 0) - (intervals.min() ?? 0), 50)
        XCTAssertLessThan((intervals.max() ?? 0) - (intervals.min() ?? 0), 90)
        // Successive beats differ, so RMSSD is not zero.
        let squares = zip(intervals.dropFirst(), intervals).map { ($0 - $1) * ($0 - $1) }
        XCTAssertGreaterThan((squares.reduce(0, +) / Double(squares.count)).squareRoot(), 5)
    }

    func testReconnectRecoversAQuietBroadcastWithoutReplacingItsRecording() async throws {
        let defaults = UserDefaults.standard
        let previousFake = defaults.object(forKey: "CraftFakeHeartRateMonitor")
        let previousDevice = defaults.object(forKey: "CraftHeartRate.lastDevice")
        defaults.set(true, forKey: "CraftFakeHeartRateMonitor")
        defer {
            defaults.set(previousFake, forKey: "CraftFakeHeartRateMonitor")
            defaults.set(previousDevice, forKey: "CraftHeartRate.lastDevice")
        }
        var time = Date(timeIntervalSince1970: 1_800_000_000)
        let monitor = CraftHeartRate(now: { time })
        var connections: [String] = []
        monitor.pageSink = { event in
            if let connection = event["connection"] as? String { connections.append(connection) }
            return true
        }
        func call(_ method: String, _ args: [Any] = []) async throws -> [String: Any] {
            try await withCheckedThrowingContinuation { continuation in
                monitor.perform(method: method, args: args) { result in
                    switch result {
                    case .success(let value): continuation.resume(returning: value as? [String: Any] ?? [:])
                    case .failure(let error): continuation.resume(throwing: error)
                    }
                }
            }
        }
        _ = try await call("connect", [["id": "00000000-0000-4000-8000-00000000180D"]])
        let recording = try await call("startRecording")
        connections.removeAll()
        _ = try await call("reconnect")
        XCTAssertFalse(connections.contains("reconnecting"), "a healthy subscription must be retained")
        // The link remains connected, but Garmin's broadcast stops delivering.
        time = time.addingTimeInterval(31)
        _ = try await call("reconnect")
        XCTAssertTrue(connections.contains("reconnecting"))
        let continued = try await call("getRecordingState")
        XCTAssertEqual(continued["active"] as? Bool, true)
        XCTAssertEqual(continued["id"] as? String, recording["id"] as? String)
        let recovered = expectation(description: "fresh readings resume after rebuilding the subscription")
        recovered.assertForOverFulfill = false
        monitor.pageSink = { event in
            if event["type"] as? String == "reading" { recovered.fulfill() }
            return true
        }
        await fulfillment(of: [recovered], timeout: 5)
        let restored = try await call("getState")
        XCTAssertNotNil(restored["bpm"] as? Int)
        let saved = try await call("stopRecording")
        XCTAssertGreaterThan((saved["samples"] as? [[String: Any]])?.count ?? 0, 0)
        _ = try await call("disconnect", [["forget": true]])
        time = time.addingTimeInterval(31)
        let forgotten = try await call("getState")
        XCTAssertEqual(forgotten["connection"] as? String, "disconnected")
        XCTAssertTrue(forgotten["lastDevice"] is NSNull)
    }

    func testTheModuleAnswersOnlyWhenTheAppReadsAStrap() async {
        let off = await withCheckedContinuation { continuation in
            CraftNativeActions.perform(requestToken: UUID().uuidString, version: craftNativeCapabilityProtocolVersion, module: "HeartRate", method: "getState", args: [], config: CraftConfig()) { continuation.resume(returning: $0) }
        }
        guard case .failure(let error) = off else { return XCTFail("a build without enableHeartRate answered") }
        XCTAssertEqual(error.code, "CAPABILITY_DISABLED")

        var config = CraftConfig()
        config.enableHeartRate = true
        XCTAssertTrue(CraftNativeActions.capabilities(config: config).contains("heartRate"))
        let on = await withCheckedContinuation { continuation in
            CraftNativeActions.perform(requestToken: UUID().uuidString, version: craftNativeCapabilityProtocolVersion, module: "HeartRate", method: "getRecordingState", args: [], config: config) { continuation.resume(returning: $0) }
        }
        guard case .success(let value) = on, let state = value as? [String: Any] else { return XCTFail("getRecordingState failed") }
        XCTAssertNotNil(state["active"] as? Bool)
    }
}
