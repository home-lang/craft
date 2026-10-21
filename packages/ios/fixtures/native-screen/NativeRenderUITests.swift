import XCTest

final class NativeRenderUITests: XCTestCase {
    private func keyboardIsVisible(_ app: XCUIApplication) -> Bool {
        app.keyboards.firstMatch.waitForExistence(timeout: 5)
    }

    /// A label the screen derives from typed text is drawn from the script
    /// thread, after the keystroke: `typeText` returns once the main thread
    /// is idle, which says nothing about a mutation still on its way back.
    /// The typed value itself is checked at once; only its echo is waited
    /// for, and a missing last keystroke still fails after `timeout`.
    @discardableResult
    private func waitForLabel(_ element: XCUIElement, _ expected: String, timeout: TimeInterval = 3, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let matched = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", expected), object: element)], timeout: timeout) == .completed
        XCTAssertTrue(matched, "\(element.identifier) reads \"\(element.label)\", not \"\(expected)\", \(timeout)s after typing", file: file, line: line)
        return matched
    }

    func testTypingAndButtonUpdatesDoNotDropTheKeyboard() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertFalse(app.webViews.firstMatch.exists, "native mode created a WebView")
        let field = app.textFields["name-input"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText("Ada")
        XCTAssertEqual(field.value as? String, "Ada", "the native field lost typed characters")
        waitForLabel(app.staticTexts["name"], "Hello Ada")
        XCTAssertTrue(keyboardIsVisible(app))

        for count in 1...3 {
            app.buttons["increment"].tap()
            waitForLabel(app.staticTexts["count"], "Count: \(count)")
            XCTAssertTrue(
                keyboardIsVisible(app),
                "state update \(count) dismissed the keyboard"
            )
            field.typeText("x")
            XCTAssertEqual(field.value as? String, "Ada" + String(repeating: "x", count: count))
            waitForLabel(app.staticTexts["name"], "Hello Ada" + String(repeating: "x", count: count))
        }
    }

    /// A multiline TextInput is a text view to UI tests and VoiceOver, and
    /// takes the keyboard: its accessibility traits must keep UITextView's own.
    func testMultilineTextInputTakesTyping() throws {
        let app = XCUIApplication()
        app.launch()
        let notes = app.textViews["notes-input"]
        XCTAssertTrue(notes.waitForExistence(timeout: 15), "the multiline input is not exposed as a text view")
        notes.tap()
        XCTAssertTrue(keyboardIsVisible(app))
        notes.typeText("Easy run")
        XCTAssertEqual(notes.value as? String, "Easy run", "the native text view lost typed characters")
        XCTAssertTrue(app.keyboards.firstMatch.exists, "typing dismissed the native keyboard")
        waitForLabel(app.staticTexts["notes"], "Notes: Easy run")
    }

    func testSwitchTapChangesUIKitStateAndDeliversValueChange() throws {
        let app = XCUIApplication()
        app.launch()
        let toggle = app.switches["native-switch"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 15))
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "1")
        XCTAssertEqual(app.staticTexts["switch-result"].label, "Switch on")
    }

    func testSwitchInsideScrollViewTakesOneTap() throws {
        let app = XCUIApplication()
        app.launch()
        let toggle = app.switches["scroll-switch"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 15))
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "1")
        XCTAssertEqual(app.staticTexts["switch-result"].label, "Switch on")
    }

    /// A drag that starts on a button scrolls the page, and presses nothing.
    /// UIKit leaves a touch with the control it began on unless the scroll
    /// view cancels it, so on a page made of buttons - a trail page's map
    /// controls, a form's pickers - a drag from most places did nothing.
    func testADragThatStartsOnAButtonScrolls() throws {
        let app = XCUIApplication()
        app.launch()
        let first = app.buttons["scroll-button-0"]
        XCTAssertTrue(first.waitForExistence(timeout: 15))
        let before = first.frame.minY
        let start = app.buttons["scroll-button-2"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -100)), withVelocity: .slow, thenHoldForDuration: 0.3)
        XCTAssertLessThan(first.frame.minY, before - 40, "a drag from a button did not scroll its scroll view")
        XCTAssertEqual(app.staticTexts["scroll-presses"].label, "Scroll presses: 0", "the drag pressed the button it started on")
        // A tap still presses one.
        app.buttons["scroll-button-3"].tap()
        XCTAssertEqual(app.staticTexts["scroll-presses"].label, "Scroll presses: 1")
    }
}
