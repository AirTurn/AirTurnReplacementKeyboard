# AirTurnReplacementKeyboard

A replacement keyboard for apps that must keep an on-screen keyboard available while
an AirTurn or another external keyboard is connected. The keyboard uses KeyboardKit's
standard system-like layout and behavior.

## KeyboardKit 11 developer preview

This branch evaluates `11.0.0-dp.1` (upstream revision
`9b60f93ef23006fb9e0b1741582ace3f97cff7ee`) without changing the v10 main branch.
The dependency requires Swift 6.2 / Xcode 26 or later. iOS 16 remains the minimum.

The preview removes `setupKeyboardView` from its public interface. The wrapper
therefore embeds a `UIHostingController`, injects `.keyboardState(state)`, and
replaces the existing host on redraw. It also handles the now-optional
`KeyboardContext.screenSize`. Test contexts pass `KeyboardSettings` explicitly.

All 13 package tests pass, including rendering and repeated hosting setup.
With the replacement Silver license, all four SDK example UI tests pass on
iOS 26.5 and iOS 27, including international and emoji input.

[Official preview announcement](https://keyboardkit.com/blog/2026/08/28/keyboardkit-11-developer-preview)

## Requirements

- iOS 16 or later
- Xcode 26 or later (Swift 6.2)
- KeyboardKit 11.0.0-dp.1

## Products

- `AirTurnReplacementKeyboard` supports every locale provided by KeyboardKit and
  requires a current KeyboardKit 10 license.
- `AirTurnReplacementKeyboardStandard` provides an English keyboard without
  KeyboardKit Pro features or a license.

Bundle your vendor-supplied `KeyboardKit.license` in the main app, or set
`AirTurnReplacementKeyboardViewController.keyboardKitProLicenseKey` before
presenting the Pro keyboard. KeyboardKit 6 license keys are not compatible with
KeyboardKit 10.

Create and present `AirTurnReplacementKeyboardViewController` as an input view
controller. Set `enableAutoCorrect` to show or hide the autocomplete toolbar, and
set `keyboardLocale` to choose the initial locale.

When AirTurn embeds the controller's view directly, the keyboard observes its
actual hosted size and keeps KeyboardKit's screen-size and orientation context in
sync. It sizes its `preferredContentSize` to an estimated system software-keyboard
height (so the in-app host matches Apple's keyboard size class rather than
KeyboardKit's shorter natural ~216pt layout), then scales standard key-row
metrics to fill that host while keeping the bottom row clear of the home
indicator. No application-facing API changed for this behavior.

The Pro keyboard places globe and emoji controls below the key rows, above the
home indicator. Tap the globe to cycle enabled languages; hold it to open
KeyboardKit's language menu. The emoji control opens KeyboardKit's emoji grid
and changes to ABC to return to letters. KeyboardKit's small emoji metrics leave
room for this footer. The Standard product remains an English keyboard.

The upstream demo is a keyboard extension; UIKit supplies its system globe and
dictation strip. An in-app input view does not receive that strip, so this wrapper
provides the lower language and emoji controls using KeyboardKit's public locale
menu and action handler. It does not switch to a system keyboard extension.

The AirTurn SDK examples include a bundle-ID-bound Silver license. App-hosted
UI tests verify French AZERTY, German ü, Spanish ñ, language-menu selection,
emoji insertion, and returning to letters. Integrators with another bundle ID
need their own license.

## Running tests

The package's unit tests cover locale resolution (`configuredKeyboardKitLocales`,
`defaultLocale`), removal of duplicate language/emoji controls from the key rows
(`AirTurnReplacementKeyboardView.layoutForSeparateControls`), that the
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
