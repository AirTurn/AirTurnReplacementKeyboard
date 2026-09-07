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

Bundle your vendor-supplied `KeyboardKit.license` in the main app, or set
`AirTurnReplacementKeyboardViewController.keyboardKitProLicenseKey` before
presenting the Pro keyboard. KeyboardKit 6 license keys are not compatible with
KeyboardKit 10.

Create and present `AirTurnReplacementKeyboardViewController` as an input view
controller. Set `enableAutoCorrect` to show or hide the autocomplete toolbar, and
set `keyboardLocale` to choose the initial locale. The distributed Swift and
Objective-C examples enable autocomplete and its suggestion bar. Integrators
can opt in with `enableAutoCorrect = true`; the wrapper's default remains false.
Changing that option after presentation updates the host height as well.

When AirTurn embeds the controller's view directly, the keyboard observes its
actual hosted size and keeps KeyboardKit's screen-size and orientation context in
sync. It sizes its `preferredContentSize` to an estimated system software-keyboard
height (so the in-app host matches Apple's keyboard size class rather than
KeyboardKit's shorter natural ~216pt layout), then scales standard key-row
metrics to fill that host while keeping the bottom row clear of the home
indicator. No application-facing API changed for this behavior.

The Pro keyboard places globe and emoji controls below the key rows, above the
home indicator. The footer uses KeyboardKit's native-style emoji image and is
calibrated to the iPhone 17 Pro portrait reference, including its spacing from
the last key row. Tap the globe to cycle enabled languages; hold it to open
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

## Continuous integration

`.github/workflows/ios-tests.yml` runs on pushes, pull requests, and manual
dispatches in the **AirTurnReplacementKeyboard repository**. This directory is a
submodule of SDK-iOS; the workflow must be pushed to the package repository to
run. Enable GitHub Actions there if it is disabled.

The job uses a GitHub-hosted macOS 15 runner and its latest installed released
Xcode 26, selecting an
available iPhone simulator through `scripts/test.sh`. It runs the package's unit
and rendering tests with `xcodebuild`, since `swift test` targets macOS and cannot
load the iOS KeyboardKit binary. Tests run serially, with execution timeouts to
bound controller setup hangs. No signing credentials or Pro license secrets are
configured.

Each run uploads `keyboard-test-results`, containing the Xcode version, simulator
inventory, build log, and `.xcresult` bundle when produced, including on failure.
Artifacts are retained for 14 days. Download the bundle and open it in Xcode to
inspect failures. The job has a 30-minute timeout.

To reproduce the result-bundle invocation locally, use a fresh output path:

```sh
sh scripts/test.sh "" -parallel-testing-enabled NO \
  -resultBundlePath /tmp/KeyboardTests.xcresult
```

These are package tests, including a hosted-controller rendering test. They do
not verify the example app's full input-view installation or that its host
honors emoji resize requests. Those still require app-hosted UI tests or manual
device verification.

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
