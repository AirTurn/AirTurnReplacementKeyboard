# AirTurnReplacementKeyboard

A replacement keyboard for apps that must keep an on-screen keyboard available while
an AirTurn or another external keyboard is connected. The keyboard uses KeyboardKit's
standard system-like layout and behavior.

## Requirements

- iOS 16 or later
- Xcode 16 or later
- KeyboardKit 10.9.1

## Products

- `AirTurnReplacementKeyboard` supports every locale provided by KeyboardKit and
  requires a current KeyboardKit 10 license.
- `AirTurnReplacementKeyboardStandard` provides an English keyboard without
  KeyboardKit Pro features or a license.

Set `AirTurnReplacementKeyboardViewController.keyboardKitProLicenseKey` before
presenting the Pro keyboard. KeyboardKit 6 license keys are not compatible with
KeyboardKit 10.

Create and present `AirTurnReplacementKeyboardViewController` as an input view
controller. Set `enableAutoCorrect` to show or hide the autocomplete toolbar, and
set `keyboardLocale` to choose the initial locale.

When AirTurn embeds the controller's view directly, the keyboard observes its
actual hosted size and keeps KeyboardKit's screen-size and orientation context in
sync. It also fits KeyboardKit's wide-phone vertical metrics to UIKit's in-app
keyboard host, preventing a landscape-width layout from being clipped after the
host app returns to portrait and keeping the first row below the dismiss bar. No
application-facing API changed for this behavior.

## Upgrading from KeyboardKit 6

KeyboardKit 10 combines the former KeyboardKit and KeyboardKitPro packages. Remove
any direct KeyboardKitPro dependency and update to the single KeyboardKit 10.9.1
package dependency. The wrapper keeps its existing public controller and property
names, including `keyboardKitProLicenseKey`, for source and Objective-C
compatibility. That property now requires a current KeyboardKit 10 subscription
key or v10 licence; a KeyboardKit 6 key will not activate licensed locales.

The package's minimum deployment target has changed from iOS 13 to iOS 16. The
current implementation uses KeyboardKit's standard keyboard directly instead of
the old demo-derived appearance, autocomplete, layout-provider, and action-handler
implementations.
