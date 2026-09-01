import KeyboardKit
import SwiftUI

@MainActor
final class AirTurnReplacementKeyboardViewParameters: ObservableObject {
    @Published var enableAutoCorrect = false
}

/// A thin wrapper around KeyboardKit's standard keyboard.
///
/// AirTurn displays this view inside the host application when iOS suppresses
/// its software keyboard because an AirTurn pedal is connected as an external
/// keyboard. Keeping the standard `KeyboardView` intact makes the replacement
/// follow the current iOS keyboard layout and appearance as closely as
/// KeyboardKit supports.
struct AirTurnReplacementKeyboardView: View {
    let services: KeyboardServices
    let state: KeyboardState

    @ObservedObject var parameters: AirTurnReplacementKeyboardViewParameters

    private var layout: KeyboardLayout {
        var layout = KeyboardLayout.standard(for: state.keyboardContext)

        // This keyboard is embedded in the host app, so the system keyboard
        // switcher is not useful. Reuse its position for locale switching when
        // more than one configured locale is available.
        if state.keyboardContext.locales.count > 1 {
            layout.replace(.nextKeyboard, withAction: .nextLocale)
        } else {
            layout.remove(.nextKeyboard)
        }

        return layout
    }

    var body: some View {
        KeyboardView(
            layout: layout,
            services: services,
            buttonContent: { $0.view },
            buttonView: { $0.view },
            collapsedView: { $0.view },
            emojiKeyboard: { $0.view },
            toolbar: { parameters in
                if self.parameters.enableAutoCorrect {
                    parameters.view
                }
            }
        )
    }
}
