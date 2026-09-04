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

The emoji keyboard is sized differently: KeyboardKit's emoji grid isn't governed
by the same layout fitting and can be taller than the alphabetic keyboard, as it
is on the real system keyboard. Rather than clip it, the controller grows its
`preferredContentSize` to request more room from UIKit when the emoji keyboard
needs it, and returns to the alphabetic keyboard's height when switching back.
Whether the host visibly resizes end-to-end depends on the surrounding app's
input view installation reacting to that request.

## Running tests

The package's unit tests cover locale resolution (`configuredKeyboardKitLocales`,
`defaultLocale`), the locale-switch key layout fix
(`AirTurnReplacementKeyboardView.layoutApplyingLocaleKeyFixIfNeeded`), that the
alphabetic keyboard fits its host, and the emoji keyboard's resize-request
behavior (`synchronizeKeyboardLayoutSize`). Run them with the bundled script,
which picks a booted or available iPhone simulator automatically:

```sh
scripts/test.sh
```

Pass a specific simulator UDID or destination string to target one explicitly:

```sh
scripts/test.sh 29C7CD0A-5FE3-4A61-B2E6-3E397575098F
scripts/test.sh "platform=iOS Simulator,name=iPhone 16 Pro"
```

Equivalently, run `xcodebuild test -scheme AirTurnReplacementKeyboard-Package
-destination "platform=iOS Simulator,name=<simulator name>"` directly, or open
the package in Xcode and run the `AirTurnReplacementKeyboardTests` target
(⌘U) with the `AirTurnReplacementKeyboard-Package` scheme selected.

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
