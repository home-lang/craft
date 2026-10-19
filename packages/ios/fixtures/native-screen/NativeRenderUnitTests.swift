import Combine
import UIKit
import MapKit
import CoreLocation
import XCTest
@testable import NativeRender

private final class UnitLocationManager: CLLocationManager {
    var state: CLAuthorizationStatus = .notDetermined
    var whenInUseRequests = 0
    var alwaysRequests = 0
    var fixRequests = 0
    var onAuthorizationRequest: (() -> Void)?
    override var authorizationStatus: CLAuthorizationStatus { state }
    override func requestWhenInUseAuthorization() { whenInUseRequests += 1; onAuthorizationRequest?() }
    override func requestAlwaysAuthorization() { alwaysRequests += 1; onAuthorizationRequest?() }
    override func requestLocation() { fixRequests += 1 }
}

@MainActor
final class NativeRenderUnitTests: XCTestCase {
    func testPresenterRectRejectsBooleanCoordinatesAndNonFiniteNumbers() {
        XCTAssertNil(CraftPresenter.rect(["x": true, "y": 20, "width": 30, "height": 40]))
        XCTAssertNil(CraftPresenter.rect(["x": 10, "y": false, "width": 30, "height": 40]))
        XCTAssertNil(CraftPresenter.rect(["x": Double.nan, "y": 20, "width": 30, "height": 40]))
        XCTAssertEqual(CraftPresenter.rect(["x": 10, "y": 20, "width": 30, "height": 40]), CGRect(x: 10, y: 20, width: 30, height: 40))
        XCTAssertEqual(CraftPresenter.rect(["x": 10, "y": 20, "width": true, "height": false]), CGRect(x: 10, y: 20, width: 0, height: 0))
    }

    func testOneShotLocationWaitsForPermissionBeforeStartingItsFixAndTimeout() throws {
        var config = CraftConfig()
        config.enableGeolocation = true
        config.enableBackgroundLocation = true
        let manager = UnitLocationManager()
        let coordinator = CraftWebView.Coordinator(config: config, locationManager: manager)
        let previous = CraftSwiftShim.coordinator
        CraftSwiftShim.coordinator = coordinator
        defer { CraftSwiftShim.coordinator = previous }
        let permission = expectation(description: "foreground location permission requested")
        manager.onAuthorizationRequest = { permission.fulfill() }
        let completed = expectation(description: "authorized native fix delivered")
        var answer: Result<Any, CraftNativeActionError>?
        CraftWebServices.perform(action: "getCurrentPosition", body: ["timeout": 20]) { result in
            answer = result
            completed.fulfill()
        }
        wait(for: [permission], timeout: 2)
        XCTAssertEqual(manager.whenInUseRequests, 1)
        XCTAssertEqual(manager.alwaysRequests, 0, "One foreground fix does not ask for background access")
        XCTAssertEqual(manager.fixRequests, 0)
        coordinator.locationManager(manager, didFailWithError: NSError(domain: kCLErrorDomain, code: CLError.Code.denied.rawValue))
        let deciding = expectation(description: "person is still reading the permission sheet")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { deciding.fulfill() }
        wait(for: [deciding], timeout: 2)
        XCTAssertNil(answer, "The acquisition timeout excludes time spent deciding permission")
        manager.state = .authorizedWhenInUse
        coordinator.locationManagerDidChangeAuthorization(manager)
        XCTAssertEqual(manager.fixRequests, 1)
        coordinator.locationManagerDidChangeAuthorization(manager)
        XCTAssertEqual(manager.fixRequests, 1, "Repeated authorization notifications do not restart acquisition")
        coordinator.locationManager(manager, didUpdateLocations: [CLLocation(latitude: 34, longitude: -118)])
        wait(for: [completed], timeout: 2)
        guard case .success(let value)? = answer else { return XCTFail("Expected an authorized native fix") }
        XCTAssertEqual((value as? [String: Any])?["latitude"] as? Double, 34)
    }

    func testOneShotLocationRejectsDeniedPermissionWithoutRequestingAFix() {
        for status in [CLAuthorizationStatus.denied, .restricted] {
            var config = CraftConfig()
            config.enableGeolocation = true
            let manager = UnitLocationManager()
            manager.state = status
            let coordinator = CraftWebView.Coordinator(config: config, locationManager: manager)
            let previous = CraftSwiftShim.coordinator
            CraftSwiftShim.coordinator = coordinator
            let completed = expectation(description: "denied native request settled")
            CraftWebServices.perform(action: "getCurrentPosition", body: [:]) { result in
                guard case .failure(let error) = result else { completed.fulfill(); return XCTFail("Denied permission returned a fix") }
                XCTAssertEqual(error.code, "PERMISSION_DENIED")
                completed.fulfill()
            }
            wait(for: [completed], timeout: 2)
            XCTAssertEqual(manager.fixRequests, 0)
            XCTAssertEqual(manager.whenInUseRequests, 0)
            CraftSwiftShim.coordinator = previous
        }
    }

    func testOneShotLocationRejectsWhenPermissionPromptIsDeclined() {
        var config = CraftConfig()
        config.enableGeolocation = true
        let manager = UnitLocationManager()
        let coordinator = CraftWebView.Coordinator(config: config, locationManager: manager)
        let previous = CraftSwiftShim.coordinator
        CraftSwiftShim.coordinator = coordinator
        defer { CraftSwiftShim.coordinator = previous }
        let permission = expectation(description: "foreground permission requested")
        manager.onAuthorizationRequest = { permission.fulfill() }
        let completed = expectation(description: "declined native request settled")
        CraftWebServices.perform(action: "getCurrentPosition", body: [:]) { result in
            guard case .failure(let error) = result else { completed.fulfill(); return XCTFail("Declined permission returned a fix") }
            XCTAssertEqual(error.code, "PERMISSION_DENIED")
            completed.fulfill()
        }
        wait(for: [permission], timeout: 2)
        manager.state = .denied
        coordinator.locationManagerDidChangeAuthorization(manager)
        wait(for: [completed], timeout: 2)
        XCTAssertEqual(manager.fixRequests, 0)
    }

    func testPanProgressDoesNotInvalidateTheWholeChrome() {
        let chrome = CraftChrome.shared
        let tabs = chrome.tabs
        let selected = chrome.selected
        defer {
            chrome.cancelTabSwipe()
            chrome.tabs = tabs
            chrome.selected = selected
        }
        chrome.tabs = [CraftChrome.Tab(id: "/today", title: "Today", symbol: "house", badge: nil), CraftChrome.Tab(id: "/health", title: "Health", symbol: "heart", badge: nil)]
        chrome.selected = "/today"
        chrome.beginTabSwipe(to: "/health", from: "/today")
        var chromeChanges = 0
        var indicatorChanges = 0
        let chromeSubscription = chrome.objectWillChange.sink { chromeChanges += 1 }
        let indicatorSubscription = chrome.tabSwipeProgress.objectWillChange.sink { indicatorChanges += 1 }
        defer { chromeSubscription.cancel(); indicatorSubscription.cancel() }
        for frame in 1...120 { chrome.updateTabSwipe(progress: CGFloat(frame) / 120) }
        XCTAssertEqual(chromeChanges, 0, "tracking must leave tab content, material and splash alone")
        XCTAssertEqual(indicatorChanges, 120)
        XCTAssertEqual(chrome.tabSwipePosition, 1)
        chrome.updateTabSwipe(progress: 1)
        XCTAssertEqual(indicatorChanges, 120, "equal pan positions do not redraw")
        chrome.cancelTabSwipe()
        XCTAssertNil(chrome.tabSwipePosition)
        XCTAssertEqual(chrome.selected, "/today")
    }

    func testLiveTabReadingPublishesOnceAndEqualReadingsDoNotRedrawChrome() {
        let chrome = CraftChrome.shared
        let previous = chrome.tabs
        defer { chrome.tabs = previous }
        chrome.tabs = [CraftChrome.Tab(id: "/health", title: "Health", symbol: "heart", badge: nil)]
        var publications = 0
        let subscription = chrome.objectWillChange.sink { publications += 1 }
        defer { subscription.cancel() }
        let reading: [String: Any] = ["id": "/health", "title": "123 bpm", "iconText": NSNull(), "iconTint": "#ff3b30", "iconPulse": true, "accessibilityLabel": "Health, 123 bpm"]
        chrome.updateTab(reading)
        XCTAssertEqual(publications, 1, "all fields of one reading are committed together")
        for _ in 0..<120 { chrome.updateTab(reading) }
        XCTAssertEqual(publications, 1, "repeated readings must not invalidate SwiftUI during scrolling")
        chrome.updateTab(["id": "/health", "title": NSNull(), "iconTint": NSNull(), "iconPulse": false, "accessibilityLabel": NSNull()])
        XCTAssertEqual(publications, 2)
        XCTAssertEqual(chrome.tabs[0].displayTitle, "Health")
        XCTAssertFalse(chrome.tabs[0].iconPulse)
    }

    func testConfiguredHomeShortcutUsesTheNativeAppDestination() throws {
        let shortcut = try XCTUnwrap(UIApplication.shared.shortcutItems?.first { $0.type == "saved" })
        XCTAssertEqual(shortcut.localizedTitle, "Saved trails")
        XCTAssertEqual(shortcut.userInfo?["url"] as? String, "craft-fixture://saved")
    }

