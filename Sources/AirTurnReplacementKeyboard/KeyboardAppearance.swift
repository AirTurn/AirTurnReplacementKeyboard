//
//  DemoKeyboardAppearance.swift
//  Keyboard
//
//  Created by Daniel Saidi on 2021-10-06.
//  Copyright © 2021 Daniel Saidi. All rights reserved.
//

import KeyboardKitPro
import SwiftUI

/**
 This demo-specific appearance inherits the standard one and
 can be used to easily customize the demo keyboard.
 */
class KeyboardAppearance: StandardKeyboardAppearance {
    override func buttonImage(for action: KeyboardAction) -> Image? {
        if action == .custom(named: "dismiss") {
            return super.buttonImage(for: .dismissKeyboard)
        }
        return super.buttonImage(for: action)
    }
    
    override func buttonStyle(
        for action: KeyboardAction,
        isPressed: Bool) -> KeyboardButtonStyle {
        if action == .custom(named: "dismiss") {
            return super.buttonStyle(for: .dismissKeyboard, isPressed: false)
        }
        return super.buttonStyle(for: action, isPressed: isPressed)
    }
    
    override func buttonText(for action: KeyboardAction) -> String? {
        if action == .custom(named: "dismiss") {
            return super.buttonText(for: .dismissKeyboard)
        }
        return super.buttonText(for: action)
    }
}
