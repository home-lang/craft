import UIKit
import QuartzCore
import XCTest
@testable import MetalSurfaceFixture

@MainActor
final class MetalSurfaceTests: XCTestCase {
    func testNativeDrawablePixelsScaleResizeSuspendAndOwnership() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        let canvas = UIView(frame: CGRect(x: 20, y: 100, width: 256, height: 192))
        controller.view.addSubview(canvas)
        controller.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 20_000_000)
        var handle: UnsafeMutableRawPointer?
        try checked(metalOpen(Unmanaged.passUnretained(canvas).toOpaque(), &handle))
        let owner = try XCTUnwrap(handle)
        var liveOwner: UnsafeMutableRawPointer? = owner
        defer { if let liveOwner { XCTAssertEqual(metalClose(liveOwner), 0) } }
        XCTAssertEqual(canvas.layer.sublayers?.filter { $0 is CAMetalLayer }.count, 1)
        var width: UInt32 = 0, height: UInt32 = 0
        var scale: Double = 0
        try checked(metalDimensions(owner, &width, &height, &scale))
        XCTAssertEqual(scale, Double(window.screen.scale))
        XCTAssertEqual(width, UInt32(256 * scale))
        XCTAssertEqual(height, UInt32(192 * scale))
        for frame in 0..<60 {
            if frame == 30 {
                canvas.frame.size = CGSize(width: 160, height: 120)
                try checked(metalDimensions(owner, &width, &height, &scale))
                XCTAssertEqual(width, UInt32(160 * scale))
                XCTAssertEqual(height, UInt32(120 * scale))
            }
            try checked(metalFrame(owner, UInt32(frame)))
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        try checked(metalSuspend(owner, 1))
        let suspended = metalFrame(owner, 60)
        XCTAssertEqual(String(cString: metalError(suspended)), "Suspended")
        try checked(metalSuspend(owner, 0))
        try checked(metalFrame(owner, 61))
        // Keep the allocation owned across the awaited call. Transfer its
        // address, rather than claiming the foreign pointer is Sendable.
        let liveAddress = UInt(bitPattern: owner)
        let wrongThread: Int32 = await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let reference = UnsafeMutableRawPointer(bitPattern: liveAddress)!
                continuation.resume(returning: metalFrame(reference, 62))
            }
        }
        XCTAssertEqual(String(cString: metalError(wrongThread)), "MainThreadRequired")
        try checked(metalClose(owner))
        liveOwner = nil
        XCTAssertEqual(canvas.layer.sublayers?.filter { $0 is CAMetalLayer }.count ?? 0, 0)
    }
}
