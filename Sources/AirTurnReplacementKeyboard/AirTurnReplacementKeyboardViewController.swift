import Combine
import KeyboardKit
import SwiftUI
import UIKit

/// Presents a system-style software keyboard inside an application when an
/// attached AirTurn pedal causes iOS to hide its own software keyboard.
@objc(AirTurnReplacementKeyboardViewController)
@MainActor
public final class AirTurnReplacementKeyboardViewController: KeyboardInputViewController {
    private static let currentLocaleKey = "com.airturn.AirTurnReplacementKeyboard.currentLocale"

    private let viewParameters = AirTurnReplacementKeyboardViewParameters()
    private var currentLocaleCancellable: AnyCancellable?
    /// Keeps the UIKit `inputView` height at the system keyboard size.
    /// AirTurn installs `keyboardView` as a plain `inputView`, which sizes from
    /// the view's frame/constraints — not from `preferredContentSize`.
    private var hostHeightConstraint: NSLayoutConstraint?

    /// The host height `layout.preparedForHost` scales the alphabetic/
    /// numeric layout to. Exposed read-only for tests.
    internal var maximumHeight: CGFloat { viewParameters.maximumHeight }

    /// Bottom safe-area inset applied as layout edge padding so the bottom
    /// key row clears the home indicator when embedded as an `inputView`.
    internal var bottomSafeAreaInset: CGFloat { viewParameters.bottomSafeAreaInset }

    @objc(enableAutoCorrect)
    public var enableAutoCorrect = false {
        didSet { applyAutocompleteConfiguration() }
    }

    @objc(keyboardLocale)
    public var keyboardLocale: Locale = .english_us {
        didSet { state.keyboardContext.locale = keyboardLocale }
    }

#if ATRK_PRO
    /// KeyboardKit 10 requires a current subscription key or v10 licence file.
    /// The existing property name is retained for source and Objective-C
    /// compatibility with applications that used the previous wrapper.
    @objc(keyboardKitProLicenseKey)
    public static var keyboardKitProLicenseKey: String?
#endif

    @objc(allKeyboardKitLocales)
    public static var allKeyboardKitLocales: [Locale] {
#if ATRK_PRO
        .keyboardKitSupported
#else
        [.english]
#endif
    }

    /// Returns the enabled iOS keyboard locales supported by this product,
    /// retaining their system order and always providing an English fallback.
    @objc(configuredKeyboardKitLocales)
    public static var configuredKeyboardKitLocales: [Locale] {
        return configuredKeyboardKitLocales(from: UITextInputMode.activeInputModes)
    }

    internal static func configuredKeyboardKitLocales(from inputModes: [UITextInputMode]) -> [Locale] {
        configuredKeyboardKitLocales(
            from: inputModes.compactMap { $0.primaryLanguage?.replacingOccurrences(of: "-", with: "_") }
        )
    }

    internal static func configuredKeyboardKitLocales(from inputModeIdentifiers: [String]) -> [Locale] {
        var seen = Set<String>()
        let locales = inputModeIdentifiers.compactMap { (identifier: String) -> Locale? in
            let normalized = identifier.replacingOccurrences(of: "-", with: "_")
            let language = normalized.split(separator: "_").first.map(String.init)
            guard let locale = allKeyboardKitLocales.first(where: {
                $0.identifier.replacingOccurrences(of: "-", with: "_") == normalized
                    || $0.language.languageCode?.identifier == language
            }) else { return nil }
            guard seen.insert(locale.identifier).inserted else { return nil }
            return locale
        }
        return locales.isEmpty ? [.english] : locales
    }

    public override func viewWillSetupKeyboardKit() {
        synchronizeKeyboardContextWithActiveScene()

        let app = KeyboardApp(
            name: "AirTurn Replacement Keyboard",
            licenseKey: Self.licenseKey,
            locales: Self.configuredKeyboardKitLocales
        )

        setupKeyboardKit(for: app) { [weak self] result in
            switch result {
            case .success(let license):
                NSLog(
                    "AirTurnReplacementKeyboard: KeyboardKit setup succeeded (license=%@)",
                    license.map { String(describing: $0) } ?? "nil"
                )
            case .failure(let error):
                NSLog(
                    "AirTurnReplacementKeyboard: KeyboardKit setup failed (%@). "
                        + "Emoji and extra locales require a current KeyboardKit 10 license key.",
                    String(describing: error)
                )
            }
            guard let self else { return }
            let actionHandler = AirTurnKeyboardActionHandler(controller: self)
            actionHandler.onNextLocale = { [weak self] in
                self?.refreshConfiguredKeyboardLocales()
            }
            self.services.actionHandler = actionHandler
            self.applyConfiguration()
        }
    }

