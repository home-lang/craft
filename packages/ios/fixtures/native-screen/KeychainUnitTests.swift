import XCTest
@testable import NativeRender

/// CraftKeychain: a Keychain read once, then from memory until something in
/// this process changes it. A read took up to 900ms on a simulator, on the
/// main thread, and every screen reads the sign-in token when it opens.
final class KeychainUnitTests: XCTestCase {
    override func setUp() {
        super.setUp()
        CraftKeychain.forget(account: nil)
    }

    func testReadsTheKeychainOnceAndThenFromMemory() {
        var reads = 0
        let read = { () -> String? in reads += 1; return "token-1" }
        XCTAssertEqual(CraftKeychain.value(account: "auth.token", service: nil, read: read), "token-1")
        XCTAssertEqual(CraftKeychain.value(account: "auth.token", service: nil, read: read), "token-1")
        XCTAssertEqual(reads, 1)
    }

    func testRemembersThatAnItemIsAbsent() {
        var reads = 0
        let read = { () -> String? in reads += 1; return nil }
        XCTAssertNil(CraftKeychain.value(account: "missing", service: "dev.craft.native.secure", read: read))
        XCTAssertNil(CraftKeychain.value(account: "missing", service: "dev.craft.native.secure", read: read))
        XCTAssertEqual(reads, 1)
    }

    func testForgettingAnAccountReadsItAgainUnderEveryServiceAndLeavesOthers() {
        var reads: [String] = []
        func read(_ name: String, _ value: String) -> () -> String? { { reads.append(name); return value } }
        _ = CraftKeychain.value(account: "auth.token", service: nil, read: read("any", "a"))
        _ = CraftKeychain.value(account: "auth.token", service: "dev.craft.native.secure", read: read("native", "a"))
        _ = CraftKeychain.value(account: "wildloop-account", service: nil, read: read("other", "b"))
        CraftKeychain.forget(account: "auth.token")
        _ = CraftKeychain.value(account: "auth.token", service: nil, read: read("any", "a2"))
        _ = CraftKeychain.value(account: "auth.token", service: "dev.craft.native.secure", read: read("native", "a2"))
        _ = CraftKeychain.value(account: "wildloop-account", service: nil, read: read("other", "b"))
        XCTAssertEqual(reads, ["any", "native", "other", "any", "native"])
    }

    func testAReadThatRacedAWriteIsNotKept() {
        var reads = 0
        // The write lands while the read is still asking the Keychain.
        let stale = CraftKeychain.value(account: "auth.token", service: nil) {
            reads += 1
            CraftKeychain.forget(account: "auth.token")
            return "old"
        }
        XCTAssertEqual(stale, "old")
        XCTAssertEqual(CraftKeychain.value(account: "auth.token", service: nil) { reads += 1; return "new" }, "new")
        XCTAssertEqual(reads, 2)
    }

    func testAWriteThroughTheHybridKeychainIsSeenByTheNextRead() {
        let key = "craft-keychain-test-\(UUID().uuidString)"
        defer { CraftHybridKeychain.set(key, value: nil) }
        CraftHybridKeychain.set(key, value: "first")
        XCTAssertEqual(CraftNativeActions.webSecureValue(forKey: key), "first")
        CraftHybridKeychain.set(key, value: "second")
        XCTAssertEqual(CraftNativeActions.webSecureValue(forKey: key), "second")
        CraftHybridKeychain.set(key, value: nil)
        XCTAssertNil(CraftNativeActions.webSecureValue(forKey: key))
    }
}
