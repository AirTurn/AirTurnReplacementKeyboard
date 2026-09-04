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
/// KNOWN LIMITATION: `layout.fitted(toHostHeight:bottomInset:)` scales the
/// alphabetic/numeric key layout to fit `parameters.maximumHeight`, but the
/// emoji keyboard's own grid does not follow suit. KeyboardKit 10.9.1 renders
/// that grid through a UIKit-bridged component
/// (`UIKitPlatformViewHost<PlatformViewRepresentableAdaptor<...>>`, confirmed
/// via view-hierarchy inspection) with `clipsToBounds == false` that reports
/// and keeps its own intrinsic height regardless of any SwiftUI-level
/// constraint applied here — `.frame(height:)`, `.clipped()`, and KeyboardKit's
/// own `.emojiKeyboardSizes(...)` sizing API were all tried and none of them
/// changed its measured rendered size. When the emoji grid's natural height
/// exceeds the host's fixed frame, it can render past the host's bounds. See
/// `AirTurnReplacementKeyboardRenderingTests` for a reproduction.
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
        let baseLayout = KeyboardLayout.standard(for: keyboardContext)
        let bottomInset = max(0, parameters.bottomSafeAreaInset)
        return Self.layoutApplyingBottomRowFixesIfNeeded(
            baseLayout,
            locales: keyboardContext.locales
        )
        .preparedForHost(
            // SwiftUI `.padding(.bottom)` owns the home-indicator gap; scale
            // key rows to the remaining height so they fill flush to that pad.
            hostHeight: max(0, parameters.maximumHeight - bottomInset),
            bottomSafeAreaInset: 0,
            includeAutocompleteToolbar: parameters.enableAutoCorrect
        )
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
        .padding(.bottom, max(0, parameters.bottomSafeAreaInset))
        // Ignore the container safe area so the explicit bottom padding is the
        // sole home-indicator clearance; otherwise SwiftUI also insets and the
        // key layout is vertically centered in the leftover space.
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

extension AirTurnReplacementKeyboardView {
    /// Adjusts the bottom row for in-app embedding: swap the system keyboard
    /// switcher for locale switching when multiple locales are configured, and
    /// keep an emoji switcher so the row matches a standard iPhone keyboard.
    internal static func layoutApplyingBottomRowFixesIfNeeded(
        _ layout: KeyboardLayout,
        locales: [Locale]
    ) -> KeyboardLayout {
        var result = layout
        if locales.count > 1 {
            result.replace(.nextKeyboard, withAction: .nextLocale)

            if !result.hasKey(for: .nextLocale) {
                result.tryInsertBottomRowAction(.nextLocale, before: .space)
            }
        } else {
            result.remove(.nextKeyboard)
        }

        // KeyboardKit may omit the emoji switcher when Pro emoji features are
        // unavailable; still request the key so a licensed emoji keyboard can
        // surface it, matching the system keyboard's bottom row.
        if !result.hasKeyboardSwitcher(.emojis), !result.hasKey(for: .keyboardType(.emojis)) {
            result.tryInsertBottomRowAction(.keyboardType(.emojis), before: .space)
        }

        return result
    }

    /// Backward-compatible name used by existing unit tests.
    internal static func layoutApplyingLocaleKeyFixIfNeeded(
        _ layout: KeyboardLayout,
        locales: [Locale]
    ) -> KeyboardLayout {
        layoutApplyingBottomRowFixesIfNeeded(layout, locales: locales)
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