    public override func viewWillSetupKeyboardView() {
        let parameters = viewParameters
        updateHostGeometryParameters()
        setupKeyboardView { [weak self] controller in
            AirTurnReplacementKeyboardView(
                services: controller.services,
                state: controller.state,
                parameters: parameters,
                onSizeChange: { [weak self] size in
                    self?.synchronizeKeyboardLayoutSize(size)
                }
            )
        }
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshConfiguredKeyboardLocales()
        updateHostGeometryParameters()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Re-apply system-height sizing after each layout pass so a short
        // natural KeyboardKit intrinsic size cannot permanently shrink the
        // alphabetic/numeric host below the system keyboard.
        updateHostGeometryParameters()
    }

    public override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateHostGeometryParameters()
    }

    /// Re-anchors alphabetic/numeric sizing to the system keyboard height for
    /// the destination size. Emoji growth of `preferredContentSize` is cleared
    /// on rotation so the next alphabetic layout starts from the system size.
    public override func viewWillTransition(
        to size: CGSize,
        with coordinator: any UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)
        updateHostGeometryParameters(screenSizeOverride: size)
    }

    /// Syncs host height and bottom safe-area inset used by the SwiftUI layout.
    ///
    /// Drives `preferredContentSize` to an estimated system keyboard height so
    /// the UIKit/`AirTurnKeyboardManager` host matches Apple's keyboard size
    /// class. KeyboardKit's natural alphabetic layout is only ~216pt; without
    /// this, the in-app `inputView` stays short and keys never reach system size.
    ///
    /// - Parameter screenSizeOverride: Optional size used during rotation
    ///   before the window reports the new bounds.
    private func updateHostGeometryParameters(screenSizeOverride: CGSize? = nil) {
        let bottomInset = resolvedBottomSafeAreaInset()
        viewParameters.bottomSafeAreaInset = bottomInset

        let screenSize = resolvedScreenSize(override: screenSizeOverride)
        let orientation = resolvedInterfaceOrientation(screenSize: screenSize)
        let estimated = SystemKeyboardGeometry.estimatedHeight(
            screenSize: screenSize,
            orientation: orientation,
            deviceType: state.keyboardContext.deviceTypeForKeyboard,
            bottomSafeAreaInset: bottomInset,
            includeAutocompleteToolbar: enableAutoCorrect
        )

        let width: CGFloat = {
            if let overrideWidth = screenSizeOverride?.width, overrideWidth > 0 {
                return overrideWidth
            }
            let boundsWidth = view.bounds.width
            return boundsWidth > 0 ? boundsWidth : max(preferredContentSize.width, screenSize.width, 1)
        }()

        let type = state.keyboardContext.keyboardType
        if type == .emojis {
            // Emoji may already have grown the host; never shrink below system.
            let height = max(preferredContentSize.height, estimated)
            applyInputViewHostHeight(height, width: width)
            viewParameters.maximumHeight = max(viewParameters.maximumHeight, estimated)
        } else {
            // Alphabetic/numeric: lock to system height (shrink after emoji).
            applyInputViewHostHeight(estimated, width: width)
            viewParameters.maximumHeight = estimated
        }

        if state.keyboardContext.isLiquidGlassAvailable {
            state.keyboardContext.isLiquidGlassEnabled = true
        }
    }

    /// Applies the host height UIKit and AirTurn use when this controller's
    /// view is installed as a plain `inputView` (not as `inputViewController`).
    ///
    /// - Parameters:
    ///   - height: Target keyboard height in points.
    ///   - width: Target keyboard width in points.
    private func applyInputViewHostHeight(_ height: CGFloat, width: CGFloat) {
        guard height.isFinite, height > 0 else { return }

        preferredContentSize = CGSize(
            width: width > 0 ? width : max(preferredContentSize.width, 1),
            height: height
        )

        if let inputView = inputView {
            inputView.allowsSelfSizing = true
        }

        // Match KeyboardKit's standard keyboard chrome so UIKit doesn't show
        // the app through a short SwiftUI background while keys scale taller.
        view.backgroundColor = UIColor { traits in
            let scheme: ColorScheme = traits.userInterfaceStyle == .dark ? .dark : .light
            return UIColor(Color.keyboardBackground(for: scheme))
        }
        inputView?.backgroundColor = view.backgroundColor

        var frame = view.frame
        if width > 0 {
            frame.size.width = width
        }
        frame.size.height = height
        if view.frame.size != frame.size {
            view.frame = frame
        }

        if let hostHeightConstraint {
            if abs(hostHeightConstraint.constant - height) > 0.5 {
                hostHeightConstraint.constant = height
            }
        } else {
            let constraint = view.heightAnchor.constraint(equalToConstant: height)
            // Slightly below required so KeyboardKit's own layout can still
            // resolve without unsatisfiable-constraint noise if it also pins height.
            constraint.priority = UILayoutPriority(999)
            constraint.isActive = true
            hostHeightConstraint = constraint
        }

        view.invalidateIntrinsicContentSize()
    }

    /// Screen size used for system-keyboard height estimation.
    private func resolvedScreenSize(override: CGSize?) -> CGSize {
        if let override, override.width > 0, override.height > 0 {
            return override
        }
        if let screen = view.window?.windowScene?.screen.bounds.size,
           screen.width > 0, screen.height > 0 {
            return screen
        }
        let contextSize = state.keyboardContext.screenSize
        if contextSize.width > 0, contextSize.height > 0 {
            return contextSize
        }
        return CGSize(width: 393, height: 852)
    }

    /// Interface orientation used for system-keyboard height estimation.
    private func resolvedInterfaceOrientation(screenSize: CGSize) -> Keyboard.InterfaceOrientation {
        switch view.window?.windowScene?.interfaceOrientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        default:
            return state.keyboardContext.interfaceOrientation.isLandscape
                || screenSize.width > screenSize.height
                ? .landscape
                : .portrait
        }
    }

    /// Prefers any connected window's bottom safe area because an embedded
    /// keyboard `inputView` (and its keyboard window) often reports `0` even
    /// when the home indicator overlaps the host. Falls back to a floor on
    /// modern phone screen sizes so the bottom row still clears rounded corners.
    private func resolvedBottomSafeAreaInset() -> CGFloat {
        var inset = max(view.safeAreaInsets.bottom, view.window?.safeAreaInsets.bottom ?? 0)
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows {
                inset = max(inset, window.safeAreaInsets.bottom)
            }
        }
        if inset > 0 {
            return inset
        }
        let screenHeight = view.window?.windowScene?.screen.bounds.height
            ?? state.keyboardContext.screenSize.height
        // iPhone X and later (portrait) use a home indicator; without an
        // inset the bottom row sits in the rounded corner region.
        return screenHeight >= 812 ? 34 : 0
    }

    /// KeyboardKit normally synchronizes its layout context from an attached
    /// input view controller. AirTurn embeds this controller's view directly,
    /// so use the actual hosted SwiftUI width to avoid retaining a stale
    /// landscape width after the device rotates.
    internal func synchronizeKeyboardLayoutSize(_ size: CGSize) {
        guard size.width.isFinite, size.width > 0 else { return }

        // `maximumHeight` (the target `layout.preparedForHost` scales the
        // alphabetic/numeric layout to) is anchored from rotation /
        // `updateHostGeometryParameters()`, not from here: syncing it from
        // whatever SwiftUI reports it rendered would let this call's own
        // `preferredContentSize` growth, below, redefine the very cap
        // `preparedForHost` is meant to respect.
        //
        // The emoji keyboard's own grid isn't governed by `layout`/`fitted`
        // (see the "KNOWN LIMITATION" doc comment on
        // `AirTurnReplacementKeyboardView`) and can render taller than the
        // current host. Rather than clip it, ask UIKit for more room —
        // matching how the real system keyboard is itself taller in emoji
        // mode. `AirTurnKeyboardStateMonitor` already observes the resulting
        // host resize and repositions the surrounding AirTurn UI for it.
        // Only grow preferredContentSize for emoji. Alphabetic/numeric sizing
        // is restored to the system keyboard height in
        // `updateHostGeometryParameters()` when leaving emoji mode.
        if size.height.isFinite, size.height > 0, size.height > preferredContentSize.height {
            preferredContentSize = CGSize(width: size.width, height: size.height)
        }

        let context = state.keyboardContext
        let windowSize = view.window?.bounds.size
        var screenSize = windowSize ?? context.screenSize
        screenSize.width = size.width
        if screenSize.height <= 0 {
            screenSize.height = max(context.screenSize.width, context.screenSize.height)
        }

        let orientation: Keyboard.InterfaceOrientation
        switch view.window?.windowScene?.interfaceOrientation {
        case .portrait:
            orientation = .portrait
        case .portraitUpsideDown:
            orientation = .portraitUpsideDown
        case .landscapeLeft:
            orientation = .landscapeLeft
        case .landscapeRight:
            orientation = .landscapeRight
        default:
            orientation = screenSize.width > screenSize.height ? .landscape : .portrait
        }

        if context.screenSize != screenSize {
            context.screenSize = screenSize
        }
        if context.interfaceOrientation != orientation {
            context.interfaceOrientation = orientation
        }
    }

    /// Seed KeyboardKit with the host app's actual device geometry before it
    /// creates its first SwiftUI layout. Otherwise a wide phone can start with
    /// the preview row height and outgrow the input view after width syncing.
    private func synchronizeKeyboardContextWithActiveScene() {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
            return
        }

        let context = state.keyboardContext
        let size = scene.screen.bounds.size
        context.screenSize = size
        switch scene.interfaceOrientation {
        case .portrait:
            context.interfaceOrientation = .portrait
        case .portraitUpsideDown:
            context.interfaceOrientation = .portraitUpsideDown
        case .landscapeLeft:
            context.interfaceOrientation = .landscapeLeft
        case .landscapeRight:
            context.interfaceOrientation = .landscapeRight
        default:
            context.interfaceOrientation = size.width > size.height ? .landscape : .portrait
        }
    }

    private static var licenseKey: String? {
#if ATRK_PRO
        keyboardKitProLicenseKey
#else
        nil
#endif
    }

    static func defaultLocale(
        for locales: [Locale],
        preferredLocale: Locale,
        storedLocaleIdentifier: String?
    ) -> Locale {
        if locales.contains(preferredLocale) {
            return preferredLocale
        }

        if let storedLocaleIdentifier,
           let storedLocale = locales.first(where: { $0.identifier == storedLocaleIdentifier }) {
            return storedLocale
        }

        return locales[0]
    }

    private func applyConfiguration() {
        let locales = Self.configuredKeyboardKitLocales
        let selectedLocale = Self.defaultLocale(
            for: locales,
            preferredLocale: keyboardLocale,
            storedLocaleIdentifier: UserDefaults.standard.string(forKey: Self.currentLocaleKey)
        )

        state.keyboardContext.locales = locales
        state.keyboardContext.locale = selectedLocale
        keyboardLocale = selectedLocale
        applyAutocompleteConfiguration()

        currentLocaleCancellable = state.keyboardContext.$locale
            .removeDuplicates()
            .sink { locale in
                UserDefaults.standard.set(locale.identifier, forKey: Self.currentLocaleKey)
            }
    }

    private func refreshConfiguredKeyboardLocales() {
        let locales = Self.configuredKeyboardKitLocales
        let currentLocale = state.keyboardContext.locale
        state.keyboardContext.locales = locales

        if locales.contains(currentLocale) {
            return
        }

        state.keyboardContext.locale = Self.defaultLocale(
            for: locales,
            preferredLocale: keyboardLocale,
            storedLocaleIdentifier: UserDefaults.standard.string(forKey: Self.currentLocaleKey)
        )
        keyboardLocale = state.keyboardContext.locale
    }

    private func applyAutocompleteConfiguration() {
        viewParameters.enableAutoCorrect = enableAutoCorrect
        state.autocompleteSettings.isAutocompleteEnabled = enableAutoCorrect
        state.autocompleteSettings.isAutocorrectEnabled = enableAutoCorrect
    }
}
