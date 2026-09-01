import Combine
import KeyboardKit
import UIKit

/// Presents a system-style software keyboard inside an application when an
/// attached AirTurn pedal causes iOS to hide its own software keyboard.
@objc(AirTurnReplacementKeyboardViewController)
@MainActor
public final class AirTurnReplacementKeyboardViewController: KeyboardInputViewController {
    private static let currentLocaleKey = "com.airturn.AirTurnReplacementKeyboard.currentLocale"

    private let viewParameters = AirTurnReplacementKeyboardViewParameters()
    private var currentLocaleCancellable: AnyCancellable?

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
        var seen = Set<String>()
        let supported = allKeyboardKitLocales
        let locales = UITextInputMode.activeInputModes.compactMap { inputMode -> Locale? in
            guard let identifier = inputMode.primaryLanguage else { return nil }
            let normalized = identifier.replacingOccurrences(of: "-", with: "_")
            let language = normalized.split(separator: "_").first.map(String.init)
            guard let locale = supported.first(where: {
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

        setupKeyboardKit(for: app) { [weak self] _ in
            guard let self else { return }
            self.services.actionHandler = AirTurnKeyboardActionHandler(controller: self)
            self.applyConfiguration()
        }
    }

    public override func viewWillSetupKeyboardView() {
        let parameters = viewParameters
        parameters.maximumHeight = view.bounds.height
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

    /// KeyboardKit normally synchronizes its layout context from an attached
    /// input view controller. AirTurn embeds this controller's view directly,
    /// so use the actual hosted SwiftUI width to avoid retaining a stale
    /// landscape width after the device rotates.
    private func synchronizeKeyboardLayoutSize(_ size: CGSize) {
        guard size.width.isFinite, size.width > 0 else { return }

        if size.height.isFinite, size.height > 0, viewParameters.maximumHeight != size.height {
            viewParameters.maximumHeight = size.height
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

    private func applyConfiguration() {
        let locales = Self.configuredKeyboardKitLocales
        let storedIdentifier = UserDefaults.standard.string(forKey: Self.currentLocaleKey)
        let storedLocale = storedIdentifier.flatMap { identifier in
            locales.first { $0.identifier == identifier }
        }
        let selectedLocale = locales.contains(keyboardLocale)
            ? keyboardLocale
            : (storedLocale ?? locales[0])

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

    private func applyAutocompleteConfiguration() {
        viewParameters.enableAutoCorrect = enableAutoCorrect
        state.autocompleteSettings.isAutocompleteEnabled = enableAutoCorrect
        state.autocompleteSettings.isAutocorrectEnabled = enableAutoCorrect
    }
}
