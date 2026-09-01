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
        setupKeyboardView { controller in
            AirTurnReplacementKeyboardView(
                services: controller.services,
                state: controller.state,
                parameters: parameters
            )
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
