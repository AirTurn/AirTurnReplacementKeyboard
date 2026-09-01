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
