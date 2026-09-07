import KeyboardKit
import SwiftUI

@MainActor
final class AirTurnReplacementKeyboardViewParameters: ObservableObject {
    @Published var enableAutoCorrect = false
    @Published var maximumHeight: CGFloat = 0
    /// Home-indicator (or other) inset that must stay clear of the bottom key row
    /// when this keyboard is embedded as an in-app `inputView`.
    @Published var bottomSafeAreaInset: CGFloat = 0
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
///
/// The emoji grid has its own sizing, independent of `KeyboardLayout`. Use
/// KeyboardKit's small emoji metrics to leave room for the lower controls.
/// App-hosted UI tests verify emoji insertion and the return to letters.
///
/// KeyboardKit's built-in background tracks the layout's natural height, so
/// when rows are scaled up this view also draws an explicit full-bleed
/// `Color.keyboardBackground` behind the host.
struct AirTurnReplacementKeyboardView: View {
    let services: KeyboardServices
    let state: KeyboardState
    let onSizeChange: (CGSize) -> Void

    @ObservedObject var parameters: AirTurnReplacementKeyboardViewParameters
    @ObservedObject private var keyboardContext: KeyboardContext
    @Environment(\.colorScheme) private var colorScheme

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

    private var controlsHeight: CGFloat {
#if ATRK_PRO
        44
#else
        0
#endif
    }

    private var footerInset: CGFloat {
        let inset = max(0, parameters.bottomSafeAreaInset)
        // The native portrait footer has ~39pt from the last key to the icon
        // centre, rather than a full extra 34pt safe-area gap above the control.
        return keyboardContext.deviceTypeForKeyboard == .phone
            && !keyboardContext.interfaceOrientation.isLandscape ? inset / 2 : inset
    }

    private var keyboardHeight: CGFloat {
        max(0, parameters.maximumHeight - controlsHeight - footerInset)
    }

