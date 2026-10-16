import UIKit
import XCTest
@testable import NativeNavigation

/// Drive the real UIKit gesture target and inspect the hosted native stacks,
/// including frames while the finger is down. UI tests cover touch routing.
@MainActor
final class NativeNavigationUnitTests: XCTestCase {
    private final class Pan: UIPanGestureRecognizer {
        var phase: UIGestureRecognizer.State = .changed
        var distance: CGFloat = 0
        var speed: CGFloat = 0
        override var state: UIGestureRecognizer.State {
            get { phase }
            set { phase = newValue }
        }
        override func translation(in view: UIView?) -> CGPoint { CGPoint(x: distance, y: 0) }
        override func velocity(in view: UIView?) -> CGPoint { CGPoint(x: speed, y: 0) }
    }

    @MainActor
    private final class DisplayWait: NSObject {
        private let ready: () -> Bool
        private let finished: XCTestExpectation
        private var link: CADisplayLink?
        init(ready: @escaping () -> Bool, finished: XCTestExpectation) {
            self.ready = ready
            self.finished = finished
            super.init()
        }
        func start() {
            link = CADisplayLink(target: self, selector: #selector(frame))
            link?.add(to: .main, forMode: .common)
        }
        @objc private func frame() {
            if ready() { stop(); finished.fulfill() }
        }
        func stop() { link?.invalidate(); link = nil }
    }

    private var shell: CraftHybridController!
    private var window: UIWindow!
    private var previous: CraftHybridController?
    private var previousWindow: UIWindow?
    private var selection: String?
    private let pan = Pan()

    override func setUp() async throws {
        try await super.setUp()
        await displayWait("native host window connected") {
            CraftHybrid.shared.controller?.viewIfLoaded?.window?.windowScene != nil
        }
        previous = CraftHybrid.shared.controller
        previousWindow = previous?.view.window
        selection = CraftChrome.shared.selected
        CraftChrome.shared.selected = "/"
        shell = CraftHybridController(config: CraftHybrid.shared.config)
        let scene = previousWindow?.windowScene
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        if let scene {
            window = UIWindow(windowScene: scene)
        } else {
            window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        }
        window.rootViewController = shell
        window.makeKeyAndVisible()
        XCTAssertNotNil(window.windowScene, "hosted UIKit tests need a connected scene")
        shell.view.frame = window.bounds
        shell.view.layoutIfNeeded()
    }

    override func tearDown() {
        if let shell { _ = shell.tabTapped("/", reselect: false) }
        window?.isHidden = true
        window?.rootViewController = nil
        shell = nil
        window = nil
        CraftHybrid.shared.controller = previous
        CraftChrome.shared.selected = selection
        previous = nil
        previousWindow?.makeKeyAndVisible()
        previousWindow = nil
        super.tearDown()
    }

    private func drag(_ distance: CGFloat, phase: UIGestureRecognizer.State = .changed, speed: CGFloat = 0) {
        pan.distance = distance
        pan.speed = speed
        pan.phase = phase
        shell.perform(NSSelectorFromString("tabSwipeRecognized:"), with: pan)
    }

    private func stack(_ path: String) -> UINavigationController? {
        shell.children.compactMap { $0 as? UINavigationController }.first {
            ($0.viewControllers.first as? CraftNativeScreenController)?.routeParams["path"] as? String == path
        }
    }

    func testColdLinkWaitsForTheConstructedShellToLoadItsStacks() async throws {
        let earlyShell = CraftHybridController(config: CraftHybrid.shared.config)
        XCTAssertFalse(earlyShell.isViewLoaded)
        defer {
            window.rootViewController = shell
            CraftHybrid.shared.controller = shell
        }

        let url = try XCTUnwrap(URL(string: "https://example.com/linked-details?name=Cold"))
        XCTAssertTrue(CraftHybrid.shared.handleDeepLink(url))
        window.rootViewController = earlyShell
        earlyShell.view.frame = window.bounds
        earlyShell.view.layoutIfNeeded()

        await displayWait("the cold link reaches its screen after the shell mounts") {
            earlyShell.children.compactMap { $0 as? UINavigationController }.contains {
                guard let screen = $0.topViewController as? CraftNativeScreenController else { return false }
                return screen.routeParams["path"] as? String == "/linked-details?name=Cold"
                    && screen.routeParams["name"] as? String == "Cold"
            }
        }
    }

