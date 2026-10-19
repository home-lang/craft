import XCTest

final class NativeRenderUITests: XCTestCase {
    private func keyboardIsVisible(_ app: XCUIApplication) -> Bool {
        app.keyboards.firstMatch.waitForExistence(timeout: 5)
    }

    func testTypingAndButtonUpdatesDoNotDropTheKeyboard() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertFalse(app.webViews.firstMatch.exists, "native mode created a WebView")
        let field = app.textFields["name-input"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText("Ada")
        XCTAssertEqual(app.staticTexts["name"].label, "Hello Ada")
        XCTAssertTrue(keyboardIsVisible(app))

        for count in 1...3 {
            app.buttons["increment"].tap()
            XCTAssertEqual(app.staticTexts["count"].label, "Count: \(count)")
            XCTAssertTrue(
                keyboardIsVisible(app),
                "state update \(count) dismissed the keyboard"
            )
            field.typeText("x")
            XCTAssertEqual(field.value as? String, "Ada" + String(repeating: "x", count: count))
            XCTAssertEqual(app.staticTexts["name"].label, "Hello Ada" + String(repeating: "x", count: count))
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
        XCTAssertEqual(app.staticTexts["notes"].label, "Notes: Easy run")
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
}
