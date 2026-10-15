import XCTest

final class HybridNavigationUITests: XCTestCase {
    private func redPageIsVisible(_ screenshot: XCUIScreenshot) -> Bool {
        guard let image = screenshot.image.cgImage else { return false }
        let x = max(0, min(image.width - 1, Int(CGFloat(image.width) * 0.5)))
        let y = max(0, min(image.height - 1, Int(CGFloat(image.height) * 0.5)))
        guard let sample = image.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)) else { return false }
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.draw(sample, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return pixel[0] > 180 && pixel[1] < 140 && pixel[2] < 140
    }

    func testShellWebPushKeepsTheOutgoingPageVisible() {
        let app = XCUIApplication()
        app.launch()
        let open = app.buttons["Open second"]
        XCTAssertTrue(open.waitForExistence(timeout: 15))

        open.tap()
        // CraftHybrid waits 0.35s for the page before pushing a slow route;
        // sample after that deadline, while UIKit is animating the slot.
        let transition = Date().addingTimeInterval(0.45)
        while Date() < transition {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        var sawOutgoingPage = false
        let deadline = Date().addingTimeInterval(0.45)
        while Date() < deadline {
            if redPageIsVisible(XCUIScreen.main.screenshot()) {
                sawOutgoingPage = true
                break
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        XCTAssertTrue(sawOutgoingPage, "the outgoing web page went blank during the hybrid push")
        XCTAssertTrue(app.buttons["Back home"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Hybrid second"].waitForExistence(timeout: 10))
    }
}