    private func displayWait(_ description: String, diagnostic: @escaping () -> String = { "" }, ready: @escaping () -> Bool) async {
        let finished = expectation(description: description)
        let display = DisplayWait(ready: ready, finished: finished)
        display.start()
        let result = await XCTWaiter.fulfillment(of: [finished], timeout: 15)
        display.stop()
        XCTAssertEqual(result, .completed, "\(description): \(diagnostic())")
    }

    private func renderFrames() async {
        CATransaction.flush()
        var frames = 0
        await displayWait("native frames rendered") { frames += 1; return frames >= 2 }
    }

    private func settle() async {
        await displayWait("native settle animation completed", diagnostic: { [self] in
            shell.children.compactMap { $0 as? UINavigationController }.map {
                "frame=\($0.view.frame), expected=\(shell.view.bounds), hidden=\($0.view.isHidden), animations=\($0.view.layer.animationKeys() ?? [])"
            }.joined(separator: "; ")
        }) { [self] in
            shell.children.compactMap { $0 as? UINavigationController }.allSatisfy {
                let frame = $0.view.frame
                let bounds = shell.view.bounds
                return abs(frame.minX - bounds.minX) <= 0.5 && abs(frame.minY - bounds.minY) <= 0.5
                    && abs(frame.width - bounds.width) <= 0.5 && abs(frame.height - bounds.height) <= 0.5
                    && ($0.view.layer.animationKeys()?.isEmpty ?? true)
            }
        }
        await renderFrames()
    }

