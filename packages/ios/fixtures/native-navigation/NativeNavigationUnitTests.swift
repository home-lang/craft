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

    private var shell: CraftHybridController!
    private var window: UIWindow!
    private var previous: CraftHybridController?
    private var previousWindow: UIWindow?
    private var selection: String?
    private let pan = Pan()

    override func setUp() {
        super.setUp()
        previous = CraftHybrid.shared.controller
        previousWindow = previous?.view.window
        selection = CraftChrome.shared.selected
        CraftChrome.shared.selected = "/"
        shell = CraftHybridController(config: CraftHybrid.shared.config)
        if let scene = previousWindow?.windowScene {
            window = UIWindow(windowScene: scene)
        } else {
            window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        }
        window.rootViewController = shell
        window.makeKeyAndVisible()
        shell.view.frame = window.bounds
        shell.view.layoutIfNeeded()
    }

    override func tearDown() {
        window.isHidden = true
        window.rootViewController = nil
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

    private func settle() {
        let finished = expectation(description: "native settle animation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { finished.fulfill() }
        wait(for: [finished], timeout: 2)
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

    func testFirstSwipeMountsAnUnvisitedNativeTabBesideTheCurrentScreen() throws {
        XCTAssertNil(stack("/details"))
        let width = shell.view.bounds.width
        drag(-150)
        let incoming = try XCTUnwrap(stack("/details"), "a first visit must participate in the interactive transition")
        let outgoing = try XCTUnwrap(stack("/"))
        XCTAssertEqual(incoming.view.frame.minX, width - 150, accuracy: 0.5)
        XCTAssertEqual(outgoing.view.frame.maxX, incoming.view.frame.minX, accuracy: 0.5)
        drag(-150, phase: .cancelled)
        settle()
    }

    func testIncomingTabKeepsItsEdgePastHalfwayInBothDirections() throws {
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
        settle()
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
        settle()
        XCTAssertEqual(CraftChrome.shared.selected, "/")
        XCTAssertFalse(home.view.isHidden)
        XCTAssertEqual(home.view.frame, shell.view.bounds)
    }

    func testReleaseAnimatesToTheDestinationInsteadOfJumping() throws {
        mountDetails()
        let details = try XCTUnwrap(stack("/details"))
        let width = shell.view.bounds.width
        drag(-width * 0.4)
        let start = details.view.frame.minX
        attachFrame("Incoming native tab follows the finger")
        drag(-width * 0.4, phase: .ended)
        let sample = expectation(description: "sample a settling animation frame")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            if !UIAccessibility.isReduceMotionEnabled {
                let frame = details.view.layer.presentation()?.frame ?? details.view.frame
                XCTAssertGreaterThan(frame.minX, 0.5, "the native transition jumped to its final frame")
                XCTAssertLessThan(frame.minX, start, "the native transition never advanced")
            }
            sample.fulfill()
        }
        wait(for: [sample], timeout: 2)
        settle()
        XCTAssertEqual(details.view.frame, shell.view.bounds)
        XCTAssertFalse(details.view.isHidden)
        XCTAssertEqual(CraftChrome.shared.selected, "/details")
    }

    func testShortAndSystemCancelledSwipesRestoreBothStacksAndSelection() throws {
        mountDetails()
        let home = try XCTUnwrap(stack("/"))
        let details = try XCTUnwrap(stack("/details"))
        for phase in [UIGestureRecognizer.State.ended, .cancelled, .failed] {
            drag(-50)
            drag(-50, phase: phase)
            settle()
            XCTAssertEqual(CraftChrome.shared.selected, "/")
            XCTAssertFalse(home.view.isHidden)
            XCTAssertTrue(details.view.isHidden)
            XCTAssertEqual(home.view.frame, shell.view.bounds)
            XCTAssertEqual(details.view.frame, shell.view.bounds)
        }
    }

    func testReversingTheDragNeverExposesTheBackgroundOrSelectsTheWrongTab() throws {
        mountDetails()
        let home = try XCTUnwrap(stack("/"))
        let details = try XCTUnwrap(stack("/details"))
        drag(-150)
        drag(70)
        XCTAssertEqual(home.view.frame.minX, 0, accuracy: 0.5)
        XCTAssertEqual(details.view.frame.minX, shell.view.bounds.width, accuracy: 0.5)
        drag(70, phase: .ended, speed: 800)
        settle()
        XCTAssertEqual(CraftChrome.shared.selected, "/")
        XCTAssertEqual(home.view.frame, shell.view.bounds)
    }
}
