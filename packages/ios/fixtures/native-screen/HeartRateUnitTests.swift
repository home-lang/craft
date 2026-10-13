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
