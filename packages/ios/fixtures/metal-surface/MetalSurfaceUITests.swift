import CoreImage
import XCTest

final class MetalSurfaceUITests: XCTestCase {
    func testDisplayedPixelsResizeAndBackgroundResume() throws {
        let app = XCUIApplication()
        app.launch()
        let status = app.staticTexts["metal-status"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        let verified = NSPredicate { _, _ in status.label.hasPrefix("Verified frame ") }
        expectation(for: NSPredicate { _, _ in status.label == "Verified frame 60" }, evaluatedWith: status)
        waitForExpectations(timeout: 10)
        XCTAssertEqual(app.webViews.count, 0)
        let canvas = app.otherElements["metal-canvas"]
        XCTAssertTrue(canvas.exists)
        try compareScreenPixels(canvas, app: app, name: "Native Metal initial frame")
        app.buttons["metal-resize"].tap()
        expectation(for: NSPredicate { _, _ in abs(canvas.frame.width - 160) < 0.1 }, evaluatedWith: canvas)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(verified.evaluate(with: status), status.label)
        try compareScreenPixels(canvas, app: app, name: "Native Metal resized frame")
        let before = status.label
        XCUIDevice.shared.press(.home)
        app.activate()
        expectation(for: NSPredicate { _, _ in status.label.hasPrefix("Verified frame ") && status.label != before }, evaluatedWith: status)
        waitForExpectations(timeout: 10)
        try compareScreenPixels(canvas, app: app, name: "Native Metal resumed frame")
    }

    private func compareScreenPixels(_ canvas: XCUIElement, app: XCUIApplication, name: String) throws {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let image = try XCTUnwrap(screenshot.image.cgImage)
        let scale = CGFloat(image.width) / app.frame.width
        let native = CIImage(cgImage: image)
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = CIContext()
        let expected = [[224, 32, 64], [32, 192, 96], [32, 64, 224], [208, 160, 32]]
        for (index, color) in expected.enumerated() {
            let x = (canvas.frame.minX + canvas.frame.width * (index % 2 == 0 ? 0.25 : 0.75)) * scale
            let y = (canvas.frame.minY + canvas.frame.height * (index < 2 ? 0.25 : 0.75)) * scale
            var bytes: [UInt8] = [0, 0, 0, 0]
            context.render(native, toBitmap: &bytes, rowBytes: 4,
                           bounds: CGRect(x: floor(x), y: CGFloat(image.height) - floor(y) - 1, width: 1, height: 1),
                           format: .RGBA8, colorSpace: space)
            for channel in 0..<3 {
                XCTAssertLessThanOrEqual(abs(Int(bytes[channel]) - color[channel]), 3,
                                         "Displayed quadrant \(index), channel \(channel): \(bytes), expected \(color)")
            }
            XCTAssertEqual(bytes[3], 255)
        }
    }
}
