import KeyboardKit
import SwiftUI

@MainActor
final class AirTurnReplacementKeyboardViewParameters: ObservableObject {
    @Published var enableAutoCorrect = false
}

private struct AirTurnReplacementKeyboardWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
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
    let onWidthChange: (CGFloat) -> Void

    @ObservedObject var parameters: AirTurnReplacementKeyboardViewParameters
    @ObservedObject private var keyboardContext: KeyboardContext

    init(
        services: KeyboardServices,
        state: KeyboardState,
        parameters: AirTurnReplacementKeyboardViewParameters,
        onWidthChange: @escaping (CGFloat) -> Void
    ) {
        self.services = services
        self.state = state
        self.parameters = parameters
        self.onWidthChange = onWidthChange
        _keyboardContext = ObservedObject(wrappedValue: state.keyboardContext)
    }

    private var layout: KeyboardLayout {
        var layout = KeyboardLayout.standard(for: keyboardContext)

        // This keyboard is embedded in the host app, so the system keyboard
        // switcher is not useful. Reuse its position for locale switching when
        // more than one configured locale is available.
        if keyboardContext.locales.count > 1 {
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
        .background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: AirTurnReplacementKeyboardWidthPreferenceKey.self,
                    value: geometry.size.width
                )
            }
        }
        .onPreferenceChange(AirTurnReplacementKeyboardWidthPreferenceKey.self) {
            onWidthChange($0)
        }
    }
}