    private var layout: KeyboardLayout {
        let baseLayout = KeyboardLayout.standard(for: keyboardContext)
        // Reserve the footer and home-indicator clearance before fitting keys
        // to UIKit's fixed-height in-app keyboard host.
        return Self.layoutForSeparateControls(baseLayout)
        .preparedForHost(
            // KeyboardView adds the autocomplete toolbar outside KeyboardLayout.
            // Reserve it separately so it cannot extend under the dismiss bar.
            hostHeight: max(0, keyboardHeight - (parameters.enableAutoCorrect
                ? SystemKeyboardGeometry.autocompleteToolbarHeight : 0)),
            bottomSafeAreaInset: 0,
            includeAutocompleteToolbar: parameters.enableAutoCorrect
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            KeyboardView(
                layout: layout,
                services: services,
                buttonContent: { $0.view },
                buttonView: { $0.view },
                collapsedView: { $0.view },
                emojiKeyboard: { $0.view.emojiKeyboardSizes(.small) },
                toolbar: { parameters in
                    if self.parameters.enableAutoCorrect {
                        parameters.view
                            .accessibilityIdentifier("AirTurnSuggestions")
                    }
                }
            )
            .frame(height: keyboardHeight > 0 ? keyboardHeight : nil)
            controls
                .frame(
                    height: controlsHeight + footerInset,
                    alignment: .bottom
                )
        }
        // Fill the UIKit host so scaled key rows aren't taller than KK's
        // intrinsic background (which stays at the natural ~216pt size).
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background {
            Color.keyboardBackground(for: colorScheme)
                .ignoresSafeArea()
        }
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

    private var controls: some View {
        HStack(spacing: 8) {
            if keyboardContext.locales.count > 1 {
                Image(systemName: "globe")
                    .frame(width: 44, height: 44)
                    .keyboardLocaleContextMenu {
                        services.actionHandler.handle(.nextLocale)
                    }
                    .accessibilityLabel("Next Locale")
                    .accessibilityValue(keyboardContext.locale.identifier)
                    .accessibilityIdentifier("AirTurnNextLocale")
            }
#if ATRK_PRO
            Button {
                let type: Keyboard.KeyboardType = keyboardContext.keyboardType == .emojis
                    ? .alphabetic : .emojis
                services.actionHandler.handle(.keyboardType(type))
            } label: {
                Group {
                    if keyboardContext.keyboardType == .emojis {
                        Text("ABC").font(.system(size: 17))
                    } else {
                        Image.keyboardEmoji
                            .resizable()
                            .scaledToFit()
                            .frame(width: 27, height: 27)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel(keyboardContext.keyboardType == .emojis ? "Alphabetic Keyboard" : "Emoji Keyboard")
            .accessibilityIdentifier("AirTurnEmojiKeyboard")
#endif
            Spacer(minLength: 0)
        }
        .font(.system(size: 25))
        .foregroundStyle(.primary)
        .buttonStyle(.plain)
        .padding(.horizontal, 21)
    }
}

extension AirTurnReplacementKeyboardView {
    /// Keeps language and emoji controls in the footer below the key rows.
    internal static func layoutForSeparateControls(
        _ layout: KeyboardLayout
    ) -> KeyboardLayout {
        var result = layout
        // UIKit supplies these controls outside a keyboard extension. AirTurn
        // embeds an input view in an app, so render them in our own footer.
        result.remove(.nextKeyboard)
        result.remove(.nextLocale)
        result.remove(.keyboardType(.emojis))

        return result
    }


}

extension KeyboardLayout {
    /// Prepares a standard KeyboardKit layout for AirTurn's fixed-height
    /// in-app keyboard host.
    ///
    /// - Parameters:
    ///   - hostHeight: The UIKit host height the keys must fill.
    ///   - bottomSafeAreaInset: Space to keep clear above the home indicator.
    ///   - includeAutocompleteToolbar: When false, clears the unused toolbar
    ///     height so KeyboardKit does not reserve an empty band above the keys.
    /// - Returns: A layout whose vertical metrics fill `hostHeight` while
    ///   keeping the bottom row above `bottomSafeAreaInset`.
    func preparedForHost(
        hostHeight: CGFloat,
        bottomSafeAreaInset: CGFloat,
        includeAutocompleteToolbar: Bool
    ) -> KeyboardLayout {
        var result = self

        if !includeAutocompleteToolbar {
            result.configuration.inputToolbarHeight = 0
        }

        let bottomInset = max(0, bottomSafeAreaInset)
        if bottomInset > result.configuration.edgeInsets.bottom {
            result.configuration.edgeInsets.bottom = bottomInset
        }

        return result.fitted(toHostHeight: hostHeight)
    }

    /// Scales vertical row metrics so the layout's `totalHeight` matches the
    /// host. Scales both up and down: a short natural layout in a taller UIKit
    /// keyboard host otherwise leaves empty space above the keys and parks the
    /// bottom row in the home-indicator / rounded-corner region.
    func fitted(toHostHeight hostHeight: CGFloat) -> KeyboardLayout {
        guard hostHeight.isFinite, hostHeight > 0, totalHeight > 0 else {
            return self
        }

        let insetChrome = configuration.edgeInsets.top + configuration.edgeInsets.bottom
        let targetRowHeight = hostHeight - insetChrome
        guard targetRowHeight > 0 else {
            return self
        }

        let scale = targetRowHeight / totalHeight
        guard abs(scale - 1) > 0.001 else {
            return self
        }

        var result = self
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

    /// Scales vertical metrics down when the layout is taller than the host.
    /// Kept for call sites and tests that only need the shrinking behavior.
    func fitted(toMaximumHeight maximumHeight: CGFloat) -> KeyboardLayout {
        guard maximumHeight.isFinite, maximumHeight > 0, totalHeight > maximumHeight else {
            return self
        }
        return fitted(toHostHeight: maximumHeight)
    }
}
