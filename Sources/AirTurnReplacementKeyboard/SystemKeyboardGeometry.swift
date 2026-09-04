import CoreGraphics
import KeyboardKit

/// Estimates the system software-keyboard height when it cannot be measured
/// live (AirTurn keeps a hardware keyboard attached, which suppresses iOS's
/// own keyboard and its frame notifications).
enum SystemKeyboardGeometry {
    /// Approximate QuickType / autocomplete bar height included in system
    /// keyboard frames when predictive text is visible.
    static let autocompleteToolbarHeight: CGFloat = 45

    /// Extra vertical chrome modern Face ID phones add above the classic
    /// 216pt / 226pt key-row heights when reporting
    /// `UIKeyboardFrameEndUserInfoKey` (portrait).
    private static let modernPortraitChrome: CGFloat = 41

    /// Extra vertical chrome Face ID phones add in landscape beyond classic
    /// 162pt / 171pt key-row heights.
    private static let modernLandscapeChrome: CGFloat = 15

    /// Estimates the undocked system software-keyboard height for the given
    /// device geometry.
    ///
    /// Values track commonly observed `UIKeyboardFrameEndUserInfoKey` heights
    /// when the predictive bar is hidden (or included when
    /// `includeAutocompleteToolbar` is true). They are not pixel-perfect
    /// Apple metrics — Apple does not publish those — but they put an
    /// in-app replacement keyboard in the same size class as the system one.
    ///
    /// - Parameters:
    ///   - screenSize: The device screen size in points.
    ///   - orientation: Interface orientation used for the keyboard.
    ///   - deviceType: Phone vs pad sizing branch.
    ///   - bottomSafeAreaInset: Home-indicator (or similar) inset included in
    ///     the system keyboard frame on Face ID devices.
    ///   - includeAutocompleteToolbar: When true, includes the predictive /
    ///     autocomplete bar height.
    /// - Returns: Estimated keyboard height in points, including the bottom
    ///   safe-area region when present.
    static func estimatedHeight(
        screenSize: CGSize,
        orientation: Keyboard.InterfaceOrientation,
        deviceType: Keyboard.DeviceType,
        bottomSafeAreaInset: CGFloat,
        includeAutocompleteToolbar: Bool
    ) -> CGFloat {
        let bottom = max(0, bottomSafeAreaInset)
        let autocomplete = includeAutocompleteToolbar ? autocompleteToolbarHeight : 0
        let isLandscape = orientation.isLandscape
        let shortSide = min(screenSize.width, screenSize.height)
        let longSide = max(screenSize.width, screenSize.height)

        if deviceType == .pad {
            return estimatedPadHeight(
                longSide: longSide,
                isLandscape: isLandscape,
                autocomplete: autocomplete
            )
        }

        // Plus / Max class phones use slightly taller classic key rows.
        let isLargePhone = shortSide >= 414 || longSide >= 896

        if isLandscape {
            let keyRows: CGFloat = isLargePhone ? 171 : 162
            let chrome: CGFloat = bottom > 0 ? modernLandscapeChrome : 0
            return keyRows + bottom + chrome + autocomplete
        }

        let keyRows: CGFloat = isLargePhone ? 226 : 216
        let chrome: CGFloat = bottom > 0 ? modernPortraitChrome : 0
        return keyRows + bottom + chrome + autocomplete
    }
}

private extension SystemKeyboardGeometry {
    /// Docked iPad keyboard height estimates by long-side class.
    static func estimatedPadHeight(
        longSide: CGFloat,
        isLandscape: Bool,
        autocomplete: CGFloat
    ) -> CGFloat {
        let portraitBase: CGFloat
        if longSide >= 1366 {
            portraitBase = 398
        } else if longSide >= 1024 {
            portraitBase = 313
        } else {
            portraitBase = 265
        }
        // Docked landscape iPad keyboards are typically similar in height to
        // the large portrait class for the same device family.
        let landscapeBase: CGFloat = longSide >= 1366 ? 398 : 313
        return (isLandscape ? landscapeBase : portraitBase) + autocomplete
    }
}

extension Keyboard.InterfaceOrientation {
    /// Whether this orientation lays the keyboard out horizontally.
    var isLandscape: Bool {
        self == .landscape || self == .landscapeLeft || self == .landscapeRight
    }
}
