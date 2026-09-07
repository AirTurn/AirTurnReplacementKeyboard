import XCTest
import KeyboardKit
@testable import AirTurnReplacementKeyboard

/// Renders the real `AirTurnReplacementKeyboardViewController` inside a fixed-height
/// host, the way `AirTurnKeyboardManager` embeds it, and checks the alphabetic/numeric
/// layout — the one `KeyboardLayout.preparedForHost` actually scales — never
/// renders taller than the host it's given. It also verifies
/// `synchronizeKeyboardLayoutSize`'s resize-request logic directly, bypassing SwiftUI's
/// `GeometryReader`/`PreferenceKey` reporting pipeline that feeds it in production: that
/// pipeline requires genuine screen compositing to fire — confirmed, while investigating
/// this, to never report a non-zero size in a headless XCTest-hosted `UIWindow` — so a
/// test relying on it would never actually exercise the code under test.
///
/// Emoji sizing is independent of KeyboardLayout. These tests exercise resize
/// reporting; app-hosted UI tests cover the licensed emoji grid, its lower
/// controls, and switching back to alphabetic input.
///
/// All scenarios share a single hosted controller instance. KeyboardKit's setup
/// performs an async license lookup per controller instance that this sandboxed
/// test environment cannot reach the network to resolve; a second instance created
/// in the same process hangs the test run waiting on it, so this file must not
/// instantiate more than one `AirTurnReplacementKeyboardViewController`.
@MainActor
final class AirTurnReplacementKeyboardRenderingTests: XCTestCase {
    private var window: UIWindow?
    private var hostViewController: UIViewController?
    private var replacementController: AirTurnReplacementKeyboardViewController?

    override func tearDown() {
        replacementController?.willMove(toParent: nil)
        replacementController?.view.removeFromSuperview()
        replacementController?.removeFromParent()
        replacementController = nil

        hostViewController?.view.removeFromSuperview()
        hostViewController = nil

        window?.rootViewController = nil
        window?.isHidden = true
        window = nil

        super.tearDown()
    }

    func testAlphabeticKeyboardFitsAndResizeRequestBehavior() {
        let controller = makeHostedController()
        settle(controller)

        let bounds = controller.view.bounds
        let maxY = deepestVisibleMaxY(in: controller.view)
        XCTAssertLessThanOrEqual(
            maxY,
            bounds.height + 0.5,
            "The alphabetic keyboard's rendered content (extends to \(maxY)pt) "
                + "overflows the host view's bounds (\(bounds.height)pt)."
        )

        let heightWithoutSuggestions = controller.maximumHeight
        controller.enableAutoCorrect = true
        settle(controller)
        XCTAssertEqual(controller.maximumHeight,
                       heightWithoutSuggestions + SystemKeyboardGeometry.autocompleteToolbarHeight,
                       accuracy: 0.5)
        XCTAssertLessThanOrEqual(deepestVisibleMaxY(in: controller.view),
                                 controller.view.bounds.height + 0.5,
                                 "Suggestions and footer must fit inside the keyboard host")
        controller.enableAutoCorrect = false
        settle(controller)
        XCTAssertEqual(controller.maximumHeight, heightWithoutSuggestions, accuracy: 0.5)

        let maximumHeightBefore = controller.maximumHeight
        let preferredContentSizeBefore = controller.preferredContentSize

        controller.synchronizeKeyboardLayoutSize(.zero)
        controller.synchronizeKeyboardLayoutSize(CGSize(width: CGFloat.nan, height: 300))
        controller.synchronizeKeyboardLayoutSize(CGSize(width: 393, height: CGFloat.infinity))
        XCTAssertEqual(
            controller.preferredContentSize,
            preferredContentSizeBefore,
            "Non-finite or empty reported sizes should be ignored."
        )

        // Simulates the emoji keyboard's grid (whose height isn't governed by
        // layout.preparedForHost) reporting a render taller than the
        // current host.
        controller.state.keyboardContext.keyboardType = .emojis
        let tallerReportedHeight = controller.view.bounds.height + 84
        controller.synchronizeKeyboardLayoutSize(CGSize(width: 393, height: tallerReportedHeight))

        XCTAssertEqual(
            controller.preferredContentSize.height,
            tallerReportedHeight,
            "A taller report should grow preferredContentSize so UIKit can give the "
                + "keyboard more room instead of the content being clipped."
        )
        XCTAssertEqual(
            controller.maximumHeight,
            maximumHeightBefore,
            "maximumHeight is the target layout.preparedForHost scales the "
                + "alphabetic/numeric layout to, and is anchored from the system "
                + "keyboard height estimate, not from reported emoji render sizes — "
                + "otherwise the emoji keyboard growing the host would leave the "
                + "alphabetic layout permanently fitted to the wrong, larger height "
                + "the next time it's shown."
        )
    }

    // MARK: - Helpers

    /// Hosts a real `AirTurnReplacementKeyboardViewController` in a window whose
    /// height matches the estimated system keyboard height, mirroring the host
    /// size `updateHostGeometryParameters` requests via `preferredContentSize`.
    private func makeHostedController() -> AirTurnReplacementKeyboardViewController {
        let context = KeyboardContext()
        context.deviceTypeForKeyboard = .phone
        context.screenSize = CGSize(width: 393, height: 852)
        context.interfaceOrientation = .portrait
        context.locales = [.english]
        context.keyboardType = .alphabetic
        let hostHeight = SystemKeyboardGeometry.estimatedHeight(
            screenSize: context.screenSize,
            orientation: .portrait,
            deviceType: .phone,
            bottomSafeAreaInset: 34,
            includeAutocompleteToolbar: false
        )

        let controller = AirTurnReplacementKeyboardViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIViewController()
        window.rootViewController = host
        window.makeKeyAndVisible()
        self.window = window
        self.hostViewController = host
        self.replacementController = controller

        controller.view.frame = CGRect(x: 0, y: 0, width: 393, height: hostHeight)
        host.addChild(controller)
        host.view.addSubview(controller.view)
        controller.didMove(toParent: host)

        return controller
    }

    private func settle(_ controller: UIViewController) {
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(1.0))
        controller.view.layoutIfNeeded()
    }

    /// The furthest bottom edge, in `root`'s coordinate space, that is actually
    /// rendered (not masked out by an ancestor's `clipsToBounds`) among every
    /// visible descendant of `root`. A descendant's raw `frame` can extend past
    /// an ancestor's bounds without producing any visible overflow as long as
    /// that ancestor clips — mirroring what Core Animation actually draws is
    /// what distinguishes genuine bleed past the host from harmless oversized
    /// layout that gets masked away before it reaches the host's edge.
    private func deepestVisibleMaxY(in root: UIView) -> CGFloat {
        // Effectively unbounded, without risking overflow/NaN in CGRect math.
        let unclipped = CGRect(x: -1e6, y: -1e6, width: 2e6, height: 2e6)

        var maxY: CGFloat = 0
        func walk(_ view: UIView, visibleClip: CGRect) {
            guard !view.isHidden, view.alpha > 0 else { return }

            let frameInRoot = view.convert(view.bounds, to: root)
            let effectiveRect = frameInRoot.intersection(visibleClip)
            if !effectiveRect.isNull, !effectiveRect.isEmpty {
                maxY = max(maxY, effectiveRect.maxY)
            }

            let childClip = view.clipsToBounds ? frameInRoot.intersection(visibleClip) : visibleClip
            for subview in view.subviews {
                walk(subview, visibleClip: childClip)
            }
        }
        for subview in root.subviews { walk(subview, visibleClip: unclipped) }
        return maxY
    }
}
