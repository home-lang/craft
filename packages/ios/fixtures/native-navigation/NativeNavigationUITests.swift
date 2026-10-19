import XCTest

final class NativeNavigationUITests: XCTestCase {
    private func layoutCount(_ element: XCUIElement) -> Int {
        Int(String(element.label.split(separator: ":").last ?? "0").trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    private func waitForLabel(
        _ element: XCUIElement,
        _ label: String,
        timeout: TimeInterval = 10
    ) -> Bool {
        let predicate = NSPredicate(format: "label == %@", label)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForLayoutIncrease(
        _ element: XCUIElement,
        from baseline: Int,
        timeout: TimeInterval = 10
    ) -> Bool {
        let predicate = NSPredicate { object, _ in
            guard let candidate = object as? XCUIElement else { return false }
            return self.layoutCount(candidate) > baseline
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForLayoutDecrease(
        _ element: XCUIElement,
        from baseline: CGFloat,
        timeout: TimeInterval = 10
    ) -> Bool {
        let predicate = NSPredicate { object, _ in
            guard let candidate = object as? XCUIElement else { return false }
            return candidate.frame.width < baseline - 20
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func inside(_ element: XCUIElement, _ scroll: XCUIElement) -> Bool {
        let frame = element.frame
        let viewport = scroll.frame
        return !frame.isEmpty && frame.minY >= viewport.minY - 0.5 && frame.maxY <= viewport.maxY + 0.5
    }

    /// Scrolls `scroll` until `element` sits wholly inside it. A nested
    /// scroll view is first brought wholly into the root scroll: XCUITest
    /// scrolls the root by itself to reach whatever a tap targets, so an
    /// inner scroll view can be anywhere, and a swipe that starts in its
    /// clipped part lands on whatever lies outside it. The drag starts where
    /// no nested scroll view would take it, travels a bounded distance and
    /// holds before lifting, so the offset is not left to momentum.
    private func reveal(
        _ element: XCUIElement,
        in scroll: XCUIElement,
        within root: XCUIElement? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "missing control before scrolling", file: file, line: line)
        if let root { reveal(scroll, in: root, file: file, line: line) }
        for _ in 0..<24 {
            if inside(element, scroll) && element.isHittable { return }
            let viewport = scroll.frame
            let nested: [CGRect] = scroll.descendants(matching: .scrollView).allElementsBoundByIndex.map { $0.frame }
            var start: CGFloat = 0.5
            for step in 0...8 {
                let offset = CGFloat(step) * 0.05
                let free = [0.5 + offset, 0.5 - offset].first { (fraction: CGFloat) -> Bool in
                    let y = viewport.minY + viewport.height * fraction
                    return !nested.contains { (frame: CGRect) -> Bool in frame.minY - 4 <= y && y <= frame.maxY + 4 }
                }
                if let free { start = free; break }
            }
            // Content moves the opposite way to the finger, which may leave
            // a short scroll view: the drag stays its own until it lifts.
            let distance = max(-240, min(240, element.frame.midY - viewport.midY))
            let from = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: start))
            let to = from.withOffset(CGVector(dx: 0, dy: -distance))
            from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.3)
        }
        XCTAssertTrue(inside(element, scroll) && element.isHittable, "control remained outside the native scroll viewport", file: file, line: line)
    }

    private func openCapabilities(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["open-capabilities"].waitForExistence(timeout: 15))
        app.buttons["open-capabilities"].tap()
        XCTAssertTrue(app.staticTexts["capabilities-title"].waitForExistence(timeout: 10))
    }

    private func swipeTab(_ app: XCUIApplication, left: Bool) {
        let window = app.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.8 : 0.2, dy: 0.35))
        let end = window.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.2 : 0.8, dy: 0.35))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
    }

    func testTabSwipeSwitchesNativeRootsAndReturns() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertFalse(app.webViews.firstMatch.exists, "tab swipe fixture created a WebView")
        swipeTab(app, left: true)
        XCTAssertTrue(app.staticTexts["details-title"].waitForExistence(timeout: 10))
        swipeTab(app, left: false)
        XCTAssertTrue(app.staticTexts["home-title"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Home"].isSelected)
    }

    func testSwipesAcrossAllFiveNativeTabsAndBack() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["home-title"].waitForExistence(timeout: 15))
        let tabs = [("Home", "home-title"), ("Details", "details-title"), ("Third", "summary-title"), ("Fourth", "details-title"), ("Fifth", "summary-title")]
        for index in Array(1..<tabs.count) + Array((0..<(tabs.count - 1)).reversed()) {
            let left = index > (tabs.firstIndex { app.buttons[$0.0].isSelected } ?? 0)
            swipeTab(app, left: left)
            let (title, identifier) = tabs[index]
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: app.buttons[title])
            XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 10), .completed, "tab selection did not settle on \(title)")
            let content = app.staticTexts[identifier]
            XCTAssertTrue(content.waitForExistence(timeout: 10))
            XCTAssertTrue(content.isHittable, "selected native tab has no usable screen")
            XCTAssertGreaterThanOrEqual(content.frame.minX, app.windows.firstMatch.frame.minX)
            XCTAssertLessThanOrEqual(content.frame.maxX, app.windows.firstMatch.frame.maxX)
            XCTAssertFalse(app.webViews.firstMatch.exists)
        }
    }

    func testShortTabSwipeCancelsAndTheNextSwipeStillWorks() {
        let app = XCUIApplication()
        app.launch()
        let home = app.staticTexts["home-title"]
        XCTAssertTrue(home.waitForExistence(timeout: 15))
        let baseline = home.frame
        let window = app.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.35))
        let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.35))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
        XCTAssertTrue(home.isHittable, "cancelled drag did not restore the native root")
        XCTAssertEqual(home.frame.minX, baseline.minX, accuracy: 1)
        XCTAssertFalse(app.staticTexts["details-title"].isHittable)
        swipeTab(app, left: true)
        let details = app.staticTexts["details-title"]
        XCTAssertTrue(details.waitForExistence(timeout: 10))
        XCTAssertTrue(details.isHittable)
        XCTAssertGreaterThanOrEqual(details.frame.minX, window.frame.minX)
        XCTAssertLessThanOrEqual(details.frame.maxX, window.frame.maxX)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Native tab after cancelled and completed swipe"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        swipeTab(app, left: false)
        XCTAssertTrue(home.waitForExistence(timeout: 10))
        XCTAssertEqual(home.frame.minX, baseline.minX, accuracy: 1)
    }

    func testDraggingFromAButtonScrollsWithoutActivatingIt() {
        let app = XCUIApplication()
        app.launch()
        let scroll = app.scrollViews["native-root-scroll"]
        let button = app.buttons["toggle-safe-area"]
        let marker = app.staticTexts["home-title"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 10))
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        let baseline = marker.frame.minY
        let start = button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -120)), withVelocity: .slow, thenHoldForDuration: 0.3)
        XCTAssertLessThan(marker.frame.minY, baseline - 30, "A drag that starts on a button must scroll the list")
        XCTAssertEqual(app.staticTexts["safe-area-status"].label, "Safe edges: top,bottom", "Scrolling must cancel the button's tap")
    }

    func testMultilineInputKeepsKeyboardFocusWhenTapped() {
        let app = XCUIApplication()
        app.launch()
        let root = app.scrollViews["native-root-scroll"]
        XCTAssertTrue(root.waitForExistence(timeout: 10))
        let notes = app.textViews["notes-input"]
        reveal(notes, in: root)
        notes.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "The scroll container dismissed the text area's keyboard")
        // A native tap can place the caret anywhere. Exercise the review edit
        // interaction explicitly instead of assuming insertion is at the end.
        notes.press(forDuration: 1)
        let selectAll = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Select All")).firstMatch
        XCTAssertTrue(selectAll.waitForExistence(timeout: 5), "The text area must retain its native selection menu")
        selectAll.tap()
        notes.typeText("Draft edited")
        XCTAssertEqual(notes.value as? String, "Draft edited")
        notes.tap()
        XCTAssertTrue(app.keyboards.firstMatch.exists, "Tapping the text area again must preserve editing")
    }

    func testHorizontalCarouselKeepsItsSwipe() {
        let app = XCUIApplication()
        app.launch()
        let carousel = app.scrollViews["tab-swipe-carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 10))
        let start = carousel.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
        let end = carousel.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertFalse(app.staticTexts["details-title"].exists, "carousel swipe was claimed by the tab shell")
        XCTAssertTrue(app.staticTexts["tab-swipe-carousel-label"].exists)
        swipeTab(app, left: true)
        XCTAssertTrue(app.staticTexts["details-title"].waitForExistence(timeout: 10))
    }

    func testSafeAreaEdgesUpdateTheNativeRootWithoutRecreatingItsScrollView() {
        let app = XCUIApplication()
        app.launch()
        let rootScroll = app.scrollViews["native-root-scroll"]
        XCTAssertTrue(rootScroll.waitForExistence(timeout: 15))
        let toggle = app.buttons["toggle-safe-area"]
        reveal(toggle, in: rootScroll)

        let baseline = rootScroll.frame.minY
        toggle.tap()
        XCTAssertTrue(waitForLabel(app.staticTexts["safe-area-status"], "Safe edges: bottom"))
        let removed = XCTNSPredicateExpectation(predicate: NSPredicate { object, _ in
            guard let candidate = object as? XCUIElement else { return false }
            return candidate.frame.minY < baseline - 4
        }, object: rootScroll)
        XCTAssertEqual(XCTWaiter.wait(for: [removed], timeout: 5), .completed,
                       "removing the top edge did not remove the native top inset")

        toggle.tap()
        XCTAssertTrue(waitForLabel(app.staticTexts["safe-area-status"], "Safe edges: top,bottom"))
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate { object, _ in
            abs(((object as? XCUIElement)?.frame.minY ?? baseline) - baseline) <= 2
        }, object: rootScroll)
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 5), .completed,
                       "restoring the top edge did not restore the native inset")
    }

    func testRetainedContainerCanSwitchBetweenViewAndSafeAreaView() {
        let app = XCUIApplication()
        app.launch()
        let rootScroll = app.scrollViews["native-root-scroll"]
        XCTAssertTrue(rootScroll.waitForExistence(timeout: 15))
        let toggle = app.buttons["toggle-retained-safe-area"]
        reveal(toggle, in: rootScroll)

        XCTAssertTrue(waitForLabel(app.staticTexts["retained-safe-area-status"], "Retained: plain"))
        XCTAssertTrue(app.otherElements["retained-safe-area"].waitForExistence(timeout: 5))
        toggle.tap()
        XCTAssertTrue(waitForLabel(app.staticTexts["retained-safe-area-status"], "Retained: safe"))
        XCTAssertTrue(app.otherElements["retained-safe-area"].waitForExistence(timeout: 5))
        toggle.tap()
        XCTAssertTrue(waitForLabel(app.staticTexts["retained-safe-area-status"], "Retained: plain"))
        XCTAssertTrue(app.otherElements["retained-safe-area"].waitForExistence(timeout: 5))
    }

    func testMultipleFloatingNavigationButtonsStayIndependent() {
        let app = XCUIApplication()
        app.launch()
        let messages = app.buttons["fixture-messages"]
        let account = app.buttons["fixture-account"]
        XCTAssertTrue(messages.waitForExistence(timeout: 10))
        XCTAssertTrue(account.waitForExistence(timeout: 10))

        let window = app.windows.firstMatch.frame
        for button in [messages, account] {
            XCTAssertGreaterThanOrEqual(button.frame.width, 36, "navigation button became too narrow")
            XCTAssertLessThanOrEqual(button.frame.width, 52, "navigation button grew into a shared slab")
            XCTAssertGreaterThanOrEqual(button.frame.height, 36, "navigation button became too short")
            XCTAssertLessThanOrEqual(button.frame.height, 52, "navigation button grew vertically")
            XCTAssertGreaterThanOrEqual(button.frame.minX, window.minX - 1)
            XCTAssertLessThanOrEqual(button.frame.maxX, window.maxX + 1, "navigation button ran past the screen edge")
        }
        XCTAssertNotEqual(messages.frame, account.frame, "adjacent buttons collapsed into one surface")
        let ordered = [messages.frame, account.frame].sorted { $0.minX < $1.minX }
        XCTAssertGreaterThanOrEqual(ordered[1].minX, ordered[0].maxX - 1,
                                    "floating navigation buttons overlapped into one platter")
    }

    func testRefreshedScrollViewKeepsInputFocusAcrossKeyedMoves() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["navigation-open-details"].tap()
        XCTAssertTrue(app.staticTexts["details-title"].waitForExistence(timeout: 10))
        let people = app.scrollViews["people-list"]
        XCTAssertTrue(people.waitForExistence(timeout: 5))
        people.swipeDown()
        XCTAssertTrue(waitForLabel(app.staticTexts["people-count"], "People: 40; events: 1"))
        let input = app.textFields["person-input-person-0"]
        reveal(input, in: people)
        input.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        input.typeText("draft")
        app.buttons["shuffle-people"].tap()
        XCTAssertTrue(waitForLabel(app.staticTexts["person-label-person-0"], "1: Person zero updated"))
        XCTAssertEqual(input.value as? String, "draft")
        input.typeText("!")
        XCTAssertEqual(input.value as? String, "draft!")
    }

    func testNativeLinkOpensRoute() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["navigation-increment"].waitForExistence(timeout: 15))
        app.buttons["navigation-increment"].tap()
        XCTAssertTrue(waitForLabel(app.staticTexts["navigation-home-state"], "Home state: Ada/1"))
        let link = app.links["native-route-link"]
        XCTAssertTrue(link.waitForExistence(timeout: 10))
        reveal(link, in: app.scrollViews["native-root-scroll"])
        link.tap()
        XCTAssertTrue(app.staticTexts["details-title"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.webViews.firstMatch.exists, "native link opened a WebView")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == %@ AND selected == true", "Home")).count, 1, "link selected the Details tab instead of pushing")
        app.buttons["details-back"].tap()
        XCTAssertTrue(link.waitForExistence(timeout: 10))
    }

    func testPushedScreenTabAccessoryOpensNativeRouteAndClearsOnBack() {
        let app = XCUIApplication()
        app.launch()
        let openDetails = app.buttons["navigation-open-details"]
        XCTAssertTrue(openDetails.waitForExistence(timeout: 15))
        openDetails.tap()
        XCTAssertTrue(app.staticTexts["details-title"].waitForExistence(timeout: 10))

        let accessory = app.buttons["craft-tab-accessory"]
        XCTAssertTrue(accessory.waitForExistence(timeout: 10))
        XCTAssertEqual(accessory.label, "Open capabilities")
        let frame = accessory.frame
        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThanOrEqual(frame.width, 44)
        XCTAssertGreaterThanOrEqual(frame.height, 44)
        XCTAssertGreaterThanOrEqual(frame.minX, window.minX)
        XCTAssertLessThanOrEqual(frame.maxX, window.maxX)
        let before = XCTAttachment(screenshot: app.screenshot())
        before.name = "Native tab accessory before tap"
        before.lifetime = .keepAlways
        add(before)
        accessory.tap()
        XCTAssertTrue(app.staticTexts["capabilities-title"].waitForExistence(timeout: 10))
        XCTAssertFalse(accessory.exists, "the accessory from the pushed screen remained over its destination")

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["details-title"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["craft-tab-accessory"].waitForExistence(timeout: 10), "the pushed screen accessory was not restored")
        // The glass surface outside the small symbol is a native button too.
        accessory.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["capabilities-title"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["details-title"].waitForExistence(timeout: 10))
        app.buttons["details-back"].tap()
        XCTAssertTrue(app.staticTexts["home-title"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["craft-tab-accessory"].exists, "the accessory was not cleared after leaving the pushed screen")
    }

    func testCapabilityPersistenceAndNotificationsAcrossRelaunch() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertFalse(app.webViews.firstMatch.exists, "capability screen created a WebView")
        openCapabilities(app)
        XCTAssertEqual(app.staticTexts["capabilities-platform"].label, "Platform: ios")
        XCTAssertEqual(app.staticTexts["capabilities-state"].label, "App state: active")

        app.buttons["save-capabilities"].tap()
        let status = app.staticTexts["capabilities-status"]
        XCTAssertTrue(waitForLabel(status, "Saved Ada and Grace"), "found \(status.label)")
        app.terminate()
        app.launch()
        openCapabilities(app)
        app.buttons["load-capabilities"].tap()
        XCTAssertTrue(waitForLabel(status, "Loaded Ada and Grace"), "found \(status.label)")

        app.buttons["test-notifications"].tap()
        // Scheduling asks for permission first. The alert is SpringBoard's, so
        // it is answered there directly: an interruption monitor only runs
        // when a later query happens to be blocked by the alert, and on a
        // loaded runner that came after the label wait had given up.
        let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.buttons["Allow"]
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline, !status.label.hasPrefix("Notification") {
            if allow.waitForExistence(timeout: 1) { allow.tap() }
        }
        XCTAssertEqual(status.label, "Notifications scheduled and cancelled")

        app.buttons["test-secure-storage"].tap()
        XCTAssertTrue(waitForLabel(status, "Secure storage roundtrip"), "found \(status.label)")
    }

    func testSharedRuntimePushBackReplaceLifecycleAndStateIsolation() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertFalse(app.webViews.firstMatch.exists, "native navigation created a WebView")

        let homeState = app.staticTexts["navigation-home-state"]
        XCTAssertTrue(homeState.waitForExistence(timeout: 15))
        XCTAssertEqual(homeState.label, "Home state: Ada/0")
        app.buttons["navigation-increment"].tap()
        app.buttons["navigation-increment"].tap()
        XCTAssertTrue(waitForLabel(homeState, "Home state: Ada/2"))

        app.buttons["navigation-open-details"].tap()
        let detailsTitle = app.staticTexts["details-title"]
        let detailsCount = app.staticTexts["details-count"]
        XCTAssertTrue(detailsTitle.waitForExistence(timeout: 10))
        XCTAssertEqual(detailsTitle.label, "Details for Ada")
        XCTAssertEqual(detailsCount.label, "Count: 2")
        app.buttons["details-increment"].tap()
        XCTAssertTrue(waitForLabel(detailsCount, "Count: 3"))
        app.buttons["details-back"].tap()

        XCTAssertTrue(homeState.waitForExistence(timeout: 10))
        XCTAssertEqual(homeState.label, "Home state: Ada/2")
        app.buttons["navigation-check-lifecycle"].tap()
        XCTAssertTrue(waitForLabel(app.staticTexts["navigation-lifecycle"], "Disposed Ada/3"))

        app.buttons["navigation-open-details"].tap()
        XCTAssertTrue(detailsTitle.waitForExistence(timeout: 10))
        XCTAssertEqual(detailsCount.label, "Count: 2", "a pushed screen reused stale detail state")
        app.buttons["open-summary"].tap()
        XCTAssertTrue(app.staticTexts["summary-title"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["summary-title"].label, "Summary for Ada")
        XCTAssertEqual(app.staticTexts["summary-count"].label, "Count: 2")
        app.buttons["summary-back"].tap()

        XCTAssertTrue(homeState.waitForExistence(timeout: 10), "replace left details on the stack")
        XCTAssertEqual(homeState.label, "Home state: Ada/2")
        app.buttons["navigation-check-lifecycle"].tap()
        XCTAssertTrue(waitForLabel(app.staticTexts["navigation-lifecycle"], "Disposed Ada/2"))

        app.buttons["navigation-open-details"].tap()
        XCTAssertTrue(detailsTitle.waitForExistence(timeout: 10))
        XCTAssertTrue(app.navigationBars.buttons.firstMatch.waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(homeState.waitForExistence(timeout: 10))
        XCTAssertEqual(homeState.label, "Home state: Ada/2")
    }

    func testNativeBackSwipeKeepsTheSelectedTabAndHomeState() {
        let app = XCUIApplication()
        app.launch()
        let homeState = app.staticTexts["navigation-home-state"]
        XCTAssertTrue(homeState.waitForExistence(timeout: 15))
        app.buttons["navigation-increment"].tap()
        XCTAssertTrue(waitForLabel(homeState, "Home state: Ada/1"))
        app.buttons["navigation-open-details"].tap()
        XCTAssertTrue(app.staticTexts["details-title"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.navigationBars.buttons.firstMatch.waitForExistence(timeout: 5))

        let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.005, dy: 0.5))
        let destination = app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
        edge.press(forDuration: 0.1, thenDragTo: destination)

        XCTAssertTrue(homeState.waitForExistence(timeout: 10), "native back gesture did not pop the pushed screen")
        XCTAssertEqual(homeState.label, "Home state: Ada/1")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == %@ AND selected == true", "Home")).count, 1, "back gesture changed the selected tab")
        XCTAssertFalse(app.webViews.firstMatch.exists, "native back gesture created a WebView")
    }

    func testSharedRuntimeKeyedForPreservesNativeRowState() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertFalse(app.webViews.firstMatch.exists, "keyed native list created a WebView")

        let scroll = app.scrollViews["native-root-scroll"]
        let status = app.staticTexts["keyed-list-status"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Ada row"].exists)
        let beaLabel = app.staticTexts["Bea row"]
        XCTAssertTrue(beaLabel.exists)
        let beaInput = app.textFields["navigation-input-b"]
        XCTAssertTrue(beaInput.waitForExistence(timeout: 5))

        beaInput.tap()
        beaInput.typeText("draft")

        XCTAssertTrue(app.staticTexts["Bea row updated"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Cy row"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Ada row"].exists)
        XCTAssertEqual(beaInput.value as? String, "draft")
        beaInput.typeText("!")
        XCTAssertEqual(beaInput.value as? String, "draft!")
        app.buttons["navigation-select-b"].tap()
        XCTAssertTrue(waitForLabel(status, "Selected: b"))
        XCTAssertTrue(scroll.exists, "keyed reconciliation replaced the list scroll host")
    }

    func testPushNativeBackSwipeReplaceAndRetainedHomeState() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertFalse(app.webViews.firstMatch.exists, "native navigation created a WebView")
        // Measure padding before any gesture changes this inner scroll offset.
        let scroll = app.scrollViews["native-scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 15))
        let image = app.images["native-image"]
        XCTAssertTrue(image.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(image.frame.minY, scroll.frame.minY + 12, "ScrollView contentContainerStyle did not add top padding")
        let rootScroll = app.scrollViews["native-root-scroll"]
        XCTAssertTrue(rootScroll.waitForExistence(timeout: 15))
        let rootOverlay = app.otherElements["native-root-overlay"]
        XCTAssertTrue(rootOverlay.waitForExistence(timeout: 5), "root absolute sibling did not mount")
        let overlayFrame = rootOverlay.frame
        let overlayTop = overlayFrame.minY - rootScroll.frame.minY
        rootScroll.swipeUp()
        // A large navigation title can collapse, moving the viewport itself.
        XCTAssertEqual(rootOverlay.frame.minY - rootScroll.frame.minY, overlayTop, accuracy: 2, "root absolute sibling moved with ScrollView content")
        XCTAssertEqual(rootOverlay.frame.maxX, overlayFrame.maxX, accuracy: 2, "root absolute sibling changed horizontal position")
        let bubble = app.otherElements["max-content-bubble"]
        let bubbleText = app.staticTexts["max-content-bubble-text"]
        XCTAssertTrue(bubble.waitForExistence(timeout: 5), "max-content bubble did not mount")
        XCTAssertTrue(bubbleText.waitForExistence(timeout: 5), "max-content bubble text did not mount")
        XCTAssertLessThan(bubbleText.frame.height, 30, "text took min-content width and wrapped unexpectedly")
        XCTAssertGreaterThan(bubble.frame.width, bubbleText.frame.width, "bubble did not retain its authored horizontal padding")
        let intrinsicImage = app.images["intrinsic-image"]
        XCTAssertTrue(intrinsicImage.waitForExistence(timeout: 10), "intrinsic image did not mount")
        XCTAssertTrue(app.staticTexts["intrinsic image ready"].waitForExistence(timeout: 5), "intrinsic image did not receive its initial measurement")
        let intrinsicImageToggle = app.buttons["toggle-intrinsic-image"]
        reveal(intrinsicImageToggle, in: scroll, within: rootScroll)
        intrinsicImageToggle.tap()
        XCTAssertTrue(app.staticTexts["intrinsic image resized"].waitForExistence(timeout: 5), "intrinsic image source change did not invalidate its parent measurement")
        let resizeToggle = app.buttons["toggle-image-resize-mode"]
        XCTAssertTrue(resizeToggle.waitForExistence(timeout: 5), "dynamic image resize fixture did not mount")
        XCTAssertTrue(app.staticTexts["cover"].waitForExistence(timeout: 5), "dynamic image did not start in cover mode")
        reveal(resizeToggle, in: scroll, within: rootScroll)
        resizeToggle.tap()
        XCTAssertTrue(app.staticTexts["contain"].waitForExistence(timeout: 5), "dynamic image resize mode did not reconcile")
        resizeToggle.tap()
        XCTAssertTrue(app.staticTexts["cover"].waitForExistence(timeout: 5), "dynamic image resize mode did not restore cover")
        let imageBackground = app.images["native-image-background"]
        XCTAssertTrue(imageBackground.waitForExistence(timeout: 10), "ImageBackground did not mount as a native image container")
        let unsupportedBackground = app.images["unsupported-image-background"]
        XCTAssertTrue(unsupportedBackground.waitForExistence(timeout: 10), "unsupported ImageBackground did not mount")
        XCTAssertTrue(waitForLabel(app.staticTexts["image-background-error-status"], "background failed"))
        let unsupportedBackgroundValue = (unsupportedBackground.value as? String) ?? ""
        XCTAssertTrue(unsupportedBackgroundValue.contains("Unsupported image source"), "ImageBackground error did not reach accessibilityValue")
        XCTAssertTrue(app.otherElements["native-keyboard-avoiding"].waitForExistence(timeout: 10), "KeyboardAvoidingView did not mount as a native container")
        let svg = app.descendants(matching: .any)["native-svg"]
        XCTAssertTrue(svg.waitForExistence(timeout: 5), "SVG fixture did not mount as a native view")
        XCTAssertEqual(svg.label, "Native vector", "SVG accessibility metadata did not survive native mounting")
        let icon = app.images["native-icon"]
        XCTAssertTrue(icon.waitForExistence(timeout: 5), "Icon fixture did not mount as a native image view")
        XCTAssertEqual(icon.label, "Native icon")
        let sectionList = app.scrollViews["native-section-list"]
        XCTAssertTrue(sectionList.waitForExistence(timeout: 5), "SectionList fixture did not mount as a native scroll view")
        XCTAssertTrue(app.staticTexts["native-section-header"].waitForExistence(timeout: 5), "SectionList header did not reconcile")
        XCTAssertTrue(app.staticTexts["native-section-row"].waitForExistence(timeout: 5), "SectionList row did not reconcile")
        XCTAssertTrue(app.staticTexts["native-section-footer"].waitForExistence(timeout: 5), "SectionList overflow content did not reconcile")
        reveal(sectionList, in: rootScroll)
        sectionList.swipeUp()
        XCTAssertTrue(waitForLabel(app.staticTexts["section-scroll-status"], "Section scrolls: 1"), "SectionList did not deliver onScroll")
        XCTAssertTrue(app.otherElements["native-video"].waitForExistence(timeout: 5), "Video fixture did not mount as a native view")
        XCTAssertEqual(app.staticTexts["home-title"].label, "Home")
        app.buttons["native-audio-context"].tap()
        XCTAssertTrue(app.staticTexts["AudioContext ready"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.datePickers["native-countdown"].waitForExistence(timeout: 5), "countdown DatePicker did not mount natively")
        let checkbox = app.buttons["native-checkbox"]
        XCTAssertTrue(checkbox.waitForExistence(timeout: 5), "native Checkbox did not mount natively")
        checkbox.tap()
        XCTAssertTrue(app.staticTexts["checkbox-status"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["checkbox-status"].label, "checkbox on")
        let indeterminateCheckbox = app.buttons["native-checkbox-indeterminate"]
        XCTAssertTrue(indeterminateCheckbox.waitForExistence(timeout: 5))
        XCTAssertEqual(indeterminateCheckbox.value as? String, "mixed")
        XCTAssertEqual(app.buttons["checkbox-checked-precedence"].value as? String, "unchecked")
        XCTAssertTrue(app.buttons["disabled-button"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["disabled-button"].isEnabled)
        XCTAssertEqual(image.label, "Native pixel")
        XCTAssertTrue(app.staticTexts["image loaded"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["image load ended"].waitForExistence(timeout: 5))
        image.tap()
        XCTAssertEqual(app.staticTexts["native-caption"].label, "Image taps: 1")
        XCTAssertTrue(app.images["unsupported-image"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["image failed"].waitForExistence(timeout: 5))
        let imageSourceToggle = app.buttons["toggle-image-source"]
        reveal(imageSourceToggle, in: scroll, within: rootScroll)
        imageSourceToggle.tap()
        XCTAssertTrue(app.staticTexts["image recovered"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.images["unsupported-image"].label, "Unsupported image")
        let imageTintToggle = app.buttons["toggle-image-tint"]
        reveal(imageTintToggle, in: rootScroll)
        imageTintToggle.tap()
        XCTAssertTrue(app.staticTexts["image tint off"].waitForExistence(timeout: 5))
        let unsupportedValue = (app.images["unsupported-image"].value as? String) ?? ""
        XCTAssertEqual(unsupportedValue.components(separatedBy: "Unsupported image source").count - 1, 0)
        let clearImageSource = app.buttons["clear-image-source"]
        reveal(clearImageSource, in: scroll, within: rootScroll)
        clearImageSource.tap()
        XCTAssertTrue(waitForLabel(app.staticTexts["image-error-count"], "2"))
        reveal(imageTintToggle, in: rootScroll)
        imageTintToggle.tap()
        XCTAssertTrue(app.staticTexts["image tint on"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["image-error-count"].label, "2")
        XCTAssertTrue(app.otherElements["gradient-box"].waitForExistence(timeout: 5), "gradient fixture did not mount")
        let styleToggle = app.buttons["toggle-button-style"]
        reveal(styleToggle, in: rootScroll)
        XCTAssertFalse(styleToggle.isSelected)
        styleToggle.tap()
        XCTAssertTrue(app.staticTexts["button style accented"].waitForExistence(timeout: 5))
        XCTAssertTrue(styleToggle.isSelected)
        styleToggle.tap()
        XCTAssertTrue(app.staticTexts["button style default"].waitForExistence(timeout: 5))
        XCTAssertFalse(styleToggle.isSelected)
        let panelStyleToggle = app.buttons["toggle-panel-style"]
        reveal(panelStyleToggle, in: rootScroll)
        panelStyleToggle.tap()
        XCTAssertTrue(app.staticTexts["panel style off"].waitForExistence(timeout: 5))
        panelStyleToggle.tap()
        XCTAssertTrue(app.staticTexts["panel style on"].waitForExistence(timeout: 5))
        let nullWidthText = app.staticTexts["null-width-text"]
        XCTAssertTrue(nullWidthText.waitForExistence(timeout: 5))
        let explicitTextWidth = nullWidthText.frame.width
        XCTAssertGreaterThan(explicitTextWidth, 150)
        let nullWidthToggle = app.buttons["toggle-null-width"]
        reveal(nullWidthToggle, in: rootScroll)
        nullWidthToggle.tap()
        XCTAssertTrue(waitForLayoutDecrease(nullWidthText, from: explicitTextWidth), "null width should restore intrinsic text sizing")
        let scrollEnd = app.staticTexts["scroll-end"]
        reveal(scroll, in: rootScroll)
        XCTAssertFalse(scrollEnd.isHittable)
        scroll.swipeUp()
        XCTAssertTrue(scrollEnd.waitForExistence(timeout: 5))
        XCTAssertTrue(scrollEnd.isHittable, "native ScrollView did not reveal overflow content")

        let grid = app.otherElements["grid-wrap"]
        XCTAssertTrue(grid.waitForExistence(timeout: 5))
        let gridFirst = app.staticTexts["grid-first"]
        let gridSecond = app.staticTexts["grid-second"]
        let gridThird = app.staticTexts["grid-third"]
        XCTAssertTrue(gridFirst.exists && gridSecond.exists && gridThird.exists)
        XCTAssertEqual(gridFirst.frame.minY, gridSecond.frame.minY, accuracy: 2, "grid tracks did not share a row")
        XCTAssertGreaterThan(gridSecond.frame.minX, gridFirst.frame.minX, "grid columns did not lay out side by side")
        XCTAssertGreaterThan(gridThird.frame.minY, gridFirst.frame.minY, "grid rows did not advance after the first track")
        let templateRows = app.otherElements["grid-template-rows"]
        let templateFirst = app.otherElements["grid-template-rows-first"]
        let templateThird = app.otherElements["grid-template-rows-third"]
        XCTAssertTrue(templateRows.waitForExistence(timeout: 5) && templateFirst.exists && templateThird.exists)
        XCTAssertEqual(templateFirst.frame.height, templateThird.frame.height, accuracy: 2, "explicit grid rows did not use equal tracks")
        XCTAssertEqual(templateThird.frame.minY - templateFirst.frame.minY, 44, accuracy: 1, "explicit grid rows did not fill the definite height")
        let fractionalGrid = app.otherElements["grid-fractional-wrap"]
        let fractionalFirst = app.otherElements["grid-fractional-first"]
        let fractionalSecond = app.otherElements["grid-fractional-second"]
        let fractionalThird = app.otherElements["grid-fractional-third"]
        XCTAssertTrue(fractionalGrid.waitForExistence(timeout: 5) && fractionalFirst.exists && fractionalSecond.exists && fractionalThird.exists)
        XCTAssertEqual(fractionalFirst.frame.width, fractionalSecond.frame.width, accuracy: 1, "fractional grid tracks diverged")
        XCTAssertGreaterThan(fractionalSecond.frame.minX, fractionalFirst.frame.maxX, "fractional grid columns overlapped")
        XCTAssertLessThanOrEqual(fractionalThird.frame.maxX, fractionalGrid.frame.maxX + 1, "fractional grid overflowed its container")
        let gridAlign = app.otherElements["grid-align-wrap"]
        let gridAlignFirst = app.otherElements["grid-align-first"]
        let gridAlignThird = app.otherElements["grid-align-third"]
        XCTAssertTrue(gridAlign.waitForExistence(timeout: 5) && gridAlignFirst.exists && gridAlignThird.exists)
        XCTAssertGreaterThan(gridAlignFirst.frame.minY - gridAlign.frame.minY, 20, "grid alignContent did not center its rows")
        let gridAspect = app.otherElements["grid-aspect-ratio-box"]
        XCTAssertTrue(gridAspect.waitForExistence(timeout: 5))
        XCTAssertEqual(gridAspect.frame.width, 80, accuracy: 2)
        XCTAssertEqual(gridAspect.frame.height, 40, accuracy: 2, "grid aspectRatio did not derive height from width")
        let gridPercentHeight = app.otherElements["grid-percent-height"]
        XCTAssertTrue(gridPercentHeight.waitForExistence(timeout: 5))
        XCTAssertEqual(gridPercentHeight.frame.height, 40, accuracy: 2, "percentage grid height was not resolved against the container")
        let gridEvenly = app.otherElements["grid-align-evenly-wrap"]
        let gridEvenlyFirst = app.otherElements["grid-evenly-first"]
        let gridEvenlyThird = app.otherElements["grid-evenly-third"]
        XCTAssertTrue(gridEvenly.waitForExistence(timeout: 5) && gridEvenlyFirst.exists && gridEvenlyThird.exists)
        XCTAssertGreaterThan(gridEvenlyFirst.frame.minY - gridEvenly.frame.minY, 10, "grid space-evenly missed the leading slot")
        XCTAssertGreaterThan(gridEvenlyThird.frame.minY - gridEvenlyFirst.frame.minY, 35, "grid space-evenly missed the inter-row slot")
        let aspectRatioBox = app.otherElements["aspect-ratio-box"]
        XCTAssertTrue(aspectRatioBox.waitForExistence(timeout: 5))
        XCTAssertEqual(aspectRatioBox.frame.width, 100, accuracy: 2)
        XCTAssertEqual(aspectRatioBox.frame.height, 50, accuracy: 2, "aspectRatio did not derive height from width")
        let alignFirst = app.otherElements["align-content-first"]
        let alignThird = app.otherElements["align-content-third"]
        XCTAssertTrue(alignFirst.waitForExistence(timeout: 5) && alignThird.exists)
        XCTAssertGreaterThan(alignThird.frame.minY - alignFirst.frame.minY, 50, "alignContent did not distribute wrapped lines")
        let stretch = app.otherElements["align-content-stretch-wrap"]
        let stretchFirst = app.staticTexts["align-stretch-first"]
        let stretchThird = app.staticTexts["align-stretch-third"]
        XCTAssertTrue(stretch.waitForExistence(timeout: 5) && stretchFirst.exists && stretchThird.exists)
        XCTAssertGreaterThan(stretchFirst.frame.height, 35, "alignContent stretch did not expand the first line")
        XCTAssertGreaterThan(stretchThird.frame.minY, stretchFirst.frame.minY + 35, "alignContent stretch did not expand the line height")
        let evenly = app.otherElements["align-content-evenly-wrap"]
        let evenlyFirst = app.otherElements["align-evenly-first"]
        let evenlyThird = app.otherElements["align-evenly-third"]
        XCTAssertTrue(evenly.waitForExistence(timeout: 5) && evenlyFirst.exists && evenlyThird.exists)
        XCTAssertGreaterThan(evenlyFirst.frame.minY - evenly.frame.minY, 10, "alignContent space-evenly missed the leading slot")
        XCTAssertGreaterThan(evenlyThird.frame.minY - evenlyFirst.frame.minY, 35, "alignContent space-evenly missed the inter-line slot")
        let growFirst = app.staticTexts["flex-grow-first"]
        let growSecond = app.staticTexts["flex-grow-second"]
        XCTAssertTrue(growFirst.waitForExistence(timeout: 5))
        XCTAssertTrue(growSecond.exists)
        XCTAssertGreaterThan(growFirst.frame.width, growSecond.frame.width, "flexGrow did not consume remaining main-axis space")
        let capped = app.staticTexts["flex-bound-first"]
        let redistributed = app.staticTexts["flex-bound-second"]
        XCTAssertTrue(capped.waitForExistence(timeout: 5) && redistributed.exists)
        XCTAssertEqual(capped.frame.width, 64, accuracy: 2, "maxWidth did not freeze the capped flex item")
        XCTAssertGreaterThan(redistributed.frame.width, capped.frame.width + 40, "remaining flex space was not redistributed")
        let justifyCenter = app.otherElements["justify-center-wrap"]
        let justifyCenterFirst = app.staticTexts["justify-center-first"]
        let justifyCenterSecond = app.staticTexts["justify-center-second"]
        XCTAssertTrue(justifyCenter.waitForExistence(timeout: 5) && justifyCenterFirst.exists && justifyCenterSecond.exists)
        XCTAssertGreaterThan(justifyCenterFirst.frame.minX, justifyCenter.frame.minX + 20, "shared justify-center position was not applied")
        XCTAssertGreaterThan(justifyCenterSecond.frame.minX, justifyCenterFirst.frame.maxX, "shared justify-center gap was not applied")
        let justifyBetween = app.otherElements["justify-between-wrap"]
        let justifyBetweenFirst = app.staticTexts["justify-between-first"]
        let justifyBetweenSecond = app.staticTexts["justify-between-second"]
        XCTAssertTrue(justifyBetween.waitForExistence(timeout: 5) && justifyBetweenFirst.exists && justifyBetweenSecond.exists)
        XCTAssertLessThanOrEqual(justifyBetweenFirst.frame.minX, justifyBetween.frame.minX + 20, "shared space-between leading position was not applied")
        XCTAssertGreaterThanOrEqual(justifyBetweenSecond.frame.maxX, justifyBetween.frame.maxX - 20, "shared space-between trailing position was not applied")
        let crossAxis = app.otherElements["cross-axis-wrap"]
        let crossCenter = app.staticTexts["cross-axis-center"]
        let crossEnd = app.staticTexts["cross-axis-end"]
        XCTAssertTrue(crossAxis.waitForExistence(timeout: 5) && crossCenter.exists && crossEnd.exists)
        XCTAssertEqual(crossCenter.frame.midY, crossAxis.frame.midY, accuracy: 3, "alignItems center did not center the child")
        XCTAssertGreaterThan(crossEnd.frame.minY, crossCenter.frame.minY, "alignSelf flex-end did not move the child to the line end")
        let baseline = app.otherElements["baseline-wrap"]
        let baselineLarge = app.staticTexts["baseline-large"]
        let baselineSmall = app.staticTexts["baseline-small"]
        XCTAssertTrue(baseline.waitForExistence(timeout: 5) && baselineLarge.exists && baselineSmall.exists)
        XCTAssertLessThan(baselineLarge.frame.minY, baselineSmall.frame.minY, "baseline alignment did not lower the smaller label")
        let reverseColumnFirst = app.staticTexts["reverse-column-first"]
        let reverseColumnSecond = app.staticTexts["reverse-column-second"]
        XCTAssertTrue(reverseColumnFirst.waitForExistence(timeout: 5))
        XCTAssertTrue(reverseColumnSecond.exists)
        XCTAssertGreaterThan(reverseColumnFirst.frame.minY, reverseColumnSecond.frame.minY, "column-reverse did not invert the main axis")
        let reverseWrap = app.otherElements["reverse-wrap"]
        let reverseWrapFirst = app.staticTexts["reverse-wrap-first"]
        let reverseWrapSecond = app.staticTexts["reverse-wrap-second"]
        let reverseWrapThird = app.staticTexts["reverse-wrap-third"]
        let reverseWrapFourth = app.staticTexts["reverse-wrap-fourth"]
        XCTAssertTrue(reverseWrap.waitForExistence(timeout: 5) && reverseWrapFirst.exists && reverseWrapSecond.exists && reverseWrapThird.exists && reverseWrapFourth.exists)
        XCTAssertGreaterThan(reverseWrapFirst.frame.minX, reverseWrapSecond.frame.minX, "row-reverse did not reverse the first wrapped line")
        XCTAssertGreaterThan(reverseWrapThird.frame.minX, reverseWrapFourth.frame.minX, "row-reverse did not reverse the second wrapped line")
        XCTAssertGreaterThan(reverseWrapThird.frame.minY, reverseWrapFirst.frame.minY, "row-reverse reversed wrapped line order")
        XCTAssertLessThanOrEqual(reverseWrapFourth.frame.maxY, reverseWrap.frame.maxY, "row-reverse wrapped line escaped its container")

        let link = app.staticTexts["native-link"]
        reveal(link, in: rootScroll)
        XCTAssertEqual(link.label, "Open native link")
        XCTAssertEqual(link.value as? String, "ready")
        link.tap()
        XCTAssertTrue(app.staticTexts["link pressed"].waitForExistence(timeout: 5))
        let accessibilityToggle = app.buttons["toggle-link-accessibility"]
        reveal(accessibilityToggle, in: rootScroll)
        accessibilityToggle.tap()
        XCTAssertTrue(app.staticTexts["link accessibility disabled"].waitForExistence(timeout: 5))
        XCTAssertFalse(link.isEnabled)
        accessibilityToggle.tap()
        XCTAssertTrue(app.staticTexts["link accessibility enabled"].waitForExistence(timeout: 5))
        XCTAssertTrue(link.isEnabled, "clearing accessibilityState.disabled should restore the link")
        link.tap()
        XCTAssertTrue(app.staticTexts["link pressed"].waitForExistence(timeout: 5))

        let panel = app.otherElements["native-panel"]
        reveal(panel, in: rootScroll)
        panel.tap()
        XCTAssertTrue(app.staticTexts["panel pressed"].waitForExistence(timeout: 5))
        let panelAccessibilityToggle = app.buttons["toggle-panel-accessibility"]
        reveal(panelAccessibilityToggle, in: rootScroll)
        panelAccessibilityToggle.tap()
        XCTAssertTrue(app.staticTexts["panel accessibility disabled"].waitForExistence(timeout: 5))
        panelAccessibilityToggle.tap()
        XCTAssertTrue(app.staticTexts["panel accessibility enabled"].waitForExistence(timeout: 5))
        XCTAssertTrue(panel.isEnabled, "clearing accessibilityState.disabled should restore a generic pressable")
        panel.tap()
        XCTAssertTrue(app.staticTexts["panel pressed"].waitForExistence(timeout: 5))
        let pressable = app.buttons["native-pressable"]
        reveal(pressable, in: rootScroll)
        // Earlier reveal drags may start on the pressable and legitimately
        // deliver a cancelled press-in/out pair. Assert this tap's delta.
        let lifecycle = app.staticTexts["pressable-lifecycle"]
        let counts = lifecycle.label.replacingOccurrences(of: "Press lifecycle: ", with: "")
            .split(separator: "/").compactMap { Int($0) }
        XCTAssertEqual(counts.count, 2)
        let pressesIn = try XCTUnwrap(counts.first)
        let pressesOut = try XCTUnwrap(counts.last)
        pressable.tap()
        XCTAssertTrue(app.staticTexts["pressable pressed"].waitForExistence(timeout: 5))
        XCTAssertEqual(lifecycle.label, "Press lifecycle: \(pressesIn + 1)/\(pressesOut + 1)")
        let disabledPressable = app.buttons["disabled-pressable"]
        XCTAssertTrue(disabledPressable.waitForExistence(timeout: 5))
        XCTAssertFalse(disabledPressable.isEnabled)
        let longPressPanel = app.otherElements["long-press-panel"]
        reveal(longPressPanel, in: rootScroll)
        longPressPanel.press(forDuration: 1)
        XCTAssertTrue(app.staticTexts["panel long pressed"].waitForExistence(timeout: 5))
        let longPressAccessibilityToggle = app.buttons["toggle-long-press-accessibility"]
        reveal(longPressAccessibilityToggle, in: rootScroll)
        longPressAccessibilityToggle.tap()
        XCTAssertTrue(app.staticTexts["long press disabled"].waitForExistence(timeout: 5))
        // Disabled reads as not enabled; XCUITest still finds a hit point on
        // a disabled element, as it does for a disabled UIButton.
        XCTAssertFalse(longPressPanel.isEnabled)
        longPressAccessibilityToggle.tap()
        XCTAssertTrue(app.staticTexts["long press enabled"].waitForExistence(timeout: 5))
        longPressPanel.press(forDuration: 1)
        XCTAssertTrue(app.staticTexts["panel long pressed"].waitForExistence(timeout: 5))
        XCTAssertTrue(link.isEnabled)
        link.tap()
        XCTAssertTrue(app.staticTexts["link pressed"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["justified-text"].waitForExistence(timeout: 5))

        let toggle = app.switches["native-switch"]
        reveal(toggle, in: rootScroll)
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertTrue(toggle.isEnabled)
        XCTAssertEqual(app.switches["nullable-switch"].value as? String, "1")
        XCTAssertEqual(app.switches["switch-value-precedence"].value as? String, "0")
        toggle.tap()
        XCTAssertTrue(app.staticTexts["switch on"].waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "1")

        // A <select> is a UIPickerView, which XCUITest types as a picker.
        XCTAssertTrue(app.pickers["native-picker"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["picker-value"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["picker-value"].label, "one")
        // The picker's first selection is not a change: the shared status
        // still says what the switch just did.
        XCTAssertEqual(app.staticTexts["native-link-status"].label, "switch on")
        let itemsPicker = app.pickers["native-items-picker"]
        XCTAssertTrue(itemsPicker.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["items-picker-value"].label, "one")
        XCTAssertEqual(itemsPicker.value as? String, "One item")
        let modalToggle = app.buttons["toggle-modal"]
        reveal(modalToggle, in: rootScroll)
        modalToggle.tap()
        XCTAssertTrue(app.otherElements["native-modal"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["modal-content"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["modal shown"].waitForExistence(timeout: 5))
        // Numeric text keeps the same compact representation on both native hosts.
        XCTAssertEqual(app.staticTexts["modal-opacity"].label, "1")
        app.buttons["toggle-modal-opacity"].tap()
        XCTAssertTrue(waitForLabel(app.staticTexts["modal-opacity"], "0.45"))
        // The scrim reports why it requested the close; the visible modal
        // then reconciles away and emits its ordinary dismiss lifecycle.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["modal requested backdrop"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["modal dismissed"].waitForExistence(timeout: 5))

        let slider = app.sliders["native-slider"]
        reveal(slider, in: rootScroll)
        slider.adjust(toNormalizedSliderPosition: 0.8)
        XCTAssertTrue(app.staticTexts["slider moved"].waitForExistence(timeout: 5))
        // XCUITest lands within a step of where it is asked to (0.8 or 0.9
        // here); the script hears the step the slider shows, as a decimal.
        let shownPercent = Double((slider.value as? String ?? "").replacingOccurrences(of: "%", with: "")) ?? -1
        let shownSteps = (shownPercent / 10).rounded()
        let shown = shownSteps / 10
        // Compare whole native steps: 0.8 - 0.7 rounds just above 0.1
        // in binary floating point, although it is the permitted one step.
        XCTAssertLessThanOrEqual(abs(shownSteps - 8), 1, "slider landed at \(shownPercent)%")
        XCTAssertEqual(app.staticTexts["slider-value"].label, shown == shown.rounded() ? String(Int(shown)) : String(shown))
        XCTAssertEqual(app.staticTexts["slider-completions"].label, "Slider completions: 1")
        let booleanSlider = app.sliders["boolean-slider"]
        XCTAssertTrue(booleanSlider.waitForExistence(timeout: 5))
        XCTAssertTrue((booleanSlider.value as? String ?? "").contains("50%"), "Boolean slider minimum was treated as numeric")

        XCTAssertTrue(app.activityIndicators["native-indicator"].waitForExistence(timeout: 5))
        let booleanIndicator = app.activityIndicators["boolean-indicator"]
        XCTAssertTrue(booleanIndicator.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(booleanIndicator.frame.width, 12, "Boolean ActivityIndicator size was treated as numeric")
        XCTAssertTrue(app.activityIndicators["stopped-indicator"].waitForExistence(timeout: 5))
        let stoppedIndicator = app.activityIndicators["stopped-indicator"]
        let toggleIndicatorHide = app.buttons["toggle-indicator-hide"]
        reveal(toggleIndicatorHide, in: rootScroll)
        toggleIndicatorHide.tap()
        XCTAssertFalse(stoppedIndicator.isHittable, "a stopped indicator should hide when the prop changes dynamically")
        toggleIndicatorHide.tap()
        XCTAssertTrue(stoppedIndicator.isHittable, "a stopped indicator should reappear when hidesWhenStopped is cleared")
        XCTAssertFalse(app.activityIndicators["hidden-indicator"].isHittable)
        // display:none hides the view, and a hidden view is not in the
        // accessibility tree at all (Android checks View.GONE instead).
        XCTAssertFalse(app.activityIndicators["display-none-indicator"].exists)

        let wrapped = app.otherElements["layout-wrap"]
        XCTAssertTrue(wrapped.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Layout width: 240"].waitForExistence(timeout: 5), "native onLayout did not report a frame")
        let layoutWidthToggle = app.buttons["toggle-layout-width"]
        reveal(layoutWidthToggle, in: rootScroll)
        layoutWidthToggle.tap()
        XCTAssertTrue(app.staticTexts["Layout width: 180"].waitForExistence(timeout: 5), "native onLayout did not report the responsive width")
        XCTAssertTrue(app.staticTexts["Transformed layout width: 100"].waitForExistence(timeout: 5), "onLayout must report the untransformed layout width")
        XCTAssertTrue(app.staticTexts["Hidden layout events: 0"].waitForExistence(timeout: 5), "hidden descendants must not emit onLayout")
        let bounded = app.staticTexts["layout-min"]
        XCTAssertTrue(bounded.exists)
        XCTAssertEqual(bounded.frame.width, 140, accuracy: 2, "maxWidth was not applied")
        let absoluteRatio = app.otherElements["layout-absolute-ratio"]
        XCTAssertTrue(absoluteRatio.waitForExistence(timeout: 5))
        XCTAssertEqual(absoluteRatio.frame.width, 156, accuracy: 2, "absolute left/right anchors were not resolved")
        XCTAssertEqual(absoluteRatio.frame.height, 39, accuracy: 2, "absolute aspect ratio was not resolved from anchored width")
        let absoluteHeightRatio = app.otherElements["layout-absolute-height-ratio"]
        XCTAssertTrue(absoluteHeightRatio.waitForExistence(timeout: 5))
        XCTAssertEqual(absoluteHeightRatio.frame.width, 40, accuracy: 2, "absolute aspect ratio did not derive width from authored height")
        XCTAssertEqual(absoluteHeightRatio.frame.height, 20, accuracy: 2, "absolute authored height was not preserved")
        let percentWidth = app.staticTexts["percent-width"]
        XCTAssertTrue(percentWidth.waitForExistence(timeout: 5))
        XCTAssertEqual(percentWidth.frame.width, 120, accuracy: 2, "percentage width was not resolved against the parent")
        let percentBasisFirst = app.staticTexts["percent-basis-first"]
        let percentBasisSecond = app.staticTexts["percent-basis-second"]
        XCTAssertTrue(percentBasisFirst.waitForExistence(timeout: 5))
        XCTAssertTrue(percentBasisSecond.waitForExistence(timeout: 5))
        XCTAssertEqual(percentBasisFirst.frame.width, 120, accuracy: 2, "percentage flex-basis was not resolved on the first child")
        XCTAssertEqual(percentBasisSecond.frame.width, 120, accuracy: 2, "percentage flex-basis was not resolved on the second child")
        let independentGapFirst = app.staticTexts["independent-gap-first"]
        let independentGapSecond = app.staticTexts["independent-gap-second"]
        let independentGapThird = app.staticTexts["independent-gap-third"]
        XCTAssertTrue(independentGapThird.waitForExistence(timeout: 5))
        XCTAssertEqual(independentGapSecond.frame.minX - independentGapFirst.frame.minX, 50, accuracy: 2, "column gap was not shared through the native layout ABI")
        XCTAssertEqual(independentGapThird.frame.minY - independentGapFirst.frame.minY, 22, accuracy: 2, "row gap was not shared through the native layout ABI")
        let nestedSharedFirst = app.staticTexts["nested-shared-first"]
        let nestedSharedSecond = app.staticTexts["nested-shared-second"]
        let nestedSharedSibling = app.otherElements["nested-shared-sibling"]
        XCTAssertTrue(nestedSharedSecond.waitForExistence(timeout: 5))
        XCTAssertEqual(nestedSharedSecond.frame.minY - nestedSharedFirst.frame.minY, 18, accuracy: 2, "nested column gap was not preserved")
        XCTAssertEqual(nestedSharedSibling.frame.minX - app.otherElements["nested-shared-column"].frame.minX, 80, accuracy: 2, "nested row gap was not preserved")
        let nestedPercentParent = app.otherElements["nested-percent-parent"]
        let nestedPercentChild = app.otherElements["nested-percent-child"]
        XCTAssertTrue(nestedPercentChild.waitForExistence(timeout: 5))
        XCTAssertEqual(nestedPercentParent.frame.width, 80, accuracy: 2)
        XCTAssertEqual(nestedPercentChild.frame.width, 36, accuracy: 2, "nested percentage width used the outer parent")
        XCTAssertEqual(nestedPercentChild.frame.height, 26, accuracy: 2, "nested percentage height used the outer parent")
        let booleanWidthText = app.staticTexts["boolean-width-text"]
        XCTAssertTrue(booleanWidthText.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(booleanWidthText.frame.width, 20, "boolean width was treated as a numeric layout length")
        let booleanFontSizeText = app.staticTexts["boolean-font-size-text"]
        XCTAssertTrue(booleanFontSizeText.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(booleanFontSizeText.frame.height, 10, "boolean font size was treated as a numeric style")
        let booleanNumberLines = app.staticTexts["boolean-number-lines"]
        XCTAssertTrue(booleanNumberLines.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(booleanNumberLines.frame.height, 24, "boolean numberOfLines was treated as numeric")
        let nestedShrinkRowText = app.staticTexts["nested-shrink-row-text"]
        let nestedShrinkColumnText = app.staticTexts["nested-shrink-column-text"]
        XCTAssertTrue(nestedShrinkColumnText.waitForExistence(timeout: 5))
        XCTAssertEqual(nestedShrinkRowText.frame.width, 60, accuracy: 2, "nested horizontal text did not use its parent flex-shrink default")
        XCTAssertEqual(nestedShrinkColumnText.frame.height, 80, accuracy: 2, "nested vertical text incorrectly used a horizontal flex-shrink default")
        let nestedGridFirst = app.otherElements["nested-grid-first"]
        let nestedGridSecond = app.otherElements["nested-grid-second"]
        let nestedGridThird = app.otherElements["nested-grid-third"]
        let nestedGridSibling = app.otherElements["nested-grid-sibling"]
        XCTAssertTrue(nestedGridThird.waitForExistence(timeout: 5))
        XCTAssertEqual(nestedGridSecond.frame.minX - nestedGridFirst.frame.minX, 52, accuracy: 2, "nested grid columns were not shared through the tree ABI")
        XCTAssertEqual(nestedGridThird.frame.minY - nestedGridFirst.frame.minY, 26, accuracy: 2, "nested grid rows were not shared through the tree ABI")
        XCTAssertEqual(nestedGridSibling.frame.minX - app.otherElements["nested-grid"].frame.minX, 110, accuracy: 2, "nested grid parent placement was not preserved")
        let nestedReverseFirst = app.staticTexts["nested-reverse-first"]
        let nestedReverseSecond = app.staticTexts["nested-reverse-second"]
        let nestedReverseSibling = app.otherElements["nested-reverse-sibling"]
        XCTAssertTrue(nestedReverseSecond.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(nestedReverseFirst.frame.minY, nestedReverseSecond.frame.minY, "nested reverse flow did not use the shared v2 tree ABI")
        XCTAssertEqual(nestedReverseSibling.frame.minX - app.otherElements["nested-reverse"].frame.minX, 56, accuracy: 2, "nested reverse parent placement was not preserved")
        let nestedWrapReverseFirst = app.staticTexts["nested-wrap-reverse-first"]
        let nestedWrapReverseSecond = app.staticTexts["nested-wrap-reverse-second"]
        let nestedWrapReverseSibling = app.otherElements["nested-wrap-reverse-sibling"]
        XCTAssertTrue(nestedWrapReverseSecond.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(nestedWrapReverseFirst.frame.minY, nestedWrapReverseSecond.frame.minY, "nested wrap-reverse flow did not use the shared v3 tree ABI")
        XCTAssertEqual(nestedWrapReverseSibling.frame.minX - app.otherElements["nested-wrap-reverse"].frame.minX, 56, accuracy: 2, "nested wrap-reverse parent placement was not preserved")
        let absolute = app.otherElements["layout-absolute"]
        XCTAssertTrue(absolute.exists)
        XCTAssertLessThanOrEqual(absolute.frame.maxX, wrapped.frame.maxX - 8)
        XCTAssertLessThanOrEqual(absolute.frame.maxY, wrapped.frame.maxY - 8)

        let field = app.textFields["name-input"]
        reveal(field, in: rootScroll)
        XCTAssertTrue(field.isEnabled)
        let booleanMaxLength = app.textFields["boolean-max-length"]
        XCTAssertTrue(booleanMaxLength.waitForExistence(timeout: 5))
        booleanMaxLength.tap()
        booleanMaxLength.typeText("AB")
        XCTAssertEqual(booleanMaxLength.value as? String, "AB", "Boolean maxLength was treated as numeric")
        let booleanInputLines = app.textViews["boolean-input-lines"]
        XCTAssertTrue(booleanInputLines.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(booleanInputLines.frame.height, 24, "Boolean TextInput numberOfLines was treated as numeric")
        let notes = app.textViews["notes-input"]
        XCTAssertTrue(notes.waitForExistence(timeout: 5), "multiline TextInput did not render as UITextView")
        XCTAssertTrue(notes.isEnabled)
        XCTAssertEqual(notes.value as? String, "Draft", "defaultValue was not applied to the native text view")
        let initialNotesHeight = notes.frame.height
        let inputPaddingToggle = app.buttons["toggle-input-padding"]
        reveal(inputPaddingToggle, in: rootScroll)
        inputPaddingToggle.tap()
        let expandedNotes = XCTNSPredicateExpectation(predicate: NSPredicate { object, _ in
            guard let candidate = object as? XCUIElement else { return false }
            return candidate.frame.height > initialNotesHeight + 1
        }, object: notes)
        XCTAssertEqual(XCTWaiter.wait(for: [expandedNotes], timeout: 10), .completed, "multiline input padding was not applied")
        inputPaddingToggle.tap()
        let restoredNotes = XCTNSPredicateExpectation(predicate: NSPredicate { object, _ in
            guard let candidate = object as? XCUIElement else { return false }
            return abs(candidate.frame.height - initialNotesHeight) <= 1
        }, object: notes)
        XCTAssertEqual(XCTWaiter.wait(for: [restoredNotes], timeout: 10), .completed, "multiline input padding was retained after removal")
        let readonly = app.textFields["readonly-input"]
        XCTAssertTrue(readonly.waitForExistence(timeout: 5))
        XCTAssertFalse(readonly.isEnabled)
        XCTAssertEqual(readonly.value as? String, "Read only")
        let password = app.secureTextFields["password-input"]
        XCTAssertTrue(password.waitForExistence(timeout: 5))
        let inputColorsToggle = app.buttons["toggle-input-colors"]
        reveal(inputColorsToggle, in: rootScroll)
        inputColorsToggle.tap()
        XCTAssertTrue(app.staticTexts["input colors off"].waitForExistence(timeout: 5))
        XCTAssertTrue(field.exists, "removing input colors replaced the native field")
        inputColorsToggle.tap()
        XCTAssertTrue(app.staticTexts["input colors on"].waitForExistence(timeout: 5))
        XCTAssertTrue(field.exists, "restoring input colors replaced the native field")
        field.tap()
        XCTAssertTrue(app.staticTexts["Focuses: 1"].waitForExistence(timeout: 5))
        field.typeText("Ada")
        XCTAssertEqual(app.staticTexts["greeting"].label, "Hello Ada")
        field.typeText("\n")
        XCTAssertEqual(app.staticTexts["name-submits"].label, "Submits: 1")
        notes.tap()
        XCTAssertTrue(app.staticTexts["notes-focus-text"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["notes-focus-text"].label, "Notes focus: Draft")
        let nameBlurs = app.staticTexts["name-blurs"]
        XCTAssertTrue(nameBlurs.waitForExistence(timeout: 5))
        XCTAssertEqual(nameBlurs.label, "Blurs: 1")
        let nameEndEditings = app.staticTexts["name-end-editings"]
        XCTAssertTrue(nameEndEditings.waitForExistence(timeout: 5))
        XCTAssertEqual(nameEndEditings.label, "End edits: 1")
        let nameModeToggle = app.buttons["toggle-name-mode"]
        reveal(nameModeToggle, in: rootScroll)
        nameModeToggle.tap()
        let multilineField = app.textViews["name-input"]
        XCTAssertTrue(multilineField.waitForExistence(timeout: 5))
        XCTAssertEqual(multilineField.value as? String, "Ada")
        XCTAssertEqual(app.staticTexts["name-mode"].label, "multiline")
        nameModeToggle.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "Ada")
        XCTAssertEqual(app.staticTexts["name-mode"].label, "single-line")
        notes.typeText("Note")
        notes.typeText("\n")
        XCTAssertEqual(app.staticTexts["name-submits"].label, "Submits: 2")
        let increment = app.buttons["increment"]
        reveal(increment, in: rootScroll)
        // A tap on nothing puts the keyboard away (Android clears the focus
        // here); a button would keep it.
        app.staticTexts["notes-blurs"].tap()
        let notesBlurs = app.staticTexts["notes-blurs"]
        XCTAssertTrue(notesBlurs.waitForExistence(timeout: 5))
        XCTAssertEqual(notesBlurs.label, "Notes blurs: 1")
        let notesEndEditings = app.staticTexts["notes-end-editings"]
        XCTAssertTrue(notesEndEditings.waitForExistence(timeout: 5))
        XCTAssertEqual(notesEndEditings.label, "Notes end edits: 1")
        increment.tap()
        increment.tap()
        XCTAssertTrue(waitForLabel(app.staticTexts["count"], "Count: 2"))

        let openDetails = app.buttons["open-details"]
        reveal(openDetails, in: rootScroll)
        openDetails.tap()
        XCTAssertTrue(app.staticTexts["details-title"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["details-title"].label, "Details for Ada")
        XCTAssertEqual(app.staticTexts["details-count"].label, "Count: 2")
        let people = app.scrollViews["people-list"]
        XCTAssertTrue(people.waitForExistence(timeout: 10))
        let peopleCount = app.staticTexts["people-count"]
        people.swipeDown()
        XCTAssertTrue(waitForLabel(peopleCount, "People: 40; events: 1"), "ScrollView pull-to-refresh did not invoke onRefresh")
        let peopleHeader = app.staticTexts["people-header"]
        XCTAssertTrue(peopleHeader.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(peopleHeader.frame.minY, people.frame.minY + 8, "ScrollView contentContainerStyle did not add top padding")
        let peopleLayouts = app.staticTexts["people-layout-status"]
        XCTAssertTrue(peopleLayouts.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForLayoutIncrease(peopleLayouts, from: 0), "rows did not report their initial layout")
        let initialRowLayouts = layoutCount(peopleLayouts)
        XCTAssertGreaterThan(initialRowLayouts, 0)
        XCTAssertTrue(app.textFields["person-input-person-0"].waitForExistence(timeout: 5))
        let personInput = app.textFields["person-input-person-0"]
        reveal(personInput, in: people)
        personInput.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "the row input did not open its keyboard")
        personInput.typeText("draft")
        app.buttons["shuffle-people"].tap()
        let firstPerson = app.staticTexts["person-label-person-0"]
        XCTAssertTrue(waitForLabel(firstPerson, "1: Person zero updated"))
        XCTAssertEqual(personInput.value as? String, "draft")
        app.buttons["load-more-people"].tap()
        XCTAssertTrue(
            waitForLabel(peopleCount, "People: 41; events: 3"),
            "ScrollView load-more action did not update its data; found \(peopleCount.label)"
        )
        XCTAssertTrue(
            waitForLayoutIncrease(peopleLayouts, from: initialRowLayouts),
            "ScrollView did not report a row layout after insertion; found \(peopleLayouts.label)"
        )
        people.swipeDown()
        let recycledPersonInput = app.textFields["person-input-person-0"]
        XCTAssertTrue(recycledPersonInput.waitForExistence(timeout: 5))
        XCTAssertEqual(recycledPersonInput.value as? String, "draft")
        app.buttons["clear-people"].tap()
        XCTAssertTrue(app.staticTexts["people-empty"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["people-footer"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitForLabel(peopleCount, "People: 0; events: 4"))
        XCTAssertTrue(app.navigationBars.buttons.firstMatch.exists, "UIKit did not provide a back button")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertEqual(field.value as? String, "Ada")
        XCTAssertEqual(app.staticTexts["count"].label, "Count: 2")

        reveal(openDetails, in: rootScroll)
        openDetails.tap()
        XCTAssertTrue(app.staticTexts["details-title"].waitForExistence(timeout: 10))
        app.buttons["details-back"].tap()
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertEqual(field.value as? String, "Ada")

        reveal(openDetails, in: rootScroll)
        openDetails.tap()
        XCTAssertTrue(app.staticTexts["details-title"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.navigationBars.buttons.firstMatch.waitForExistence(timeout: 5))
        for y in [0.2, 0.5, 0.8] where !field.exists {
            let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.005, dy: y))
            let farEdge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: y))
            edge.press(forDuration: 0.1, thenDragTo: farEdge)
            if field.waitForExistence(timeout: 3) { break }
        }
        XCTAssertTrue(field.waitForExistence(timeout: 5), "edge-swipe did not navigate back")
        XCTAssertEqual(field.value as? String, "Ada")

        reveal(openDetails, in: rootScroll)
        openDetails.tap()
        XCTAssertTrue(app.staticTexts["details-title"].waitForExistence(timeout: 10))
        app.buttons["open-summary"].tap()
        XCTAssertTrue(app.staticTexts["summary-title"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["summary-title"].label, "Summary for Ada")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 10), "replace left details on the stack")
        XCTAssertEqual(field.value as? String, "Ada")
        XCTAssertEqual(app.staticTexts["count"].label, "Count: 2")
    }

    func testNativeAppearanceReconcilesTraitDefaults() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertFalse(app.webViews.firstMatch.exists, "native appearance fixture created a WebView")
        let probe = app.otherElements["theme-probe"]
        XCTAssertTrue(probe.waitForExistence(timeout: 15), "theme probe did not mount")
        XCTAssertTrue(app.staticTexts["theme-probe-label"].exists, "theme probe label did not mount")

        let device = XCUIDevice.shared
        let original = device.appearance
        defer { device.appearance = original }
        device.appearance = original == .dark ? .light : .dark

        XCTAssertTrue(probe.waitForExistence(timeout: 5), "theme probe disappeared during trait refresh")
        XCTAssertTrue(app.staticTexts["theme-probe-label"].waitForExistence(timeout: 5), "theme probe label disappeared during trait refresh")
    }

    func testModalBackdropReportsDismissReason() {
        let app = XCUIApplication()
        app.launch()
        let rootScroll = app.scrollViews["native-root-scroll"]
        XCTAssertTrue(rootScroll.waitForExistence(timeout: 15))
        let modalToggle = app.buttons["toggle-modal"]
        reveal(modalToggle, in: rootScroll)
        modalToggle.tap()
        XCTAssertTrue(app.otherElements["native-modal"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["modal shown"].waitForExistence(timeout: 5))

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["modal requested backdrop"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["modal dismissed"].waitForExistence(timeout: 5))
    }
}