    private func attachFrame(_ name: String) {
        let image = UIGraphicsImageRenderer(bounds: shell.view.bounds).image { shell.view.layer.render(in: $0.cgContext) }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func mountDetails() {
        _ = shell.tabTapped("/details", reselect: false)
        _ = shell.tabTapped("/", reselect: false)
        CraftChrome.shared.selected = "/"
    }

    func testNativeLinkRetainsItsTapRecognizerAcrossUnrelatedUpdates() throws {
        let controller = CraftNativeScreenController(config: CraftConfig())
        controller.loadViewIfNeeded()
        func document(_ count: Int, enabled: Bool = true) -> [String: Any] {
            ["type": "View", "children": [
                ["type": "TouchableOpacity", "props": ["testID": "link-probe", "href": "/linked-details", "accessibilityRole": "link", "accessibilityLabel": "Open details", "disabled": !enabled],
                 "children": [["type": "Text", "children": ["Open details"]]]],
                ["type": "Text", "props": ["testID": "unrelated-count"], "children": ["Count: \(count)"]],
            ]]
        }
        func find(_ view: UIView) -> UIView? {
            if view.accessibilityIdentifier == "link-probe" { return view }
            return view.subviews.lazy.compactMap { find($0) }.first
        }
        controller.render(document(0))
        let link = try XCTUnwrap(find(controller.view))
        for count in 1...4 {
            controller.render(document(count))
            XCTAssertTrue(find(controller.view) === link, "a count update replaced the native link")
            XCTAssertEqual(link.gestureRecognizers?.filter { $0 is UITapGestureRecognizer }.count, 1,
                           "an unrelated screen update removed or duplicated the native link's tap recognizer")
            XCTAssertTrue(link.isUserInteractionEnabled)
        }
        controller.render(document(5, enabled: false))
        XCTAssertEqual(link.gestureRecognizers?.filter { $0 is UITapGestureRecognizer }.count ?? 0, 0)
        controller.render(document(6))
        XCTAssertEqual(link.gestureRecognizers?.filter { $0 is UITapGestureRecognizer }.count, 1)
    }

    func testFirstSwipeMountsAnUnvisitedNativeTabBesideTheCurrentScreen() async throws {
        XCTAssertNil(stack("/details"))
        let width = shell.view.bounds.width
        drag(-150)
        let incoming = try XCTUnwrap(stack("/details"), "a first visit must participate in the interactive transition")
        let outgoing = try XCTUnwrap(stack("/"))
        XCTAssertEqual(incoming.view.frame.minX, width - 150, accuracy: 0.5)
        XCTAssertEqual(outgoing.view.frame.maxX, incoming.view.frame.minX, accuracy: 0.5)
        drag(-150, phase: .cancelled)
        await settle()
    }

    func testIncomingTabKeepsItsEdgePastHalfwayInBothDirections() async throws {
        mountDetails()
        let width = shell.view.bounds.width
        let home = try XCTUnwrap(stack("/"))
        let details = try XCTUnwrap(stack("/details"))
        for amount in [CGFloat(150), width * 0.75, width] {
            drag(-amount)
            XCTAssertEqual(details.view.frame.minX, width - amount, accuracy: 0.5)
            XCTAssertEqual(home.view.frame.maxX, details.view.frame.minX, accuracy: 0.5)
        }
        attachFrame("Left swipe beyond halfway")
        drag(-width, phase: .ended)
        await settle()
        XCTAssertTrue(home.view.isHidden)
        XCTAssertFalse(details.view.isHidden)
        XCTAssertEqual(details.view.frame, shell.view.bounds)
        for amount in [CGFloat(150), width * 0.75, width] {
            drag(amount)
            XCTAssertEqual(home.view.frame.maxX, amount, accuracy: 0.5)
            XCTAssertEqual(home.view.frame.maxX, details.view.frame.minX, accuracy: 0.5)
        }
        attachFrame("Right swipe beyond halfway")
        drag(width, phase: .ended)
        await settle()
        XCTAssertEqual(CraftChrome.shared.selected, "/")
        XCTAssertFalse(home.view.isHidden)
        XCTAssertEqual(home.view.frame, shell.view.bounds)
    }

    func testReleaseAnimatesToTheDestinationInsteadOfJumping() async throws {
        mountDetails()
        let details = try XCTUnwrap(stack("/details"))
        let width = shell.view.bounds.width
        drag(-width * 0.4)
        let start = details.view.frame.minX
        attachFrame("Incoming native tab follows the finger")
        // A real drag renders before release; beginning and ending in one
        // run-loop turn can otherwise animate from an uncommitted layer.
        await renderFrames()
        let releasedAt = CACurrentMediaTime()
        drag(-width * 0.4, phase: .ended)
        if !UIAccessibility.isReduceMotionEnabled {
            let animation = try XCTUnwrap(details.view.layer.animation(forKey: "position") as? CABasicAnimation,
                                          "UIKit must hand the settle to the native compositor")
            let from = try XCTUnwrap(animation.fromValue as? NSValue).cgPointValue
            let to = try XCTUnwrap(animation.toValue as? NSValue).cgPointValue
            XCTAssertEqual(animation.duration, 0.22, accuracy: 0.001)
            XCTAssertEqual(from.x - to.x, start, accuracy: 0.5)
            XCTAssertEqual(to.x, animation.isAdditive ? 0 : width * 0.5, accuracy: 0.5)
        }
        let sample = expectation(description: "sample a settling animation frame")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            let elapsed = CACurrentMediaTime() - releasedAt
            // A loaded simulator may schedule this after the animation has
            // finished. Its native interpolation was still required above.
            if !UIAccessibility.isReduceMotionEnabled && elapsed < 0.19 {
                let frame = details.view.layer.presentation()?.frame ?? details.view.frame
                XCTAssertGreaterThan(frame.minX, 0.5, "the native transition jumped to its final frame")
                XCTAssertLessThan(frame.minX, start, "the native transition never advanced")
            }
            sample.fulfill()
        }
        await fulfillment(of: [sample], timeout: 15)
        await settle()
        XCTAssertEqual(details.view.frame, shell.view.bounds)
        XCTAssertFalse(details.view.isHidden)
        XCTAssertEqual(CraftChrome.shared.selected, "/details")
    }

    func testShortAndSystemCancelledSwipesRestoreBothStacksAndSelection() async throws {
        mountDetails()
        let home = try XCTUnwrap(stack("/"))
        let details = try XCTUnwrap(stack("/details"))
        for phase in [UIGestureRecognizer.State.ended, .cancelled, .failed] {
            drag(-50)
            drag(-50, phase: phase)
            await settle()
            XCTAssertEqual(CraftChrome.shared.selected, "/")
            XCTAssertFalse(home.view.isHidden)
            XCTAssertTrue(details.view.isHidden)
            XCTAssertEqual(home.view.frame, shell.view.bounds)
            XCTAssertEqual(details.view.frame, shell.view.bounds)
        }
    }

    func testReversingTheDragNeverExposesTheBackgroundOrSelectsTheWrongTab() async throws {
        mountDetails()
        let home = try XCTUnwrap(stack("/"))
        let details = try XCTUnwrap(stack("/details"))
        drag(-150)
        drag(70)
        XCTAssertEqual(home.view.frame.minX, 0, accuracy: 0.5)
        XCTAssertEqual(details.view.frame.minX, shell.view.bounds.width, accuracy: 0.5)
        drag(70, phase: .ended, speed: 800)
        await settle()
        XCTAssertEqual(CraftChrome.shared.selected, "/")
        XCTAssertEqual(home.view.frame, shell.view.bounds)
    }