    func testCelebrationStopsWhenARetainedNativeScreenLosesFocus() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        controller.loadViewIfNeeded()
        controller.render(["id": "root-node", "type": "View", "children": [["id": "card-node", "type": "View", "props": ["key": "celebrating-card", "celebration": ["replay": 0]], "style": ["width": 320, "height": 240]]]])
        window.isHidden = false
        defer { window.isHidden = true }
        controller.view.layoutIfNeeded()
        let card = try XCTUnwrap(find(UIView.self, key: "celebrating-card", below: controller.view))
        card.layoutIfNeeded()
        if !UIAccessibility.isReduceMotionEnabled {
            XCTAssertNotNil(card.layer.animation(forKey: "craft.celebration.entrance"))
        }
        controller.screenVisibilityChanged(false)
        XCTAssertNil(card.layer.animation(forKey: "craft.celebration.entrance"))
        XCTAssertFalse(window.layer.sublayers?.contains { $0.name == "craft.celebration.confetti" } == true)
        controller.screenVisibilityChanged(true)
        card.layoutIfNeeded()
        XCTAssertNil(card.layer.animation(forKey: "craft.celebration.entrance"), "returning to a tab must not replay")
        _ = try controller.applyMutation(batch(1, [
            ["op": "updateNode", "id": "card-node", "patch": ["props": ["celebration": ["replay": 1]]]],
        ]))
        card.layoutIfNeeded()
        XCTAssertTrue(card === find(UIView.self, key: "celebrating-card", below: controller.view), "replay retains the card")
        let confetti = window.layer.sublayers?.first { $0.name == "craft.celebration.confetti" }
        if !UIAccessibility.isReduceMotionEnabled {
            XCTAssertNotNil(card.layer.animation(forKey: "craft.celebration.entrance"), "a native prop update starts the next reveal")
            XCTAssertNotNil(confetti)
        }
        _ = try controller.applyMutation(batch(2, [
            ["op": "updateNode", "id": "card-node", "patch": ["props": ["celebration": ["replay": 1]]]],
        ]))
        card.layoutIfNeeded()
        XCTAssertTrue(confetti === window.layer.sublayers?.first { $0.name == "craft.celebration.confetti" }, "an unchanged replay prop keeps the current run")
        controller.screenVisibilityChanged(false)
        XCTAssertFalse(window.layer.sublayers?.contains { $0.name == "craft.celebration.confetti" } == true)
    }

    func testCelebrationRequiresAnExplicitFiniteReplay() {
        XCTAssertNil(CraftNativeCelebrationSpec(nil))
        XCTAssertNil(CraftNativeCelebrationSpec(["replay": true]))
        XCTAssertNil(CraftNativeCelebrationSpec(["replay": -1]))
        XCTAssertNil(CraftNativeCelebrationSpec(["replay": Double.infinity]))
        XCTAssertEqual(CraftNativeCelebrationSpec(["replay": 0])?.enabled, true)
        XCTAssertEqual(CraftNativeCelebrationSpec(["replay": 0, "enabled": false])?.enabled, false)
    }

    func testCelebrationReplaysOnlyOnRequestAndCleansUpForReducedMotionAndBackground() async throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIViewController()
        window.isHidden = false
        defer { window.isHidden = true }
        let card = UIView(frame: CGRect(x: 24, y: 180, width: 342, height: 280))
        window.rootViewController?.view.addSubview(card)
        let celebration = CraftNativeCelebration(view: card)
        celebration.configure(["replay": 0])
        celebration.layout(reduceMotion: false)
        XCTAssertEqual(celebration.starts, 1)
        XCTAssertTrue(celebration.isRunning)
        XCTAssertNotNil(card.layer.animation(forKey: "craft.celebration.entrance"))
        XCTAssertTrue(window.layer.sublayers?.contains { $0.name == "craft.celebration.confetti" && $0.sublayers?.count == 52 } == true)
        celebration.configure(["replay": 0])
        celebration.layout(reduceMotion: false)
        XCTAssertEqual(celebration.starts, 1, "unrelated reconciliation must not replay")
        celebration.stop()
        XCTAssertFalse(celebration.isRunning)
        XCTAssertNil(card.layer.animation(forKey: "craft.celebration.entrance"))
        XCTAssertFalse(window.layer.sublayers?.contains { $0.name == "craft.celebration.confetti" } == true)
        celebration.configure(["replay": 1])
        celebration.layout(reduceMotion: true)
        XCTAssertEqual(celebration.starts, 1, "Reduce Motion displays the full card without effects")
        celebration.layout(reduceMotion: false)
        XCTAssertEqual(celebration.starts, 1, "changing the preference must not replay a consumed request")
        celebration.configure(["replay": 2])
        celebration.layout(reduceMotion: false)
        XCTAssertEqual(celebration.starts, 2)
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        XCTAssertFalse(celebration.isRunning)
        celebration.configure(["replay": 3, "enabled": false])
        celebration.layout(reduceMotion: false)
        XCTAssertEqual(celebration.starts, 2)
        celebration.configure(["replay": 4])
        celebration.layout(reduceMotion: false)
        XCTAssertTrue(celebration.isRunning)
        try await Task.sleep(nanoseconds: 3_200_000_000)
        XCTAssertFalse(celebration.isRunning, "all decoration is removed after the finite reveal")
    }

    func testSelectedTabIconPolicySurvivesLiveCaptionCleanupAndResetsExplicitly() throws {
        let configured = try JSONDecoder().decode(CraftConfig.Tab.self, from: Data(##"{"id":"/health","title":"Health","symbol":"heart","selectedSymbol":"heart.fill","selectedIconTint":"#ff3b30","selectedIconPulse":false}"##.utf8))
        XCTAssertEqual(configured.selectedSymbol, "heart.fill")
        XCTAssertEqual(configured.selectedIconTint, "#ff3b30")
        XCTAssertEqual(configured.selectedIconPulse, false)
        let chrome = CraftChrome.shared
        let previous = chrome.tabs
        let selected = chrome.selected
        defer { chrome.tabs = previous; chrome.selected = selected }
        chrome.tabs = [CraftChrome.Tab(id: "/health", title: "Health", symbol: "heart", badge: "2")]
        chrome.selected = "/health"
        chrome.updateTab(["id": "/health", "selectedSymbol": "heart.fill", "selectedIconTint": "#ff3b30", "selectedIconPulse": true])
        var active = chrome.tabs[0].iconAppearance(selected: chrome.selected == "/health", motionAllowed: true)
        XCTAssertEqual(active.symbol, "heart.fill")
        XCTAssertEqual(active.tint, "#ff3b30")
        XCTAssertTrue(active.pulse, "selection must work without a heart-rate sensor")
        let inactive = chrome.tabs[0].iconAppearance(selected: false, motionAllowed: true)
        XCTAssertEqual(inactive.symbol, "heart")
        XCTAssertNil(inactive.tint)
        XCTAssertFalse(inactive.pulse)
        XCTAssertFalse(chrome.tabs[0].iconAppearance(selected: true, motionAllowed: false).pulse, "Reduce Motion, hidden bars and inactive scenes stop animation")
        chrome.updateTab(["id": "/health", "selectedSymbol": " \n "])
        XCTAssertNil(chrome.tabs[0].selectedSymbol, "blank overrides restore the base symbol on both platforms")
        chrome.updateTab(["id": "/health", "selectedSymbol": " heart.fill "])
        XCTAssertEqual(chrome.tabs[0].selectedSymbol, "heart.fill")
        chrome.updateTab(["id": "/health", "title": "145 bpm", "iconTint": "#ff3b30", "iconPulse": true])
        chrome.updateTab(["id": "/health", "title": NSNull(), "iconTint": NSNull(), "iconPulse": false])
        active = chrome.tabs[0].iconAppearance(selected: true, motionAllowed: true)
        XCTAssertEqual(active.symbol, "heart.fill")
        XCTAssertTrue(active.pulse, "stale live-reading cleanup must preserve selected styling")
        XCTAssertEqual(chrome.tabs[0].displayTitle, "Health")
        XCTAssertEqual(chrome.tabs[0].badge, "2")
        XCTAssertEqual(chrome.selected, "/health")
        chrome.updateTab(["id": "/health", "iconPulse": true, "selectedIconPulse": false])
        XCTAssertFalse(chrome.tabs[0].iconAppearance(selected: true, motionAllowed: true).pulse, "false overrides the legacy pulse")
        chrome.updateTab(["id": "/health", "selectedSymbol": NSNull(), "selectedIconTint": "invalid", "selectedIconPulse": NSNull()])
        active = chrome.tabs[0].iconAppearance(selected: true, motionAllowed: true)
        XCTAssertEqual(active.symbol, "heart")
        XCTAssertNil(active.tint)
        XCTAssertTrue(active.pulse, "null restores the legacy pulse")
    }

    func testTabUpdatesKeepTheIconAndSelectionWhileChangingItsLiveCaption() {
        let chrome = CraftChrome.shared
        let previous = chrome.tabs
        let selected = chrome.selected
        defer { chrome.tabs = previous; chrome.selected = selected }
        chrome.tabs = [CraftChrome.Tab(id: "/health", title: "Health", symbol: "heart", badge: "2")]
        chrome.selected = "/other"
        chrome.updateTab(["id": "/health", "title": "123 bpm", "iconText": NSNull(), "iconTint": "#ff3b30", "iconPulse": true, "accessibilityLabel": "Health, live heart rate, 123 bpm"])
        XCTAssertEqual(chrome.tabs[0].displayTitle, "123 bpm")
        XCTAssertEqual(chrome.tabs[0].symbol, "heart")
        XCTAssertNil(chrome.tabs[0].iconText)
        XCTAssertEqual(chrome.tabs[0].iconTint, "#ff3b30")
        XCTAssertTrue(chrome.tabs[0].iconPulse)
        XCTAssertEqual(chrome.tabs[0].badge, "2")
        XCTAssertEqual(chrome.selected, "/other")
        chrome.updateTab(["id": "/health", "title": NSNull(), "iconTint": NSNull(), "iconPulse": false, "accessibilityLabel": NSNull()])
        XCTAssertEqual(chrome.tabs[0].displayTitle, "Health")
        XCTAssertNil(chrome.tabs[0].iconTint)
        XCTAssertNil(chrome.tabs[0].accessibilityLabel)
        XCTAssertFalse(chrome.tabs[0].iconPulse)
        chrome.updateTab(["id": "/missing", "title": "Ignored", "iconPulse": true])
        XCTAssertEqual(chrome.tabs[0].displayTitle, "Health")
    }

    func testInitialLinkWaitsForLaunchIntentInsteadOfScreenReadiness() {
        let launch = CraftInitialLinkState()
        var answers: [URL?] = []
        launch.resolve { answers.append($0) }
        XCTAssertTrue(answers.isEmpty)
        let url = URL(string: "https://hq.training/diego-ruiz")!
        launch.receive(url)
        XCTAssertEqual(answers, [url])
        launch.resolve { answers.append($0) }
        XCTAssertEqual(answers, [url, url])
        launch.receive(URL(string: "https://hq.training/pawel")!)
        XCTAssertEqual(launch.url, url)
    }

    func testActivationWithoutALaunchLinkDoesNotClaimTheFirstWarmLink() {
        let launch = CraftInitialLinkState()
        var answers: [URL?] = []
        launch.resolve { answers.append($0) }
        launch.settle()
        launch.receive(URL(string: "https://hq.training/pawel")!)
        launch.resolve { answers.append($0) }
        XCTAssertTrue(launch.settled)
        XCTAssertNil(launch.url)
        XCTAssertEqual(answers.count, 2)
        XCTAssertTrue(answers.allSatisfy { $0 == nil })
    }

    private func capability(
        _ module: String,
        _ method: String,
        _ args: [Any] = [],
        config: CraftConfig = CraftConfig()
    ) async -> Result<Any, CraftNativeActionError> {
        await withCheckedContinuation { continuation in
            CraftNativeActions.perform(
                requestToken: UUID().uuidString,
                version: craftNativeCapabilityProtocolVersion,
                module: module,
                method: method,
                args: args,
                config: config
            ) { continuation.resume(returning: $0) }
        }
    }

    private func assertInvalidFetch(_ options: [String: Any], line: UInt = #line) async {
        guard case .failure(let error) = await capability("Network", "fetch", [options]) else {
            return XCTFail("malformed fetch options unexpectedly succeeded", file: #filePath, line: line)
        }
        XCTAssertEqual(error.code, "INVALID_ARGUMENT", file: #filePath, line: line)
    }

    private func batch(
        _ revision: Int,
        _ operations: [[String: Any]],
        version: Int = 1,
        baseRevision: Int? = nil
    ) -> [String: Any] {
        [
            "version": version,
            "batchId": "batch-\(revision)",
            "baseRevision": baseRevision ?? revision - 1,
            "revision": revision,
            "operations": operations,
        ]
    }

    private func node(_ type: String, key: String, text: String? = nil, style: [String: Any] = [:]) -> [String: Any] {
        var result: [String: Any] = ["type": type, "props": ["key": key], "style": style]
        if let text = text { result["children"] = [text] }
        return result
    }

    private func document(_ children: [[String: Any]]) -> [String: Any] {
        ["type": "View", "children": children]
    }

    private func find<T: UIView>(_ type: T.Type, key: String, below view: UIView) -> T? {
        if let match = view as? T, match.accessibilityIdentifier == key { return match }
        for child in view.subviews {
            if let match = find(type, key: key, below: child) { return match }
        }
        return nil
    }

    func testKeyedViewsKeepIdentityAcrossUpdatesAndMoves() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        controller.loadViewIfNeeded()
        controller.render(document([
            node("Text", key: "count", text: "Count: 0"),
            node("Button", key: "increment", text: "Increment"),
            node("TextInput", key: "name-input", style: ["width": 140]),
            node("Text", key: "name", text: "Hello"),
        ]))

        let field = try XCTUnwrap(find(UITextField.self, key: "name-input", below: controller.view))
        let count = try XCTUnwrap(find(UILabel.self, key: "count", below: controller.view))
        let button = try XCTUnwrap(find(UIButton.self, key: "increment", below: controller.view))
        field.text = "Ada"
        let caret = try XCTUnwrap(field.position(from: field.beginningOfDocument, offset: 2))
        field.selectedTextRange = field.textRange(from: caret, to: caret)

        controller.render(document([
            node("Text", key: "count", text: "Count: 1"),
            node("Button", key: "increment", text: "Again"),
            node("TextInput", key: "name-input", style: ["width": 180]),
            node("Text", key: "name", text: "Hello Ada"),
        ]))
        XCTAssertTrue(field === find(UITextField.self, key: "name-input", below: controller.view))
        XCTAssertTrue(count === find(UILabel.self, key: "count", below: controller.view))
        XCTAssertTrue(button === find(UIButton.self, key: "increment", below: controller.view))
        XCTAssertEqual(field.text, "Ada")
        let selection = try XCTUnwrap(field.selectedTextRange)
        XCTAssertEqual(field.offset(from: field.beginningOfDocument, to: selection.start), 2)
        XCTAssertEqual(count.text, "Count: 1")
        XCTAssertEqual(button.title(for: .normal), "Again")
        XCTAssertEqual(field.constraints.first(where: { $0.firstAttribute == .width && $0.isActive })?.constant, 180)

        controller.render(document([
            node("TextInput", key: "name-input"),
            node("Text", key: "count", text: "Count: 2"),
            node("Button", key: "increment", text: "Again"),
        ]))
        XCTAssertTrue(field === find(UITextField.self, key: "name-input", below: controller.view))
        let root = try XCTUnwrap(find(UIStackView.self, key: "root", below: controller.view))
        XCTAssertTrue(root.arrangedSubviews.first === field)
        XCTAssertFalse(field.constraints.contains(where: { $0.firstAttribute == .width && $0.isActive }))

        controller.render(document([node("Text", key: "name-input", text: "Replaced")]))
        XCTAssertNil(field.superview)
        XCTAssertNotNil(find(UILabel.self, key: "name-input", below: controller.view))
    }

    func testNativeTextScalesWithTheScreenContentSizeTrait() throws {
        let host = UIViewController()
        let controller = CraftNativeScreenController(config: CraftConfig())
        host.addChild(controller)
        host.view.addSubview(controller.view)
        host.setOverrideTraitCollection(
            UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge),
            forChild: controller
        )
        controller.didMove(toParent: host)
        controller.render(document([node("Text", key: "dynamic-text", text: "Dynamic", style: ["fontSize": 16])]))

        let label = try XCTUnwrap(find(UILabel.self, key: "dynamic-text", below: controller.view))
        let expected = UIFontMetrics(forTextStyle: .body).scaledValue(
            for: 16,
            compatibleWith: controller.traitCollection
        )
        XCTAssertEqual(label.font.pointSize, expected, accuracy: 0.1)
        XCTAssertGreaterThan(label.font.pointSize, 16)
    }

    func testItalicNativeTextKeepsDynamicTypeScaling() throws {
        let host = UIViewController()
        let controller = CraftNativeScreenController(config: CraftConfig())
        host.addChild(controller)
        host.view.addSubview(controller.view)
        host.setOverrideTraitCollection(
            UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge),
            forChild: controller
        )
        controller.didMove(toParent: host)
        controller.render(document([node(
            "Text",
            key: "italic-dynamic-text",
            text: "Italic",
            style: ["fontSize": 16, "fontStyle": "italic"]
        )]))

        let label = try XCTUnwrap(find(UILabel.self, key: "italic-dynamic-text", below: controller.view))
        let expected = UIFontMetrics(forTextStyle: .body).scaledValue(
            for: 16,
            compatibleWith: controller.traitCollection
        )
        XCTAssertEqual(label.font.pointSize, expected, accuracy: 0.1)
        XCTAssertTrue(label.font.fontDescriptor.symbolicTraits.contains(.traitItalic))
    }

    func testTextInputTraitsFollowHostNeutralProps() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        controller.loadViewIfNeeded()
        controller.render(document([
            [
                "type": "TextInput",
                "props": [
                    "key": "single",
                    "keyboardType": "email-address",
                    "returnKeyType": "done",
                    "autoCapitalize": "characters",
                    "autoCorrect": false,
                    "secureTextEntry": true,
                    "editable": false,
                ],
            ],
            [
                "type": "TextInput",
                "props": [
                    "key": "multi",
                    "multiline": true,
                    "keyboardType": "decimal-pad",
                    "returnKeyType": "send",
                    "autoCapitalize": "words",
                ],
            ],
        ]))

        let single = try XCTUnwrap(find(UITextField.self, key: "single", below: controller.view))
        XCTAssertEqual(single.keyboardType, .emailAddress)
        XCTAssertEqual(single.returnKeyType, .done)
        XCTAssertEqual(single.autocapitalizationType, .allCharacters)
        XCTAssertEqual(single.autocorrectionType, .no)
        XCTAssertTrue(single.isSecureTextEntry)
        XCTAssertFalse(single.isEnabled)

        let multi = try XCTUnwrap(find(UITextView.self, key: "multi", below: controller.view))
        XCTAssertEqual(multi.keyboardType, .decimalPad)
        XCTAssertEqual(multi.returnKeyType, .send)
        XCTAssertEqual(multi.autocapitalizationType, .words)
        XCTAssertEqual(multi.autocorrectionType, .default)
    }

    func testTextInputAccessibilityValueRestoresNativeValueWhenPropIsRemoved() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        controller.loadViewIfNeeded()
        controller.render(document([[
            "type": "TextInput",
            "props": ["key": "field", "value": "Draft", "accessibilityValue": "Custom value"],
        ]]))

        let field = try XCTUnwrap(find(UITextField.self, key: "field", below: controller.view))
        XCTAssertEqual(field.accessibilityValue, "Custom value")

        controller.render(document([[
            "type": "TextInput",
            "props": ["key": "field", "value": "Draft"],
        ]]))
        // UIKit's own value again: what a field holding the same text says
        // (its text, on current iOS), never the authored one.
        let native = UITextField()
        native.text = "Draft"
        XCTAssertNotEqual(field.accessibilityValue, "Custom value")
        XCTAssertEqual(field.accessibilityValue, native.accessibilityValue)
    }

    func testPersistentStorageAndDatabaseCapabilitiesRoundTripJSONValues() async throws {
        _ = await capability("Storage", "clear")
        let stored = await capability("Storage", "set", ["profile", ["name": "Ada", "visits": 2]])
        guard case .success = stored else { return XCTFail("storage set failed") }
        guard case .success(let value) = await capability("Storage", "get", ["profile"]),
              let profile = value as? [String: Any] else { return XCTFail("storage get failed") }
        XCTAssertEqual(profile["name"] as? String, "Ada")
        XCTAssertEqual(profile["visits"] as? Int, 2)

        var config = CraftConfig()
        config.enableLocalDatabase = true
        let table = "capability_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        guard case .success = await capability("Database", "execute", [
            "CREATE TABLE \(table) (id INTEGER PRIMARY KEY, name TEXT NOT NULL)", [],
        ], config: config) else { return XCTFail("database create failed") }
        guard case .success = await capability("Database", "beginTransaction", [], config: config) else {
            return XCTFail("database transaction failed")
        }
        _ = await capability("Database", "execute", ["INSERT INTO \(table) (name) VALUES (?)", ["Grace"]], config: config)
        _ = await capability("Database", "commit", [], config: config)
        guard case .success(let rows) = await capability("Database", "query", [
            "SELECT name FROM \(table)", [],
        ], config: config), let first = (rows as? [[String: Any]])?.first else {
            return XCTFail("database query failed")
        }
        XCTAssertEqual(first["name"] as? String, "Grace")
    }

    func testFetchRejectsMalformedOptionsBeforeOpeningNetwork() async {
        XCTAssertTrue(CraftNativeActions.capabilities(config: CraftConfig()).contains("fetch"))
        await assertInvalidFetch(["url": "/api/activities"])
        await assertInvalidFetch([
            "url": "http://127.0.0.1/api/activities",
            "method": "GET",
            "body": "not allowed",
        ])
        await assertInvalidFetch([
            "url": "http://127.0.0.1/api/activities",
            "body": 42,
        ])
        await assertInvalidFetch([
            "url": "http://127.0.0.1/api/activities",
            "headers": ["X-Native-Test": 42],
        ])
    }

    func testUnkeyedChildrenReusePositionAndRemovedChildrenDetach() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        controller.loadViewIfNeeded()
        controller.render(document([
            ["type": "Text", "children": ["First"]],
            ["type": "Text", "children": ["Second"]],
        ]))
        let first = try XCTUnwrap(find(UILabel.self, key: "root.0", below: controller.view))
        let second = try XCTUnwrap(find(UILabel.self, key: "root.1", below: controller.view))
        controller.render(document([["type": "Text", "children": ["Updated"]]]))
        XCTAssertTrue(first === find(UILabel.self, key: "root.0", below: controller.view))
        XCTAssertEqual(first.text, "Updated")
        XCTAssertNil(second.superview)
    }

    func testImageAndScrollViewAreNativeAccessibleAndStable() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        controller.loadViewIfNeeded()
        let pixel = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
        let image: [String: Any] = [
            "type": "Image",
            "props": ["key": "avatar", "source": ["uri": pixel], "accessibilityLabel": "Profile photo", "accessibilityRole": "image"],
            "style": ["width": 24, "height": 24, "resizeMode": "cover"]
        ]
        let scroll: [String: Any] = [
            "type": "ScrollView", "props": ["key": "feed"], "style": ["height": 80, "gap": 6],
            "children": [image, node("Text", key: "caption", text: "Native content")]
        ]
        controller.render(document([scroll]))

        let scrollView = try XCTUnwrap(find(UIScrollView.self, key: "feed", below: controller.view))
        let imageView = try XCTUnwrap(find(UIImageView.self, key: "avatar", below: controller.view))
        XCTAssertNotNil(imageView.image)
        XCTAssertEqual(imageView.accessibilityLabel, "Profile photo")
        XCTAssertTrue(imageView.accessibilityTraits.contains(.image))
        XCTAssertEqual(imageView.contentMode, .scaleAspectFill)

        controller.render(document([scroll]))
        XCTAssertTrue(scrollView === find(UIScrollView.self, key: "feed", below: controller.view))
        XCTAssertTrue(imageView === find(UIImageView.self, key: "avatar", below: controller.view))
    }

    func testHeaderAccessibilityRoleMapsToUIKitTrait() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        controller.loadViewIfNeeded()
        controller.render(document([[
            "type": "Text",
            "props": ["key": "header", "accessibilityRole": "header"],
            "children": ["People directory"],
        ]]))

        let header = try XCTUnwrap(find(UILabel.self, key: "header", below: controller.view))
        XCTAssertTrue(header.accessibilityTraits.contains(.header))
    }

    func testButtonRowWithoutALabelReadsItsText() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        controller.loadViewIfNeeded()
        controller.render(document([
            [
                "type": "View",
                "props": ["key": "email-row", "accessibilityRole": "button"],
                "children": [
                    ["type": "Image", "props": ["key": "avatar", "accessibilityLabel": "Diego Ruiz"], "children": []],
                    ["type": "Text", "props": ["key": "name"], "children": ["Diego Ruiz"]],
                    ["type": "View", "props": ["key": "inner"], "children": [
                        ["type": "Text", "props": ["key": "email"], "children": ["diego@example.org"]],
                    ]],
                    ["type": "Icon", "props": ["key": "chevron", "name": "chevron-right"], "children": []],
                ],
            ],
            [
                "type": "View",
                "props": ["key": "labelled", "accessibilityRole": "button", "accessibilityLabel": "Sign out"],
                "children": [["type": "Text", "props": ["key": "inside"], "children": ["Log out"]]],
            ],
            [
                "type": "View",
                "props": ["key": "plain"],
                "children": [["type": "Text", "props": ["key": "loose"], "children": ["Not grouped"]]],
            ],
        ]))

        let row = try XCTUnwrap(find(UIView.self, key: "email-row", below: controller.view))
        XCTAssertTrue(row.isAccessibilityElement)
        XCTAssertEqual(row.accessibilityLabel, "Diego Ruiz, diego@example.org")
        XCTAssertTrue(row.accessibilityTraits.contains(.button))
        XCTAssertEqual(try XCTUnwrap(find(UIView.self, key: "labelled", below: controller.view)).accessibilityLabel, "Sign out")
        XCTAssertNil(try XCTUnwrap(find(UIView.self, key: "plain", below: controller.view)).accessibilityLabel)
        // The chevron is decoration: no stop of its own, nothing said.
        let chevron = try XCTUnwrap(find(UIImageView.self, key: "chevron", below: controller.view))
        XCTAssertFalse(chevron.isAccessibilityElement)
        XCTAssertNil(chevron.accessibilityLabel)
    }

    func testALabelledIconIsReadAndAnUnlabelledOneIsNot() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        controller.loadViewIfNeeded()
        controller.render(document([
            ["type": "Icon", "props": ["key": "labelled", "name": "heart.fill", "accessibilityLabel": "Favourite"], "children": []],
            ["type": "Icon", "props": ["key": "plain", "name": "heart.fill"], "children": []],
        ]))
        let labelled = try XCTUnwrap(find(UIImageView.self, key: "labelled", below: controller.view))
        XCTAssertTrue(labelled.isAccessibilityElement)
        XCTAssertEqual(labelled.accessibilityLabel, "Favourite")
        let plain = try XCTUnwrap(find(UIImageView.self, key: "plain", below: controller.view))
        XCTAssertFalse(plain.isAccessibilityElement)
        XCTAssertNil(plain.accessibilityLabel)
    }

    func testSharedLayoutColorAndTextStylesMapToUIKit() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        controller.loadViewIfNeeded()
        let first = node("Text", key: "first", text: "first", style: [
            "color": "#123456", "fontSize": 21, "fontWeight": "700", "fontStyle": "italic",
            "textAlign": "right", "letterSpacing": 2, "lineHeight": 28, "textTransform": "uppercase",
            "textDecorationLine": "underline"
        ])
        let second = node("Text", key: "second", text: "second")
        controller.render(document([[
            "type": "View", "props": ["key": "styled"],
            "style": [
                "flexDirection": "row-reverse", "alignItems": "center", "justifyContent": "center",
                "gap": 7, "paddingHorizontal": 11, "paddingVertical": 5,
                "width": 240, "height": 80, "backgroundColor": "#abcdef", "opacity": 0.75,
                "borderWidth": 3, "borderColor": "#654321", "borderRadius": 9, "overflow": "hidden"
            ],
            "children": [first, second]
        ]]))

        let stack = try XCTUnwrap(find(UIStackView.self, key: "styled", below: controller.view))
        let label = try XCTUnwrap(find(UILabel.self, key: "first", below: controller.view))
        XCTAssertEqual(stack.axis, .horizontal)
        XCTAssertEqual(stack.alignment, .center)
        XCTAssertEqual(stack.spacing, 7)
        XCTAssertEqual(stack.layoutMargins.left, 11)
        XCTAssertEqual(stack.layoutMargins.top, 5)
        XCTAssertEqual(stack.arrangedSubviews.compactMap { $0.accessibilityIdentifier }, ["second", "first"])
        XCTAssertEqual(stack.alpha, 0.75)
        XCTAssertEqual(stack.layer.borderWidth, 3)
        XCTAssertEqual(stack.layer.cornerRadius, 9)
        XCTAssertTrue(stack.clipsToBounds)
        XCTAssertEqual(label.text, "FIRST")
        XCTAssertEqual(label.font.pointSize, 21)
        XCTAssertTrue(label.font.fontDescriptor.symbolicTraits.contains(.traitItalic))
        XCTAssertEqual(label.textAlignment, .right)
        XCTAssertEqual(label.attributedText?.attribute(.kern, at: 0, effectiveRange: nil) as? CGFloat, 2)
        XCTAssertNotNil(label.attributedText?.attribute(.underlineStyle, at: 0, effectiveRange: nil))
    }

    func testImageFailuresAreExplicitAndClearStaleContent() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        controller.loadViewIfNeeded()
        controller.render(document([[
            "type": "Image", "props": ["key": "broken", "source": ["uri": "data:image/png;base64,invalid"]]
        ]]))
        let image = try XCTUnwrap(find(UIImageView.self, key: "broken", below: controller.view))
        XCTAssertNil(image.image)
        XCTAssertEqual(image.accessibilityValue, "Image data is invalid")

        controller.render(document([[
            "type": "Image", "props": ["key": "broken", "source": ["uri": "http://example.com/image.png"]]
        ]]))
        XCTAssertEqual(image.accessibilityValue, "Unsupported image source")

        controller.render(document([["type": "Image", "props": ["key": "broken"]]]))
        XCTAssertEqual(image.accessibilityValue, "Image source is missing")

        controller.render(document([["type": "Text", "props": ["key": "status"], "children": ["Updated"]], [
            "type": "Image", "props": ["key": "broken", "source": ["uri": "http://example.com/image.png"]]
        ]]))
        XCTAssertEqual(image.accessibilityValue, "Unsupported image source")

        controller.render(document([[
            "type": "Image",
            "props": [
                "key": "broken",
                "source": ["uri": "http://example.com/image.png"],
                "accessibilityValue": "ready",
            ],
        ]]))
        XCTAssertEqual(image.accessibilityValue, "ready, Unsupported image source")
    }

    func testMutationBatchesPreserveControlsFocusScrollAndHandlers() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        controller.loadViewIfNeeded()
        controller.render(["id": "root-node", "type": "View", "children": []])
        try controller.applyMutation(batch(1, [
            ["op": "createNode", "id": "field-node", "node": [
                "type": "TextInput", "props": ["testID": "field"], "events": ["onChange": "changed"]
            ]],
            ["op": "createNode", "id": "scroll-node", "node": [
                "type": "ScrollView", "props": ["testID": "scroll"], "style": ["height": 40]
            ]],
            ["op": "createNode", "id": "label-node", "node": [
                "type": "Text", "props": ["testID": "label", "accessibilityLabel": "Before"],
                "style": ["color": "#ff0000"],
                "children": ["Before"]
            ]],
            ["op": "insertChild", "parentId": "scroll-node", "childId": "label-node", "index": 0],
            ["op": "insertChild", "parentId": "root-node", "childId": "field-node", "index": 0],
            ["op": "insertChild", "parentId": "root-node", "childId": "scroll-node", "index": 1],
        ]))

        let field = try XCTUnwrap(find(UITextField.self, key: "field", below: controller.view))
        let scroll = try XCTUnwrap(find(UIScrollView.self, key: "scroll", below: controller.view))
        let label = try XCTUnwrap(find(UILabel.self, key: "label", below: controller.view))
        field.text = "draft"
        let caret = try XCTUnwrap(field.position(from: field.beginningOfDocument, offset: 3))
        field.selectedTextRange = field.textRange(from: caret, to: caret)
        scroll.contentOffset = CGPoint(x: 0, y: 17)

        let update = try controller.applyMutation(batch(2, [
            ["op": "updateNode", "id": "label-node", "patch": [
                "children": ["After"],
                "props": ["accessibilityLabel": "After"],
                "style": ["fontSize": 18],
                "events": ["onPress": "pressed"],
            ]],
        ]))
        XCTAssertFalse(update.requiresFullRender)
        XCTAssertEqual(update.updatedNodeIds, ["label-node"])

        XCTAssertTrue(field === find(UITextField.self, key: "field", below: controller.view))
        XCTAssertTrue(scroll === find(UIScrollView.self, key: "scroll", below: controller.view))
        XCTAssertTrue(label === find(UILabel.self, key: "label", below: controller.view))
        XCTAssertEqual(field.text, "draft")
        let selection = try XCTUnwrap(field.selectedTextRange)
        XCTAssertEqual(field.offset(from: field.beginningOfDocument, to: selection.start), 3)
        XCTAssertEqual(scroll.contentOffset.y, 17)
        XCTAssertEqual(label.text, "After")
        XCTAssertEqual(label.accessibilityLabel, "After")
        XCTAssertEqual(label.textColor, UIColor.red)
        XCTAssertEqual(label.font.pointSize, 18)

        let move = try controller.applyMutation(batch(3, [
            ["op": "moveChild", "parentId": "root-node", "childId": "scroll-node", "index": 0],
        ]))
        XCTAssertFalse(move.requiresFullRender)
        XCTAssertEqual(move.affectedNodeIds, ["root-node"])
        XCTAssertTrue(field === find(UITextField.self, key: "field", below: controller.view))
        XCTAssertTrue(scroll === find(UIScrollView.self, key: "scroll", below: controller.view))
    }

    func testMutationPreservesAuthoredKeysAcrossImportCreationUpdatesAndMoves() throws {
        let document = CraftNativeMutationDocument()
        document.replace(with: [
            "id": "root", "type": "View", "key": "root-key", "children": [
                ["id": "existing", "type": "TextInput", "key": "draft-key", "props": ["value": "draft"]],
            ],
        ])
        XCTAssertEqual(document.node("existing")?["key"] as? String, "draft-key")
        let result = try document.apply(batch(1, [
            ["op": "createNode", "id": "created", "node": ["type": "View", "key": "created-key"]],
            ["op": "insertChild", "parentId": "root", "childId": "created", "index": 1],
            ["op": "updateNode", "id": "existing", "patch": ["props": ["value": "edited"]]],
            ["op": "moveChild", "parentId": "root", "childId": "created", "index": 0],
        ]))
        let rendered = try XCTUnwrap(result.document)
        let children = try XCTUnwrap(rendered["children"] as? [[String: Any]])
        XCTAssertEqual(rendered["key"] as? String, "root-key")
        XCTAssertEqual(children[0]["key"] as? String, "created-key")
        XCTAssertEqual(children[1]["key"] as? String, "draft-key")
        XCTAssertEqual((document.node("existing")?["props"] as? [String: Any])?["value"] as? String, "edited")
    }

    func testEveryContainerTheRendererDrawsTakesChildrenAndALeafDoesNot() throws {
        for type in CraftNativeMutationDocument.containerTypes.sorted() + ["svg", "pressable"] {
            let document = CraftNativeMutationDocument()
            XCTAssertNoThrow(try document.apply(batch(1, [
                ["op": "createNode", "id": "root", "root": true, "node": ["type": "View"]],
                ["op": "createNode", "id": "container", "node": ["type": type]],
                ["op": "createNode", "id": "child", "node": ["type": "View"]],
                ["op": "insertChild", "parentId": "root", "childId": "container", "index": 0],
                ["op": "insertChild", "parentId": "container", "childId": "child", "index": 0],
            ])), type)
            XCTAssertEqual(document.parentId(of: "child"), "container", type)
        }
        for type in ["Text", "Image", "Icon", "TextInput", "Button"] {
            let document = CraftNativeMutationDocument()
            XCTAssertThrowsError(try document.apply(batch(1, [
                ["op": "createNode", "id": "root", "root": true, "node": ["type": "View"]],
                ["op": "createNode", "id": "leaf", "node": ["type": type]],
                ["op": "createNode", "id": "child", "node": ["type": "View"]],
                ["op": "insertChild", "parentId": "root", "childId": "leaf", "index": 0],
                ["op": "insertChild", "parentId": "leaf", "childId": "child", "index": 0],
            ]))) { error in
                XCTAssertEqual((error as? CraftNativeMutationFailure)?.code, "INVALID_PARENT", type)
            }
        }
    }

    func testMapOverlayMutationStaysAddressableToItsMap() throws {
        let document = CraftNativeMutationDocument()
        XCTAssertNoThrow(try document.apply(batch(1, [
            ["op": "createNode", "id": "root", "root": true, "node": ["type": "View"]],
            ["op": "createNode", "id": "map", "node": ["type": "Map"]],
            ["op": "createNode", "id": "route", "node": [
                "type": "MapPolyline", "props": ["geometry": [47.0, 11.0, 47.1, 11.2]],
            ]],
            ["op": "insertChild", "parentId": "root", "childId": "map", "index": 0],
            ["op": "insertChild", "parentId": "map", "childId": "route", "index": 0],
        ])))
        XCTAssertEqual(document.parentId(of: "route"), "map")

        let update = try document.apply(batch(2, [
            ["op": "updateNode", "id": "route", "patch": [
                "props": ["geometry": [47.0, 11.0, 47.2, 11.4]],
            ]],
        ]))
        XCTAssertEqual(update.updatedNodeIds, ["route"])
        XCTAssertEqual(update.affectedNodeIds, ["route"])
        XCTAssertFalse(update.requiresFullRender)
    }

    func testMapExplorationCameraAndDirectionMarker() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        let window = try hostWindow()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.loadViewIfNeeded()
        controller.render([
            "type": "Map", "props": ["key": "explorer", "showsCompass": true, "showsScale": true, "cameraPitch": 30, "cameraHeading": 90,
                "region": ["center": ["latitude": 37.7, "longitude": -119.5], "span": ["latitudeDelta": 0.01, "longitudeDelta": 0.01]]],
            "style": ["width": 320, "height": 320],
            "children": [["type": "MapMarker", "props": ["id": "direction", "geometry": [37.7, -119.5], "bearing": 180]]],
        ])
        controller.view.layoutIfNeeded()
        let map = try XCTUnwrap(find(MKMapView.self, key: "explorer", below: controller.view))
        XCTAssertTrue(map.showsCompass)
        XCTAssertTrue(map.showsScale)
        XCTAssertEqual(map.camera.heading, 90, accuracy: 1)
        // MapKit can cap larger pitches at this altitude. Thirty degrees is
        // within its supported range and still catches a camera applied before layout.
        XCTAssertEqual(map.camera.pitch, 30, accuracy: 1)
        let annotation = try XCTUnwrap(map.annotations.first)
        let marker = try XCTUnwrap(map.delegate?.mapView?(map, viewFor: annotation))
        let image = try XCTUnwrap(marker.image)
        XCTAssertEqual(image.renderingMode, .alwaysOriginal, "MapKit must preserve the arrow's contrasting palette")
        XCTAssertLessThanOrEqual(image.size.width, 24, "Direction signs must leave the route visible in compact maps")
        XCTAssertEqual(marker.accessibilityIdentifier, "direction")
        XCTAssertEqual(marker.transform.b, 1, accuracy: 0.02)
    }

    func testMapDirectionSignsKeepALightBackdropAndTheAuthoredColor() throws {
        for appearance in [UIUserInterfaceStyle.light, .dark] {
            let controller = CraftNativeScreenController(config: CraftConfig())
            controller.overrideUserInterfaceStyle = appearance
            controller.loadViewIfNeeded()
            controller.render([
                "type": "Map", "props": ["key": "contrast-map"],
                "style": ["width": 320, "height": 320],
                "children": [["type": "MapMarker", "props": ["id": "direction", "geometry": [37.7, -119.5], "bearing": 90, "pinColor": "#365b2d"]]],
            ])
            let map = try XCTUnwrap(find(MKMapView.self, key: "contrast-map", below: controller.view))
            let annotation = try XCTUnwrap(map.annotations.first)
            let marker = try XCTUnwrap(map.delegate?.mapView?(map, viewFor: annotation))
            let image = try XCTUnwrap(marker.image)
            let raster = UIGraphicsImageRenderer(size: image.size).image { _ in image.draw(at: .zero) }
            let cgImage = try XCTUnwrap(raster.cgImage)
            var pixels = [UInt8](repeating: 0, count: cgImage.width * cgImage.height * 4)
            try pixels.withUnsafeMutableBytes { bytes in
                let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: cgImage.width, height: cgImage.height,
                    bitsPerComponent: 8, bytesPerRow: cgImage.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
            }
            var opaque = 0
            var light = 0
            var authored = 0
            for offset in stride(from: 0, to: pixels.count, by: 4) where pixels[offset + 3] > 240 {
                opaque += 1
                let red = Int(pixels[offset]), green = Int(pixels[offset + 1]), blue = Int(pixels[offset + 2])
                if red > 235 && green > 235 && blue > 235 { light += 1 }
                if abs(red - 54) < 12 && abs(green - 91) < 12 && abs(blue - 45) < 12 { authored += 1 }
            }
            XCTAssertGreaterThan(opaque, 50)
            XCTAssertGreaterThan(light, opaque / 3, "direction signs need an opaque light backdrop over the basemap")
            XCTAssertGreaterThan(authored, 10, "the native direction sign ignored its authored pinColor")
        }
    }

    func testMapPreservesAuthoredPolylineOrderAcrossUpdatesAndMoves() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        let window = try hostWindow()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.loadViewIfNeeded()
        func document(_ casingWidth: Double, reversed: Bool = false) -> [String: Any] {
            let casing: [String: Any] = ["type": "MapPolyline", "props": ["id": "casing", "geometry": [37.7, -119.5, 37.71, -119.51], "strokeColor": "#365b2d", "strokeWidth": casingWidth]]
            let route: [String: Any] = ["type": "MapPolyline", "props": ["id": "route", "geometry": [37.7, -119.5, 37.71, -119.51], "strokeColor": "#91e86b", "strokeWidth": 5]]
            return ["type": "Map", "props": ["key": "ordered-map"],
                    "style": ["width": 320, "height": 320],
                    "children": reversed ? [route, casing] : [casing, route]]
        }
        controller.render(document(9))
        controller.view.layoutIfNeeded()
        let map = try XCTUnwrap(find(MKMapView.self, key: "ordered-map", below: controller.view))
        func widths() throws -> [CGFloat] {
            try map.overlays.compactMap { $0 as? MKPolyline }.map { line in
                let renderer = try XCTUnwrap(map.delegate?.mapView?(map, rendererFor: line) as? MKPolylineRenderer)
                return renderer.lineWidth
            }
        }
        XCTAssertEqual(try widths(), [9, 5], "the bright route draws above its wider casing")
        let foreground = try XCTUnwrap(map.overlays.compactMap { $0 as? MKPolyline }.last)

        // Replacing a lower overlay must not move it above an unchanged line.
        controller.render(document(11))
        controller.view.layoutIfNeeded()
        XCTAssertTrue(map === find(MKMapView.self, key: "ordered-map", below: controller.view))
        XCTAssertEqual(try widths(), [11, 5])
        XCTAssertTrue(map.overlays.compactMap { $0 as? MKPolyline }.last === foreground)

        // Child moves are draw-order changes even when geometry is unchanged.
        controller.render(document(11, reversed: true))
        controller.view.layoutIfNeeded()
        XCTAssertEqual(try widths(), [5, 11])
        controller.render(document(11))
        controller.view.layoutIfNeeded()
        XCTAssertEqual(try widths(), [11, 5])
    }

    func testMapUpdatesNativePinColorAndTiltGestureWithoutReplacingTheMarker() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        let window = try hostWindow()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.loadViewIfNeeded()
        func document(_ color: String, _ pitch: Bool) -> [String: Any] {
            ["type": "Map", "props": ["key": "colored-map", "pitchEnabled": pitch],
             "style": ["width": 320, "height": 320],
             "children": [["type": "MapMarker", "props": ["id": "start", "geometry": [37.7, -119.5], "pinColor": color]]]]
        }
        controller.render(document("#24724b", false))
        controller.view.layoutIfNeeded()
        let map = try XCTUnwrap(find(MKMapView.self, key: "colored-map", below: controller.view))
        let annotation = try XCTUnwrap(map.annotations.first)
        let marker = try XCTUnwrap(map.delegate?.mapView?(map, viewFor: annotation))
        XCTAssertFalse(map.isPitchEnabled)
        XCTAssertEqual(marker.tintColor, UIColor(red: 36 / 255, green: 114 / 255, blue: 75 / 255, alpha: 1))
        XCTAssertEqual(marker.image?.renderingMode, .alwaysOriginal)
        controller.render(document("#2878c8", true))
        controller.view.layoutIfNeeded()
        XCTAssertTrue(map.isPitchEnabled)
        XCTAssertTrue(map.annotations.first === annotation)
        let updated = try XCTUnwrap(map.delegate?.mapView?(map, viewFor: annotation))
        XCTAssertEqual(updated.tintColor, UIColor(red: 40 / 255, green: 120 / 255, blue: 200 / 255, alpha: 1))
    }

    func testMapUsesNativeTopographicTilesWithAttribution() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        controller.loadViewIfNeeded()
        controller.render([
            "type": "Map", "props": ["key": "topo-map", "edgePadding": ["bottom": 160], "tileOverlay": ["urlTemplate": "https://example.org/tiles/{z}/{y}/{x}.png", "attribution": "Test map data"]],
            "style": ["width": 320, "height": 480],
            "children": [["type": "MapPolyline", "props": ["geometry": [37.7, -119.5, 37.72, -119.49]]]],
        ])
        let map = try XCTUnwrap(find(MKMapView.self, key: "topo-map", below: controller.view))
        let tiles = try XCTUnwrap(map.overlays.first as? MKTileOverlay)
        XCTAssertTrue(tiles.canReplaceMapContent)
        XCTAssertTrue(map.delegate?.mapView?(map, rendererFor: tiles) is MKTileOverlayRenderer)
        XCTAssertTrue(map.overlays.last is MKPolyline, "The route must remain above the basemap")
        controller.view.layoutIfNeeded()
        map.layoutIfNeeded()
        let credit = try XCTUnwrap(map.subviews.compactMap { $0 as? UILabel }.first { $0.text == "Test map data" && !$0.isHidden })
        XCTAssertLessThanOrEqual(credit.frame.maxY, map.bounds.height - 160, "The floating profile must not cover map attribution")
    }

    func testMapReservesRoomForFloatingControls() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        let window = try hostWindow()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.loadViewIfNeeded()
        controller.render([
            "type": "Map", "props": ["key": "padded-map", "fitToBounds": true,
                "edgePadding": ["top": 40, "bottom": 160, "left": 32, "right": 32]],
            "style": ["width": 320, "height": 480],
            "children": [["type": "MapPolyline", "props": ["geometry": [37.7, -119.5, 37.72, -119.49]]]],
        ])
        controller.view.layoutIfNeeded()
        let map = try XCTUnwrap(find(MKMapView.self, key: "padded-map", below: controller.view))
        for coordinate in [CLLocationCoordinate2D(latitude: 37.7, longitude: -119.5), CLLocationCoordinate2D(latitude: 37.72, longitude: -119.49)] {
            let point = map.convert(coordinate, toPointTo: map)
            XCTAssertGreaterThanOrEqual(point.x, 30)
            XCTAssertLessThanOrEqual(point.x, map.bounds.width - 30)
            XCTAssertGreaterThanOrEqual(point.y, 38)
            XCTAssertLessThanOrEqual(point.y, map.bounds.height - 158)
        }
    }

    func testMapFitRetriesAfterItsViewportIsMeasured() {
        let controller = CraftNativeScreenController(config: CraftConfig())
        controller.loadViewIfNeeded()
        controller.render([
            "type": "View",
            "children": [[
                "type": "Map",
                "props": ["key": "map", "fitToBounds": true],
                "style": ["width": 320, "height": 240],
                "children": [[
                    "type": "MapPolyline",
                    "props": ["geometry": [47.0, 11.0, 47.1, 11.2]],
                ]],
            ]],
        ])
        controller.view.frame = CGRect(x: 0, y: 0, width: 320, height: 240)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        let map = find(MKMapView.self, key: "map", below: controller.view)

        XCTAssertTrue(
            map?.visibleMapRect.contains(MKMapPoint(CLLocationCoordinate2D(latitude: 47.0, longitude: 11.0))) == true,
            "fitToBounds did not retry after the map received a real viewport"
        )
    }

    func testMapIgnoresBooleanNumericCoordinates() {
        let controller = CraftNativeScreenController(config: CraftConfig())
        controller.loadViewIfNeeded()
        controller.render([
            "type": "View",
            "children": [[
                "type": "Map",
                "props": [
                    "key": "boolean-map",
                    "region": [
                        "center": ["latitude": true, "longitude": 11.0],
                        "span": ["latitudeDelta": 1.0, "longitudeDelta": 1.0],
                    ],
                ],
                "style": ["width": 320, "height": 240],
                "children": [[
                    "type": "MapPolyline",
                    "props": ["geometry": [true, 11.0, 47.1, 11.2]],
                ]],
            ]],
        ])
        let map = find(MKMapView.self, key: "boolean-map", below: controller.view)
        XCTAssertEqual(map?.overlays.count, 0, "Boolean map coordinates were treated as numeric")
    }

    func testSvgIgnoresBooleanNumericGeometry() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        controller.render([
            "type": "View",
            "children": [[
                "type": "Svg",
                "props": ["testID": "boolean-svg", "viewBox": [true, 0, 24, 24]],
                "style": ["width": 40],
            ]],
        ])
        controller.view.layoutIfNeeded()
        let svg = try XCTUnwrap(find(UIView.self, key: "boolean-svg", below: controller.view))
        XCTAssertLessThanOrEqual(svg.frame.height, 1, "Boolean SVG viewBox values were treated as numeric")
    }

    func testADrawingRevealedAfterTheFirstPaintTakesItsShapesInPlace() throws {
        // A chart behind an `:if` (stx): the drawing and its shapes arrive in
        // one batch after the first paint. The shapes were refused as
        // INVALID_PARENT and the screen drawn again from scratch.
        let controller = CraftNativeScreenController(config: CraftConfig())
        controller.loadViewIfNeeded()
        controller.render(["id": "root-node", "type": "View", "children": [
            ["id": "label-node", "type": "Text", "props": ["testID": "label"], "children": ["Heart rate"]],
        ]])
        let label = try XCTUnwrap(find(UILabel.self, key: "label", below: controller.view))

        let reveal = try controller.applyMutation(batch(1, [
            ["op": "createNode", "id": "chart-node", "node": [
                "type": "Svg", "props": ["testID": "chart", "viewBox": [0, 0, 10, 10]], "style": ["width": 40, "height": 40],
            ]],
            ["op": "createNode", "id": "line-node", "node": [
                "type": "Path", "props": ["d": "M0 0L10 10", "geometry": [["M", 0, 0], ["L", 10, 10]], "stroke": "#ff0000"],
            ]],
            ["op": "insertChild", "parentId": "chart-node", "childId": "line-node", "index": 0],
            ["op": "insertChild", "parentId": "root-node", "childId": "chart-node", "index": 1],
        ]))
        XCTAssertFalse(reveal.requiresFullRender)
        XCTAssertEqual(reveal.affectedNodeIds, ["chart-node", "root-node"])
        let chart = try XCTUnwrap(find(UIView.self, key: "chart", below: controller.view))
        XCTAssertEqual(String(describing: type(of: chart)), "CraftNativeSvgView")
        XCTAssertTrue(label === find(UILabel.self, key: "label", below: controller.view))

        // A shape's new outline redraws its drawing, which stays the same view.
        _ = try controller.applyMutation(batch(2, [
            ["op": "updateNode", "id": "line-node", "patch": ["props": ["d": "M0 10L10 0", "geometry": [["M", 0, 10], ["L", 10, 0]]]]],
        ]))
        XCTAssertTrue(chart === find(UIView.self, key: "chart", below: controller.view))
    }

    func testMutationValidationIsAtomicAndDeterministic() throws {
        let document = CraftNativeMutationDocument()
        XCTAssertThrowsError(try document.apply(batch(1, [
            ["op": "createNode", "id": "root", "root": true, "node": ["type": "View"]],
            ["op": "removeNode", "id": "missing"],
        ]))) { error in
            XCTAssertEqual(error as? CraftNativeMutationFailure, CraftNativeMutationFailure(
                "UNKNOWN_NODE", "node missing does not exist", operationIndex: 1
            ))
        }
        XCTAssertEqual(document.revision, 0)

        _ = try document.apply(batch(1, [
            ["op": "createNode", "id": "root", "root": true, "node": ["type": "View"]],
        ]))
        XCTAssertThrowsError(try document.apply(batch(2, [
            ["op": "updateNode", "id": "root", "patch": ["type": "Text"]],
        ]))) { error in
            XCTAssertEqual(error as? CraftNativeMutationFailure, CraftNativeMutationFailure(
                "INVALID_PATCH", "unsupported patch field type", operationIndex: 0
            ))
        }
        XCTAssertThrowsError(try document.apply(batch(2, [
            ["op": "removeNode", "id": "root"],
        ], version: 2, baseRevision: 1))) { error in
            XCTAssertEqual((error as? CraftNativeMutationFailure)?.code, "UNSUPPORTED_VERSION")
        }
        XCTAssertEqual(document.revision, 1)
    }

    func testMutationRejectsInvalidTreeShapesWithoutAdvancingRevision() throws {
        let document = CraftNativeMutationDocument()
        _ = try document.apply(batch(1, [
            ["op": "createNode", "id": "root", "root": true, "node": ["type": "View"]],
        ]))

        XCTAssertThrowsError(try document.apply(batch(2, [
            ["op": "createNode", "id": "orphan", "node": ["type": "Text"]],
        ]))) { error in
            XCTAssertEqual(error as? CraftNativeMutationFailure, CraftNativeMutationFailure(
                "INVALID_TREE", "all nodes must be reachable from the root"
            ))
        }
        XCTAssertEqual(document.revision, 1)
        XCTAssertNil(document.node("orphan"))

        XCTAssertThrowsError(try document.apply(batch(2, [
            ["op": "createNode", "id": "parent", "node": ["type": "View"]],
            ["op": "insertChild", "parentId": "parent", "childId": "root", "index": 0],
        ]))) { error in
            XCTAssertEqual(error as? CraftNativeMutationFailure, CraftNativeMutationFailure(
                "INVALID_TREE", "root node must not have a parent"
            ))
        }
        XCTAssertEqual(document.revision, 1)
        XCTAssertNil(document.node("parent"))

        XCTAssertThrowsError(try document.apply(batch(2, [
            ["op": "createNode", "id": "child", "node": ["type": "Text"]],
            ["op": "insertChild", "parentId": "root", "childId": "child", "index": 2],
        ]))) { error in
            XCTAssertEqual((error as? CraftNativeMutationFailure)?.code, "INVALID_INDEX")
            XCTAssertEqual((error as? CraftNativeMutationFailure)?.operationIndex, 1)
        }
        XCTAssertEqual(document.revision, 1)
        XCTAssertNil(document.node("child"))

        XCTAssertThrowsError(try document.apply(batch(2, [
            ["op": "removeNode", "id": "root"],
        ], baseRevision: 0))) { error in
            XCTAssertEqual((error as? CraftNativeMutationFailure)?.code, "REVISION_MISMATCH")
            XCTAssertNil((error as? CraftNativeMutationFailure)?.operationIndex)
        }
        XCTAssertEqual(document.revision, 1)
    }

    func testFlatListRecyclesTenThousandKeyedRowsAndKeepsItsViewport() {
        let list = CraftNativeFlatList()
        list.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
        let rows: [[String: Any]] = (0..<10_000).map { index in
            ["id": "row-\(index)", "type": "Text", "children": ["Row \(index)"]]
        }
        var rendered: [String: UIView] = [:]
        var renderCount = 0
        let render: CraftNativeFlatList.RenderItem = { node, identity, previous in
            renderCount += 1
            if let previous = previous { return previous }
            let label = UILabel()
            label.text = (node["children"] as? [String])?.first
            rendered[identity] = label
            return label
        }

        list.apply(
            nodes: rows,
            horizontal: false,
            columns: 1,
            inverted: false,
            endReachedThreshold: 0.1,
            renderItem: render,
            recycleItem: { _ in },
            endReached: nil
        )
        list.layoutIfNeeded()
        XCTAssertEqual(list.numberOfItems(inSection: 0), 10_000)
        XCTAssertGreaterThan(renderCount, 0)
        XCTAssertLessThan(renderCount, 100)

        list.contentOffset = CGPoint(x: 0, y: 240)
        list.layoutIfNeeded()
        let retainedAnchor = list.visibleItemIdentities.first
        let moved = [rows[1], rows[0]] + Array(rows.dropFirst(2))
        list.apply(
            nodes: moved,
            horizontal: false,
            columns: 1,
            inverted: false,
            endReachedThreshold: 0.1,
            renderItem: render,
            recycleItem: { _ in },
            endReached: nil
        )
        list.layoutIfNeeded()
        XCTAssertEqual(list.numberOfItems(inSection: 0), 10_000)
        XCTAssertNotNil(retainedAnchor)
        XCTAssertTrue(retainedAnchor.map(list.visibleItemIdentities.contains) ?? false)
        XCTAssertLessThan(rendered.count, 100)
    }

    func testFlatListForwardsScrollAndMomentumCallbacks() {
        let list = CraftNativeFlatList()
        list.frame = CGRect(x: 0, y: 0, width: 320, height: 160)
        var scrollCount = 0
        var beginDragCount = 0
        var endDragCount = 0
        var momentumBeginCount = 0
        var momentumEndCount = 0
        list.onScrollEvent = { _ in scrollCount += 1 }
        list.onScrollBeginDrag = { _ in beginDragCount += 1 }
        list.onScrollEndDrag = { _ in endDragCount += 1 }
        list.onMomentumScrollBegin = { _ in momentumBeginCount += 1 }
        list.onMomentumScrollEnd = { _ in momentumEndCount += 1 }
        let rows = (0..<20).map { index in
            ["id": "row-\(index)", "type": "Text", "children": ["Row \(index)"]] as [String: Any]
        }
        let render: CraftNativeFlatList.RenderItem = { _, _, previous in previous ?? UILabel() }
        list.apply(
            nodes: rows,
            horizontal: false,
            columns: 1,
            inverted: false,
            endReachedThreshold: 0.1,
            renderItem: render,
            recycleItem: { _ in },
            endReached: nil
        )
        list.layoutIfNeeded()
        list.scrollViewWillBeginDragging(list)
        list.scrollViewDidScroll(list)
        list.scrollViewDidEndDragging(list, willDecelerate: true)
        list.scrollViewWillBeginDecelerating(list)
        list.scrollViewDidEndDecelerating(list)
        XCTAssertEqual(scrollCount, 1)
        XCTAssertEqual(beginDragCount, 1)
        XCTAssertEqual(endDragCount, 1)
        XCTAssertEqual(momentumBeginCount, 1)
        XCTAssertEqual(momentumEndCount, 1)
    }

    func testFlatListScrollIndicatorsAndBounceAxesFollowProps() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        controller.loadViewIfNeeded()
        controller.render(document([[
            "type": "FlatList",
            "props": [
                "key": "list",
                "horizontal": true,
                "showsVerticalScrollIndicator": false,
                "showsHorizontalScrollIndicator": true,
                "alwaysBounceVertical": true,
                "alwaysBounceHorizontal": false,
            ],
            "children": [["id": "row", "type": "Text", "children": ["Row"]]],
        ]]))

        let list = try XCTUnwrap(find(CraftNativeFlatList.self, key: "list", below: controller.view))
        XCTAssertFalse(list.showsVerticalScrollIndicator)
        XCTAssertTrue(list.showsHorizontalScrollIndicator)
        XCTAssertTrue(list.alwaysBounceVertical)
        XCTAssertFalse(list.alwaysBounceHorizontal)

        controller.render(document([[
            "type": "FlatList",
            "props": ["key": "list"],
            "children": [["id": "row", "type": "Text", "children": ["Row"]]],
        ]]))
        XCTAssertTrue(list.showsVerticalScrollIndicator)
        XCTAssertTrue(list.showsHorizontalScrollIndicator)
        XCTAssertTrue(list.alwaysBounceVertical)
        XCTAssertFalse(list.alwaysBounceHorizontal)
    }

    func testFlatListPagingFollowsProps() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        controller.loadViewIfNeeded()
        controller.render(document([[
            "type": "FlatList",
            "props": ["key": "list", "pagingEnabled": true],
            "children": [["id": "row", "type": "Text", "children": ["Row"]]],
        ]]))
        let list = try XCTUnwrap(find(CraftNativeFlatList.self, key: "list", below: controller.view))
        XCTAssertTrue(list.isPagingEnabled)

        controller.render(document([[
            "type": "FlatList",
            "props": ["key": "list"],
            "children": [["id": "row", "type": "Text", "children": ["Row"]]],
        ]]))
        XCTAssertFalse(list.isPagingEnabled)
    }

    func testFlatListScrollTargetIsAccepted() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        controller.loadViewIfNeeded()
        controller.render(document([[
            "type": "FlatList",
            "props": ["key": "list", "scrollTarget": ["id": "row", "animated": false, "key": "first"]],
            "children": [["id": "row", "type": "Text", "props": ["testID": "row"], "children": ["Row"]]],
        ]]))
        let list = try XCTUnwrap(find(CraftNativeFlatList.self, key: "list", below: controller.view))
        list.layoutIfNeeded()
        XCTAssertTrue(list.contentOffset.x.isFinite)
        XCTAssertTrue(list.contentOffset.y.isFinite)
    }

    func testFlatListRefreshControlForwardsAndTracksControlledState() {
        let list = CraftNativeFlatList()
        // A refresh control only begins refreshing inside a window.
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        list.frame = window.bounds
        window.addSubview(list)
        window.isHidden = false
        defer { window.isHidden = true }
        var refreshCount = 0
        list.setRefreshHandler({ refreshCount += 1 }, refreshing: false)

        let control = try! XCTUnwrap(list.refreshControl)
        control.sendActions(for: .valueChanged)
        XCTAssertEqual(refreshCount, 1)

        list.setRefreshHandler({ refreshCount += 1 }, refreshing: true)
        XCTAssertTrue(control.isRefreshing)
        list.setRefreshAppearance(["tintColor": "#22c55e"])
        XCTAssertEqual(control.tintColor, UIColor(hex: "#22c55e"))
        list.setRefreshAppearance([:])
        XCTAssertNil(control.tintColor)
        list.setRefreshHandler({ refreshCount += 1 }, refreshing: false)
        XCTAssertFalse(control.isRefreshing)
        list.setRefreshHandler(nil, refreshing: false)
        XCTAssertNil(list.refreshControl)
    }

    func testImageBackgroundTintFollowsStyle() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        controller.loadViewIfNeeded()
        let backgroundNode: ([String: Any]) -> [String: Any] = { style in
            [
                "type": "ImageBackground",
                "props": ["key": "background"],
                "style": style,
            ]
        }

        controller.render(document([backgroundNode(["tintColor": "#2563eb"])]))
        let background = try XCTUnwrap(find(UIImageView.self, key: "background", below: controller.view))
        XCTAssertEqual(background.tintColor, UIColor(hex: "#2563eb"))

        controller.render(document([backgroundNode([:])]))
        // Clearing an explicit tint restores UIKit's inherited tint. The
        // getter returns that resolved colour rather than nil on iOS 27.
        XCTAssertEqual(background.tintColor, background.superview?.tintColor)
    }

    func testFlatListControllerLaysOutAndMovesMulticolumnRowsWithoutReentrantInvalidation() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        let rows: [[String: Any]] = (0..<40).map { index in
            [
                "id": "row-\(index)",
                "type": "View",
                "props": ["key": "row-\(index)", "listRole": "item"],
                "children": [[
                    "id": "label-\(index)", "type": "Text",
                    "props": ["testID": "label-\(index)"], "children": ["Row \(index)"],
                ]],
            ]
        }
        func document(_ children: [[String: Any]]) -> [String: Any] {
            [
                "id": "root-node", "type": "View", "children": [[
                    "id": "list-node", "type": "FlatList",
                    "props": ["testID": "grid", "numColumns": 2],
                    "style": ["height": 300], "children": children,
                ]],
            ]
        }

        controller.render(document(rows))
        controller.view.layoutIfNeeded()
        let list = try XCTUnwrap(find(CraftNativeFlatList.self, key: "grid", below: controller.view))
        list.layoutIfNeeded()
        XCTAssertEqual(list.numberOfItems(inSection: 0), 40)
        XCTAssertNotNil(find(UILabel.self, key: "label-0", below: controller.view))

        controller.render(document(Array(rows.reversed())))
        controller.view.layoutIfNeeded()
        list.layoutIfNeeded()
        XCTAssertEqual(list.numberOfItems(inSection: 0), 40)
    }

    func testFlatListUsesIntrinsicHeightsForVariableRows() throws {
        let list = CraftNativeFlatList()
        list.frame = CGRect(x: 0, y: 0, width: 320, height: 240)
        let rows: [[String: Any]] = [
            ["id": "short", "type": "Text", "children": ["Short"]],
            ["id": "tall", "type": "Text", "children": ["Tall\nrow\ncontent\ncontent"]],
        ]
        let render: CraftNativeFlatList.RenderItem = { node, _, previous in
            let label = (previous as? UILabel) ?? UILabel()
            label.numberOfLines = 0
            label.font = .systemFont(ofSize: 16)
            label.text = (node["children"] as? [String])?.first
            return label
        }

        list.apply(
            nodes: rows,
            horizontal: false,
            columns: 1,
            inverted: false,
            endReachedThreshold: 0.1,
            renderItem: render,
            recycleItem: { _ in },
            endReached: nil
        )
        list.layoutIfNeeded()

        let short = try XCTUnwrap(list.layoutAttributesForItem(at: IndexPath(item: 0, section: 0)))
        let tall = try XCTUnwrap(list.layoutAttributesForItem(at: IndexPath(item: 1, section: 0)))
        XCTAssertGreaterThan(tall.size.height, short.size.height + 20)
    }

    func testFlatListKeepsHorizontalRowsIntrinsicallySized() throws {
        let list = CraftNativeFlatList()
        list.frame = CGRect(x: 0, y: 0, width: 320, height: 80)
        let rows: [[String: Any]] = [
            ["id": "short", "type": "Text", "children": ["short"]],
            ["id": "long", "type": "Text", "children": ["a much longer horizontal row"]],
        ]
        let render: CraftNativeFlatList.RenderItem = { node, _, previous in
            let label = (previous as? UILabel) ?? UILabel()
            label.numberOfLines = 1
            label.font = .systemFont(ofSize: 16)
            label.text = (node["children"] as? [String])?.first
            return label
        }

        list.apply(
            nodes: rows,
            horizontal: true,
            columns: 1,
            inverted: false,
            endReachedThreshold: 0.1,
            renderItem: render,
            recycleItem: { _ in },
            endReached: nil
        )
        list.layoutIfNeeded()

        let short = try XCTUnwrap(list.layoutAttributesForItem(at: IndexPath(item: 0, section: 0)))
        let long = try XCTUnwrap(list.layoutAttributesForItem(at: IndexPath(item: 1, section: 0)))
        XCTAssertLessThan(short.size.width, list.bounds.width)
        XCTAssertGreaterThan(long.size.width, short.size.width + 20)
    }

    func testFlatListCoalescesAnEndReachedRenderDuringSnapshotApplication() {
        let list = CraftNativeFlatList()
        list.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
        let first = (0..<2).map { index in
            ["id": "row-\(index)", "type": "Text", "children": ["Row \(index)"]] as [String: Any]
        }
        let appended = first + [["id": "row-2", "type": "Text", "children": ["Row 2"]]]
        let render: CraftNativeFlatList.RenderItem = { _, _, previous in previous ?? UILabel() }
        var endReachedCount = 0
        let endReached = expectation(description: "end reached after initial snapshot")

        list.apply(
            nodes: first,
            horizontal: false,
            columns: 1,
            inverted: false,
            endReachedThreshold: 0.1,
            renderItem: render,
            recycleItem: { _ in },
            endReached: {
                endReachedCount += 1
                list.apply(
                    nodes: appended,
                    horizontal: false,
                    columns: 1,
                    inverted: false,
                    endReachedThreshold: 0.1,
                    renderItem: render,
                    recycleItem: { _ in },
                    endReached: nil
                )
                endReached.fulfill()
            }
        )
        list.layoutIfNeeded()
        wait(for: [endReached], timeout: 2)
        list.layoutIfNeeded()

        XCTAssertEqual(endReachedCount, 1)
        XCTAssertEqual(list.numberOfItems(inSection: 0), 3)

        let changedMiddle = expectation(description: "end reached after a middle row changes")
        list.apply(
            nodes: [
                first[0],
                ["id": "row-1", "type": "Text", "children": ["Updated row 1"]],
                appended[2],
            ],
            horizontal: false,
            columns: 1,
            inverted: false,
            endReachedThreshold: 0.1,
            renderItem: render,
            recycleItem: { _ in },
            endReached: { changedMiddle.fulfill() }
        )
        list.layoutIfNeeded()
        wait(for: [changedMiddle], timeout: 2)

        let chromeOnlyEndReached = expectation(description: "chrome-only list does not reach data end")
        chromeOnlyEndReached.isInverted = true
        let chromeOnly: [[String: Any]] = [
            ["id": "header", "type": "Text", "props": ["listRole": "header"]],
            ["id": "empty", "type": "Text", "props": ["listRole": "empty"]],
            ["id": "footer", "type": "Text", "props": ["listRole": "footer"]],
        ]
        list.apply(
            nodes: chromeOnly,
            horizontal: false,
            columns: 1,
            inverted: false,
            endReachedThreshold: 0.1,
            renderItem: render,
            recycleItem: { _ in },
            endReached: { chromeOnlyEndReached.fulfill() }
        )
        list.layoutIfNeeded()
        wait(for: [chromeOnlyEndReached], timeout: 0.2)
    }

    func testFlatListRetainsAHorizontalViewportAcrossInvertedMoves() throws {
        let list = CraftNativeFlatList()
        list.frame = CGRect(x: 0, y: 0, width: 320, height: 160)
        let header: [String: Any] = [
            "id": "header", "type": "Text", "props": ["listRole": "header"],
        ]
        let footer: [String: Any] = [
            "id": "footer", "type": "Text", "props": ["listRole": "footer"],
        ]
        let rows: [[String: Any]] = (0..<8).map { index in
            ["id": "row-\(index)", "type": "Text", "children": ["Row \(index)"]]
        }
        let render: CraftNativeFlatList.RenderItem = { _, _, previous in previous ?? UILabel() }
        func apply(_ data: [[String: Any]]) {
            list.apply(
                nodes: [header] + data + [footer],
                horizontal: true,
                columns: 1,
                inverted: true,
                endReachedThreshold: 0.1,
                renderItem: render,
                recycleItem: { _ in },
                endReached: nil
            )
            let settled = expectation(description: "horizontal snapshot settled")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { settled.fulfill() }
            wait(for: [settled], timeout: 1)
            list.layoutIfNeeded()
        }

        apply(rows)
        let layout = try XCTUnwrap(list.collectionViewLayout as? UICollectionViewFlowLayout)
        XCTAssertEqual(layout.scrollDirection, .horizontal)
        XCTAssertEqual(list.numberOfItems(inSection: 0), 10)
        XCTAssertEqual(list.visibleItemIdentities.first, "footer")

        list.scrollToItem(at: IndexPath(item: 4, section: 0), at: .left, animated: false)
        list.layoutIfNeeded()
        let retainedAnchor = try XCTUnwrap(list.visibleItemIdentities.first)
        let moved = [rows[1], rows[0]] + Array(rows.dropFirst(2))
        apply(moved)

        XCTAssertTrue(list.visibleItemIdentities.contains(retainedAnchor))
    }

    /// A window in the test host's scene: one made with only a frame is in
    /// no scene, so nothing in it can take the keyboard.
    private func hostWindow() throws -> UIWindow {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        return window
    }

    func testImagesLoadOverHttpOnlyFromThisMachine() {
        for address in ["https://example.com/a.png", "http://localhost:3130/assets/a.png", "http://127.0.0.1:3130/a.png", "http://[::1]:3130/a.png", "http://hq.localhost/a.png"] {
            XCTAssertTrue(CraftNativeScreenController.loadsImage(from: URL(string: address)!), address)
        }
        for address in ["http://example.com/a.png", "http://localhost.example.com/a.png", "ftp://localhost/a.png", "file:///tmp/a.png"] {
            XCTAssertFalse(CraftNativeScreenController.loadsImage(from: URL(string: address)!), address)
        }
        let controller = CraftNativeScreenController(config: CraftConfig())
        controller.loadViewIfNeeded()
        controller.render(document([[
            "type": "Image", "props": ["key": "local", "source": ["uri": "http://localhost:9/missing.png"]]
        ]]))
        let image = find(UIImageView.self, key: "local", below: controller.view)
        XCTAssertNotEqual(image?.accessibilityValue, "Unsupported image source")
    }

    func testMultilineRendersPreserveCompositionAndApplyTypographyAfterCommit() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        let window = try hostWindow()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        func content(_ value: String, fontSize: Int, caption: String) -> [String: Any] {
            document([
                ["type": "TextInput", "props": ["key": "claim-proof", "multiline": true, "value": value], "style": ["fontSize": fontSize]],
                node("Text", key: "caption", text: caption),
            ])
        }
        controller.render(content("", fontSize: 16, caption: "Before"))
        let proof = try XCTUnwrap(find(UITextView.self, key: "claim-proof", below: controller.view))
        XCTAssertTrue(proof.becomeFirstResponder())
        proof.setMarkedText("ラン", selectedRange: NSRange(location: 2, length: 0))
        let marked = try XCTUnwrap(proof.markedTextRange)
        XCTAssertEqual(proof.text(in: marked), "ラン")

        controller.render(content("", fontSize: 16, caption: "Unrelated caption changed"))
        XCTAssertNotNil(proof.markedTextRange, "An unchanged input must keep its composing range")
        XCTAssertEqual(proof.text, "ラン")
        controller.render(content("", fontSize: 22, caption: "Updated while composing"))

        XCTAssertTrue(proof === find(UITextView.self, key: "claim-proof", below: controller.view))
        XCTAssertTrue(proof.isFirstResponder)
        XCTAssertEqual(proof.text, "ラン")
        let retained = try XCTUnwrap(proof.markedTextRange, "A reactive render must not commit or discard the keyboard's composition")
        XCTAssertEqual(proof.text(in: retained), "ラン")
        proof.unmarkText()
        proof.insertText(" club")
        controller.render(content("ラン club", fontSize: 22, caption: "Committed"))
        XCTAssertEqual(proof.text, "ラン club")
        XCTAssertNil(proof.markedTextRange)
        XCTAssertEqual(proof.font?.pointSize, 22)
    }

    func testTextInputsPadTheirTextAndAskForAutofill() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        controller.loadViewIfNeeded()
        controller.render(document([
            ["type": "TextInput", "props": ["key": "email", "textContentType": "username", "placeholder": "Email"], "style": ["paddingHorizontal": 16, "height": 48, "width": 300]],
            ["type": "TextInput", "props": ["key": "password", "autoComplete": "current-password", "secureTextEntry": true], "style": ["paddingLeft": 12, "paddingRight": 4]],
            ["type": "TextInput", "props": ["key": "code", "textContentType": "oneTimeCode", "keyboardType": "number-pad"]],
            ["type": "TextInput", "props": ["key": "notes", "multiline": true], "style": ["padding": 10]],
        ]))
        let email = try XCTUnwrap(find(CraftNativeTextField.self, key: "email", below: controller.view))
        let password = try XCTUnwrap(find(CraftNativeTextField.self, key: "password", below: controller.view))
        let code = try XCTUnwrap(find(CraftNativeTextField.self, key: "code", below: controller.view))
        let notes = try XCTUnwrap(find(UITextView.self, key: "notes", below: controller.view))
        XCTAssertEqual(email.padding, UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16))
        let bounds = CGRect(x: 0, y: 0, width: 300, height: 48)
        XCTAssertGreaterThanOrEqual(email.textRect(forBounds: bounds).minX, 16)
        XCTAssertGreaterThanOrEqual(email.placeholderRect(forBounds: bounds).minX, 16)
        XCTAssertLessThanOrEqual(email.editingRect(forBounds: bounds).maxX, 284)
        XCTAssertEqual(email.textContentType, .username)
        XCTAssertEqual(password.textContentType, .password)
        XCTAssertTrue(password.isSecureTextEntry)
        XCTAssertEqual(password.padding.left, 12)
        XCTAssertEqual(code.textContentType, .oneTimeCode)
        XCTAssertEqual(code.keyboardType, .numberPad)
        XCTAssertEqual(notes.textContainerInset, UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10))
        XCTAssertEqual(CraftNativeScreenController.textContentType(["autoComplete": "new-password"]), .newPassword)
        XCTAssertEqual(CraftNativeScreenController.textContentType(["textContentType": "emailAddress"]), .emailAddress)
        XCTAssertNil(CraftNativeScreenController.textContentType(["autoComplete": "off"]))
    }

    func testDelayedInputAcknowledgementDoesNotStealFocusFromTheNextField() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        let window = try hostWindow()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.render(document([
            ["type": "TextInput", "props": ["key": "name"], "events": ["onChangeText": "nameChanged"]],
            ["type": "TextInput", "props": ["key": "email"]],
        ]))
        let name = try XCTUnwrap(find(UITextField.self, key: "name", below: controller.view))
        let email = try XCTUnwrap(find(UITextField.self, key: "email", below: controller.view))
        XCTAssertTrue(name.becomeFirstResponder())
        name.text = "Runner"
        name.sendActions(for: .editingChanged)
        XCTAssertTrue(email.becomeFirstResponder())
        let settled = expectation(description: "input acknowledgement settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { settled.fulfill() }
        wait(for: [settled], timeout: 2)
        XCTAssertTrue(email.isFirstResponder, "The previous field's delayed acknowledgement must respect the newer focus")
        XCTAssertFalse(name.isFirstResponder)
    }

    func testDelayedInputAcknowledgementDoesNotReopenADismissedKeyboard() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        let window = try hostWindow()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.render(document([
            ["type": "TextInput", "props": ["key": "name"], "events": ["onChangeText": "nameChanged"]],
        ]))
        let name = try XCTUnwrap(find(UITextField.self, key: "name", below: controller.view))
        XCTAssertTrue(name.becomeFirstResponder())
        name.text = "Runner"
        name.sendActions(for: .editingChanged)
        controller.forgetFocusedInput(name)
        window.endEditing(true)
        let settled = expectation(description: "dismissed input acknowledgement settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { settled.fulfill() }
        wait(for: [settled], timeout: 2)
        XCTAssertFalse(name.isFirstResponder, "A completed edit must not undo an explicit keyboard dismissal")
    }

    func testReturnOnANextFieldMovesToTheNextOne() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        let window = try hostWindow()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.render(document([
            ["type": "TextInput", "props": ["key": "email", "returnKeyType": "next"]],
            ["type": "Text", "props": ["key": "between"], "children": ["Password"]],
            ["type": "TextInput", "props": ["key": "password", "returnKeyType": "go"], "events": ["onSubmitEditing": "signIn"]],
        ]))
        let email = try XCTUnwrap(find(UITextField.self, key: "email", below: controller.view))
        let password = try XCTUnwrap(find(UITextField.self, key: "password", below: controller.view))
        XCTAssertTrue(controller.inputAfter(email) === password)
        XCTAssertNil(controller.inputAfter(password))
        // Return stays in the form (the keyboard is kept), and focus moves on.
        XCTAssertFalse(controller.textFieldShouldReturn(email))
        // `go` with a handler of its own ends editing and fires it, as before.
        XCTAssertTrue(controller.textFieldShouldReturn(password))
    }

    func testAScrollViewInsetsForTheKeyboardAndShowsTheFocusedField() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        let window = try hostWindow()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.render(document([[
            "type": "ScrollView", "props": ["key": "form"], "style": ["flex": 1],
            "children": [
                ["type": "View", "props": ["key": "spacer"], "style": ["height": 700]],
                ["type": "TextInput", "props": ["key": "password"], "style": ["height": 44]],
            ],
        ]]))
        controller.view.layoutIfNeeded()
        let scroll = try XCTUnwrap(find(UIScrollView.self, key: "form", below: controller.view))
        let password = try XCTUnwrap(find(UITextField.self, key: "password", below: controller.view))
        let keyboard = CGRect(x: 0, y: 500, width: 390, height: 344)
        NotificationCenter.default.post(name: UIResponder.keyboardWillChangeFrameNotification, object: nil, userInfo: [
            UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: keyboard),
            UIResponder.keyboardAnimationDurationUserInfoKey: 0,
            UIResponder.keyboardAnimationCurveUserInfoKey: 0,
        ])
        controller.view.layoutIfNeeded()
        // The focused field scrolls into view (focus itself needs a running
        // keyboard, which a unit test host does not have).
        controller.scrollIntoView(password, animated: false)
        // Whatever the shrunken safe area does not cover, the inset does, and
        // the field sits above the keyboard.
        let field = password.convert(password.bounds, to: window)
        XCTAssertLessThanOrEqual(field.maxY, keyboard.minY + 0.5)
        XCTAssertGreaterThanOrEqual(scroll.contentInset.bottom, 0)
        NotificationCenter.default.post(name: UIResponder.keyboardWillHideNotification, object: nil, userInfo: [
            UIResponder.keyboardAnimationDurationUserInfoKey: 0,
            UIResponder.keyboardAnimationCurveUserInfoKey: 0,
        ])
        XCTAssertEqual(scroll.contentInset.bottom, 0)
    }

    func testFlatListContentInsetsRejectBooleanNumbers() {
        let list = CraftNativeFlatList()
        list.setContentContainerStyle(["padding": true, "paddingBottom": false])
        XCTAssertEqual(list.contentInset, .zero)
    }

    func testScreenNumericStylesRejectBooleanNumbers() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        controller.loadViewIfNeeded()
        controller.render(document([node(
            "View",
            key: "boolean-style",
            style: ["width": true, "height": false, "borderWidth": true, "opacity": false]
        )]))

        let view = try XCTUnwrap(find(UIView.self, key: "boolean-style", below: controller.view))
        XCTAssertFalse(view.constraints.contains { $0.isActive && $0.firstAttribute == .width }, "Boolean width was treated as numeric")
        XCTAssertFalse(view.constraints.contains { $0.isActive && $0.firstAttribute == .height }, "Boolean height was treated as numeric")
        XCTAssertEqual(view.layer.borderWidth, 0, "Boolean border width was treated as numeric")
        XCTAssertEqual(view.alpha, 1, accuracy: 0.001, "Boolean opacity changed the native view")
    }

    func testAPressableWithPressFeedbackStillTakesItsPress() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        controller.loadViewIfNeeded()
        controller.render(document([
            [
                "type": "Pressable", "props": ["key": "pressable"], "style": ["height": 24],
                "events": ["onPress": "pressed", "onPressIn": "pressIn", "onPressOut": "pressOut"],
                "children": [node("Text", key: "label", text: "Press")],
            ],
            [
                "type": "Pressable", "props": ["key": "disabled", "disabled": true], "style": ["height": 24],
                "events": ["onPress": "pressed"],
                "children": [node("Text", key: "disabled-label", text: "Disabled")],
            ],
        ]))
        let pressable = try XCTUnwrap(find(UIView.self, key: "pressable", below: controller.view))
        let recognizers = pressable.gestureRecognizers ?? []
        let tap = try XCTUnwrap(recognizers.first { $0 is UITapGestureRecognizer })
        let feedback = try XCTUnwrap(recognizers.first { ($0 as? UILongPressGestureRecognizer)?.minimumPressDuration == 0 })
        // The feedback begins as the finger lands; it must not take the touch
        // from the tap that is onPress.
        XCTAssertEqual(feedback.delegate?.gestureRecognizer?(feedback, shouldRecognizeSimultaneouslyWith: tap), true)
        let disabled = try XCTUnwrap(find(UIView.self, key: "disabled", below: controller.view))
        XCTAssertFalse(disabled.isUserInteractionEnabled)
        XCTAssertTrue(disabled.accessibilityTraits.contains(.notEnabled))
    }

    func testHidingAModalDismissesItsKeyboardWithoutRestoringHiddenInputFocus() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        let window = try hostWindow()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.render(document([
            ["type": "TextInput", "props": ["key": "outside"]],
            ["id": "review-modal", "type": "Modal", "props": ["key": "modal", "visible": true, "animationType": "none"],
                "children": [["type": "TextInput", "props": ["key": "review", "multiline": true], "events": ["onChangeText": "reviewChanged"]]]],
        ]))
        controller.view.layoutIfNeeded()
        let input = try XCTUnwrap(find(UITextView.self, key: "review", below: controller.view))
        XCTAssertTrue(input.becomeFirstResponder())
        input.text = "A trail review"
        controller.textViewDidChange(input)
        _ = try controller.applyMutation(batch(1, [
            ["op": "updateNode", "id": "review-modal", "patch": ["props": ["visible": false]]],
        ]))
        XCTAssertFalse(input.isFirstResponder, "Saving or cancelling a modal must dismiss its keyboard")
        let settled = expectation(description: "hidden modal input acknowledgement settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { settled.fulfill() }
        wait(for: [settled], timeout: 2)
        XCTAssertFalse(input.isFirstResponder, "A delayed input acknowledgement cannot reopen the keyboard")
        _ = try controller.applyMutation(batch(2, [
            ["op": "updateNode", "id": "review-modal", "patch": ["props": ["visible": true]]],
        ]))
        XCTAssertFalse(input.isFirstResponder, "Reopening the modal waits for an explicit focus")
        XCTAssertTrue(input.becomeFirstResponder())
        let outside = try XCTUnwrap(find(UITextField.self, key: "outside", below: controller.view))
        XCTAssertTrue(outside.becomeFirstResponder())
        _ = try controller.applyMutation(batch(3, [
            ["op": "updateNode", "id": "review-modal", "patch": ["props": ["visible": false]]],
        ]))
        XCTAssertTrue(outside.isFirstResponder, "Hiding a modal must not dismiss another field's keyboard")
    }

    func testAShownModalInAScrollViewCoversTheScreenAndTakesItsTouches() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        let window = try hostWindow()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.render(document([[
            "type": "ScrollView", "props": ["key": "page"], "style": ["flex": 1],
            "children": [
                ["type": "View", "props": ["key": "spacer"], "style": ["height": 2000]],
                [
                    "type": "Modal", "props": ["key": "modal", "visible": true, "transparent": true, "animationType": "none"],
                    "children": [["type": "Button", "props": ["key": "close"], "events": ["onPress": "close"], "children": ["Close"]]],
                ],
            ],
        ]]))
        controller.view.layoutIfNeeded()
        let page = try XCTUnwrap(find(UIScrollView.self, key: "page", below: controller.view))
        page.setContentOffset(CGPoint(x: 0, y: 1200), animated: false)
        controller.view.layoutIfNeeded()
        let modal = try XCTUnwrap(find(UIView.self, key: "modal", below: controller.view))
        // Over the screen, not over the scroll content wherever it scrolled.
        XCTAssertTrue(modal.superview === controller.view)
        XCTAssertEqual(modal.frame, controller.view.bounds)
        XCTAssertTrue(modal.isUserInteractionEnabled)
        let close = try XCTUnwrap(find(UIButton.self, key: "close", below: modal))
        modal.layoutIfNeeded()
        let center = close.convert(CGPoint(x: close.bounds.midX, y: close.bounds.midY), to: controller.view)
        XCTAssertTrue(controller.view.bounds.contains(center))
        XCTAssertTrue(controller.view.hitTest(center, with: nil) === close)
    }

    func testASliderReportsTheDecimalItShows() {
        // UISlider keeps a Float; the script hears the number, not its
        // binary neighbour.
        XCTAssertEqual(CraftNativeScreenController.sliderEventValue(0.8), 0.8)
        XCTAssertEqual(CraftNativeScreenController.sliderEventValue(Float(0.3)), 0.3)
        XCTAssertEqual(CraftNativeScreenController.sliderEventValue(42), 42)
        // Nine steps of 0.1 in Floats is 0.90000004; the step says one place.
        XCTAssertEqual(CraftNativeScreenController.sliderEventValue(Float(0.1) * 9, step: 0.1), 0.9)
        XCTAssertEqual(CraftNativeScreenController.sliderEventValue(Float(0.25) * 3, step: 0.25), 0.75)
        XCTAssertEqual(CraftNativeScreenController.sliderEventValue(7, step: 1), 7)
    }

    func testANestedScrollViewsDragDoesNotScrollItsParent() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        let window = try hostWindow()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.render(document([[
            "type": "ScrollView", "props": ["key": "page"], "style": ["flex": 1],
            "children": [
                ["type": "ScrollView", "props": ["key": "strip"], "style": ["height": 72], "children": [
                    ["type": "View", "props": ["key": "tall"], "style": ["height": 600]],
                ]],
                ["type": "FlatList", "props": ["key": "list"], "style": ["height": 72], "children": [
                    ["type": "Text", "props": ["key": "row"], "children": ["Row"]],
                ]],
                ["type": "View", "props": ["key": "spacer"], "style": ["height": 1200]],
            ],
        ]]))
        controller.view.layoutIfNeeded()
        let page = try XCTUnwrap(find(UIScrollView.self, key: "page", below: controller.view))
        let strip = try XCTUnwrap(find(UIScrollView.self, key: "strip", below: controller.view))
        let list = try XCTUnwrap(find(UIScrollView.self, key: "list", below: controller.view))
        for (inner, name) in [(strip, "ScrollView"), (list, "FlatList")] {
            let delegate = try XCTUnwrap(inner.panGestureRecognizer.delegate, name)
            // UIKit gives a drag to one of the two; answering yes scrolled both.
            XCTAssertEqual(delegate.gestureRecognizer?(inner.panGestureRecognizer, shouldRecognizeSimultaneouslyWith: page.panGestureRecognizer), false, name)
            XCTAssertEqual(page.panGestureRecognizer.delegate?.gestureRecognizer?(page.panGestureRecognizer, shouldRecognizeSimultaneouslyWith: inner.panGestureRecognizer), false, name)
            // Other gestures, the back-swipe's and the tab swipe's among them,
            // still decide for themselves alongside a scroll view's pan.
            let other = UIPanGestureRecognizer()
            controller.view.addGestureRecognizer(other)
            defer { controller.view.removeGestureRecognizer(other) }
            XCTAssertEqual(delegate.gestureRecognizer?(inner.panGestureRecognizer, shouldRecognizeSimultaneouslyWith: other), true, name)
        }
    }

    func testADatePickerPicksADayOrAClassTime() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        controller.loadViewIfNeeded()
        controller.render(document([
            ["type": "DatePicker", "props": ["key": "time", "mode": "time", "value": "07:30", "minuteInterval": 5], "events": ["onValueChange": "picked"]],
            ["type": "DatePicker", "props": ["key": "day", "value": "2026-10-12", "minimumDate": "2026-10-01", "maximumDate": "2026-12-31"]],
            ["type": "DatePicker", "props": ["key": "invalid-interval", "mode": "time", "minuteInterval": true]],
        ]))
        let time = try XCTUnwrap(find(UIDatePicker.self, key: "time", below: controller.view))
        let day = try XCTUnwrap(find(UIDatePicker.self, key: "day", below: controller.view))
        let invalid = try XCTUnwrap(find(UIDatePicker.self, key: "invalid-interval", below: controller.view))
        XCTAssertEqual(time.datePickerMode, .time)
        XCTAssertEqual(time.preferredDatePickerStyle, .compact)
        XCTAssertEqual(time.minuteInterval, 5)
        XCTAssertEqual(invalid.minuteInterval, 1)
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time.date)
        XCTAssertEqual(parts.hour, 7)
        XCTAssertEqual(parts.minute, 30)
        XCTAssertEqual(day.datePickerMode, .date)
        XCTAssertEqual(CraftNativeScreenController.datePickerEvent(day.date, mode: .date)["value"] as? String, "2026-10-12")
        XCTAssertNotNil(day.minimumDate)
        XCTAssertEqual(CraftNativeScreenController.datePickerEvent(time.date, mode: .time)["value"] as? String, "07:30")
        XCTAssertEqual(CraftNativeScreenController.pickerDate("2026-10-12T07:30:00Z")?.timeIntervalSince1970, 1_791_790_200)
        XCTAssertEqual(CraftNativeScreenController.pickerDate(1_791_790_200_000 as NSNumber)?.timeIntervalSince1970, 1_791_790_200)
        XCTAssertNil(CraftNativeScreenController.pickerDate("soon"))
        XCTAssertNil(CraftNativeScreenController.countdownDuration("1:x:3"))
    }

    func testSwitchKeepsItsControlAndUserValueWhenTheScriptAcknowledgesATap() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        controller.loadViewIfNeeded()
        func screen(_ value: Bool, _ label: String) -> [String: Any] {
            document([
                ["type": "Switch", "props": ["key": "consent", "value": value], "events": ["onValueChange": "consentChanged"]],
                ["type": "Text", "children": [label]],
            ])
        }
        controller.render(screen(false, "Confirm both"))
        let toggle = try XCTUnwrap(find(UISwitch.self, key: "consent", below: controller.view))
        toggle.setOn(true, animated: true)
        toggle.sendActions(for: .valueChanged)
        controller.render(screen(true, "Ready"))
        XCTAssertTrue(toggle === find(UISwitch.self, key: "consent", below: controller.view))
        XCTAssertTrue(toggle.isOn)
        controller.render(screen(true, "Saving"))
        XCTAssertTrue(toggle.isOn)
        // A document refresh still clears consent when the script asks it to.
        controller.render(screen(false, "Read the updated documents"))
        XCTAssertFalse(toggle.isOn)
    }

    func testNativeControlAccessibilityKeepsInteractionTraitsWithoutAuthoredRoles() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        controller.loadViewIfNeeded()
        controller.render(document([
            ["type": "Switch", "props": ["key": "toggle", "value": true]],
            ["type": "Slider", "props": ["key": "slider", "value": 0.5]],
            ["type": "Picker", "props": ["key": "picker", "items": [["label": "One", "value": "one"]]]],
            ["type": "DatePicker", "props": ["key": "date"]],
        ]))

        let toggle = try XCTUnwrap(find(UISwitch.self, key: "toggle", below: controller.view))
        let slider = try XCTUnwrap(find(UISlider.self, key: "slider", below: controller.view))
        let picker = try XCTUnwrap(find(UIPickerView.self, key: "picker", below: controller.view))
        let date = try XCTUnwrap(find(UIDatePicker.self, key: "date", below: controller.view))
        XCTAssertEqual(toggle.accessibilityTraits, UISwitch().accessibilityTraits)
        XCTAssertTrue(slider.accessibilityTraits.contains(.adjustable))
        XCTAssertTrue(picker.accessibilityTraits.contains(.adjustable))
        XCTAssertTrue(date.accessibilityTraits.contains(.adjustable))
    }

    func testSwitchAccessibilityMatchesUIKitAcrossValueAndEnabledChanges() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        controller.loadViewIfNeeded()
        let reference = UISwitch()
        for (value, disabled) in [(false, false), (true, false), (true, true), (false, false)] {
            reference.isOn = value
            reference.isEnabled = !disabled
            controller.render(document([[
                "type": "Switch",
                "props": ["key": "native-toggle", "value": value, "disabled": disabled],
            ]]))
            let toggle = try XCTUnwrap(find(UISwitch.self, key: "native-toggle", below: controller.view))
            XCTAssertEqual(toggle.isOn, reference.isOn)
            XCTAssertEqual(toggle.isEnabled, reference.isEnabled)
            XCTAssertEqual(toggle.accessibilityTraits.rawValue, reference.accessibilityTraits.rawValue,
                           "Craft replaced the system switch's native accessibility identity")
        }
    }

    func testPickerBooleanValuesFallBackToTheirLabels() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        controller.loadViewIfNeeded()
        controller.evaluateScript("globalThis.__picked = null; globalThis.__stxNativeCallback = function(json) { const message = JSON.parse(json); if (message.payload && message.payload.handlerName === 'picked') globalThis.__picked = message.payload.nativeEvent.value; };")
        controller.render(document([[
            "type": "Picker",
            "props": [
                "key": "boolean-picker",
                "items": [["label": "Boolean option", "value": true], ["label": "String option", "value": "string"]],
            ],
            "events": ["onValueChange": "picked"],
        ]]))

        let picker = try XCTUnwrap(find(UIPickerView.self, key: "boolean-picker", below: controller.view))
        controller.pickerView(picker, didSelectRow: 0, inComponent: 0)
        XCTAssertEqual(controller.evaluateScript("__picked")?.toString(), "Boolean option")
    }

    func testTheScriptHearsNewParamsAndTheScreenComingBack() throws {
        let controller = CraftNativeScreenController(config: CraftConfig(), routeName: "Messages", routeParams: ["person": "4"])
        controller.loadViewIfNeeded()
        controller.evaluateScript("globalThis.__heard = []; globalThis.__stxNativeCallback = function(json) { var m = JSON.parse(json); if (m.type === 'ROUTE_PARAMS' || m.type === 'SCREEN_FOCUS') __heard.push(m.type + ':' + (m.type === 'ROUTE_PARAMS' ? m.payload.params.person : m.payload.focused)); };")
        controller.receiveRouteParams(["person": "8", "path": "/m/messages?person=8"])
        XCTAssertEqual(controller.evaluateScript("__stxNativeParams.person")?.toString(), "8")
        // The first showing is the mount; after that, away and back are news.
        controller.screenVisibilityChanged(true)
        controller.screenVisibilityChanged(false)
        controller.screenVisibilityChanged(true)
        controller.screenVisibilityChanged(true)
        XCTAssertEqual(controller.evaluateScript("__heard.join('|')")?.toString(), "ROUTE_PARAMS:8|SCREEN_FOCUS:false|SCREEN_FOCUS:true")
    }

    func testAVideoTakesItsSourceFromSrcToo() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        controller.loadViewIfNeeded()
        controller.render(document([[
            "type": "Video", "props": ["key": "clip", "src": "https://example.com/a.mp4", "controls": true], "style": ["height": 200], "events": ["onEnd": "ended"]
        ]]))
        XCTAssertNotNil(find(UIView.self, key: "clip", below: controller.view))
    }

    func testNativeBadgeDoesNotDependOnNotificationCapability() async {
        XCTAssertTrue(CraftNativeActions.capabilities(config: CraftConfig()).contains("badge"))
        guard case .success = await capability("Badge", "set", [3]) else {
            return XCTFail("native badge set failed")
        }
        guard case .success = await capability("Badge", "clear") else {
            return XCTFail("native badge clear failed")
        }
        guard case .failure(let error) = await capability("Badge", "set", [-1]) else {
            return XCTFail("negative badge unexpectedly succeeded")
        }
        XCTAssertEqual(error.code, "INVALID_ARGUMENT")
    }

    func testDecodesStreamedTextAcrossSplitCharacters() {
        let bytes = Array("data: đ✓\n".utf8)
        let (first, rest) = CraftNativeEventStreams.decodeUTF8(Data(bytes[0..<7]))
        XCTAssertEqual(first, "data: ")
        let (second, tail) = CraftNativeEventStreams.decodeUTF8(rest + Data(bytes[7...]))
        XCTAssertEqual(first + second, "data: đ✓\n")
        XCTAssertTrue(tail.isEmpty)
    }
}
