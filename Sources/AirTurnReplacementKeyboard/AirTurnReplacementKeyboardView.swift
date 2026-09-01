import KeyboardKit
import SwiftUI

@MainActor
final class AirTurnReplacementKeyboardViewParameters: ObservableObject {
    @Published var enableAutoCorrect = false
    @Published var maximumHeight: CGFloat = 0
}

private struct AirTurnReplacementKeyboardSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
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
    let onSizeChange: (CGSize) -> Void

    @ObservedObject var parameters: AirTurnReplacementKeyboardViewParameters
    @ObservedObject private var keyboardContext: KeyboardContext

    init(
        services: KeyboardServices,
        state: KeyboardState,
        parameters: AirTurnReplacementKeyboardViewParameters,
        onSizeChange: @escaping (CGSize) -> Void
    ) {
        self.services = services
        self.state = state
        self.parameters = parameters
        self.onSizeChange = onSizeChange
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

        return layout.fitted(toMaximumHeight: parameters.maximumHeight)
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
        // This view is embedded directly in UIKit's keyboard host. Respecting
        // the host window's bottom safe area would vertically center the
        // fixed-height rows in a shorter region and move the top row outside
        // the input view by half the home-indicator inset.
        .ignoresSafeArea(.container, edges: .bottom)
        .background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: AirTurnReplacementKeyboardSizePreferenceKey.self,
                    value: geometry.size
                )
            }
        }
        .onPreferenceChange(AirTurnReplacementKeyboardSizePreferenceKey.self) {
            onSizeChange($0)
        }
    }
}

private extension KeyboardLayout {
    /// KeyboardKit uses taller rows on wide phones, while UIKit gives an
    /// in-app `inputView` the standard keyboard host height. Scale just the
    /// vertical metrics when necessary so keys never escape that host.
    func fitted(toMaximumHeight maximumHeight: CGFloat) -> KeyboardLayout {
        guard maximumHeight.isFinite, maximumHeight > 0, totalHeight > maximumHeight else {
            return self
        }

        var result = self
        let scale = maximumHeight / totalHeight
        result.configuration.rowHeight *= scale
        result.configuration.inputToolbarHeight *= scale
        result.idealItemHeight *= scale

        for rowIndex in result.itemRows.indices {
            for itemIndex in result.itemRows[rowIndex].indices {
                var item = result.itemRows[rowIndex][itemIndex]
                var size = item.size
                size.height *= scale
                item.size = size
                result.itemRows[rowIndex][itemIndex] = item
            }
        }
        return result
    }
}