    func testTabTapDuringSettlingWinsOverTheSwipeCompletion() async throws {
        mountDetails()
        let home = try XCTUnwrap(stack("/"))
        let details = try XCTUnwrap(stack("/details"))
        for path in ["/", "/third", "/details"] {
            _ = shell.tabTapped("/", reselect: false)
            CraftChrome.shared.selected = "/"
            drag(-shell.view.bounds.width * 0.4)
            drag(-shell.view.bounds.width * 0.4, phase: .ended)
            let tab = try XCTUnwrap(CraftChrome.shared.tabs.first { $0.id == path })
            CraftChrome.shared.tap(tab)
            let selected = try XCTUnwrap(stack(path))
            XCTAssertFalse(selected.view.isHidden, "the newer tab tap must take effect immediately")
            XCTAssertEqual(selected.view.frame, shell.view.bounds)
            XCTAssertTrue(selected.view.layer.animationKeys()?.isEmpty ?? true)
            await settle()
            XCTAssertEqual(CraftChrome.shared.selected, path, "a completed swipe overrode the newer tab tap")
            XCTAssertEqual(home.view.isHidden, path != "/")
            XCTAssertEqual(details.view.isHidden, path != "/details")
            XCTAssertEqual(selected.view.frame, shell.view.bounds)
        }
    }

    func testDeferredPageSelectionCannotOverrideANewerNativeTabTap() async throws {
        mountDetails()
        // A page reports its tab while a native stack owns the screen. The
        // shell defers correcting that report; another real tab tap arrives
        // before the correction runs (for example while a cold root mounts).
        CraftChrome.shared.handle(["type": "selectTab", "id": "/details"])
        let third = try XCTUnwrap(CraftChrome.shared.tabs.first { $0.id == "/third" })
        CraftChrome.shared.tap(third)
        XCTAssertEqual(CraftChrome.shared.selected, "/third")
        await renderFrames()
        XCTAssertEqual(CraftChrome.shared.selected, "/third", "a stale page correction changed the selected tab")
        XCTAssertFalse(try XCTUnwrap(stack("/third")).view.isHidden)
        XCTAssertTrue(try XCTUnwrap(stack("/")).view.isHidden)
    }

    func testDeferredPageSelectionPreservesANewerInteractiveSwipePreview() async throws {
        mountDetails()
        for reported in ["/third", "/details"] {
            CraftChrome.shared.handle(["type": "selectTab", "id": reported])
            drag(-150)
            XCTAssertEqual(CraftChrome.shared.selected, "/details")
            await renderFrames()
            XCTAssertEqual(CraftChrome.shared.selected, "/details", "a stale page correction cleared the finger's tab preview")
            drag(-150, phase: .cancelled)
            await settle()
            XCTAssertEqual(CraftChrome.shared.selected, "/", "cancellation must restore the native owning tab, not the page's stale report")
            XCTAssertFalse(try XCTUnwrap(stack("/")).view.isHidden)
        }
    }

    func testPageReportingTheOutgoingRootCannotClearAnActiveSwipePreview() async throws {
        mountDetails()
        drag(-150)
        CraftChrome.shared.handle(["type": "selectTab", "id": "/"])
        await renderFrames()
        XCTAssertEqual(CraftChrome.shared.selected, "/details", "the finger's preview owns selection until the gesture settles")
        drag(-150, phase: .cancelled)
        await settle()
        XCTAssertEqual(CraftChrome.shared.selected, "/")
    }

    func testSwipeAfterATabTapCannotBeChangedByTheOlderAnimation() async throws {
        mountDetails()
        let details = try XCTUnwrap(stack("/details"))
        let width = shell.view.bounds.width
        drag(-width * 0.4)
        drag(-width * 0.4, phase: .ended)
        let homeTab = try XCTUnwrap(CraftChrome.shared.tabs.first { $0.id == "/" })
        CraftChrome.shared.tap(homeTab)
        drag(-width * 0.4)
        XCTAssertEqual(details.view.frame.minX, width * 0.6, accuracy: 0.5)
        drag(-width * 0.4, phase: .ended)
        await settle()
        XCTAssertEqual(CraftChrome.shared.selected, "/details")
        XCTAssertFalse(details.view.isHidden)
        XCTAssertEqual(details.view.frame, shell.view.bounds)
    }
}
