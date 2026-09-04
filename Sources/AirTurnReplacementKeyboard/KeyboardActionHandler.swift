import Foundation
import KeyboardKit

/// Keeps KeyboardKit's standard behavior and additionally tells AirTurn's
/// keyboard manager when the embedded keyboard's dismiss key is released.
final class AirTurnKeyboardActionHandler: StandardKeyboardActionHandler {
    var onNextLocale: (() -> Void)?

    private static let dismissNotification = Notification.Name(
        "AirTurnReplacementKeyboardDismissNotification"
    )

    override func handle(_ gesture: Keyboard.Gesture, on action: KeyboardAction) {
        if gesture == .release, action == .nextLocale {
            onNextLocale?()
        }

        if gesture == .release, action == .dismissKeyboard {
            NotificationCenter.default.post(name: Self.dismissNotification, object: nil)
        }
        super.handle(gesture, on: action)
    }
}
