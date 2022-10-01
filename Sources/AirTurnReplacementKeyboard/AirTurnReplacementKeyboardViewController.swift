//
//  KeyboardViewController.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2021-02-11.
//  Copyright © 2021 Daniel Saidi. All rights reserved.
//

import KeyboardKit
import SwiftUI

/**
 This keyboard demonstrates how to create a keyboard that is
 using `SystemKeyboard` to mimic a native English keyboard.
 
 The keyboard makes demo-specific configurations and sets up
 the keyboard with a ``KeyboardView``. You can change all of
 these configurations to see how the keyboard changes.
 
 To use this keyboard, you must enable it in system settings
 ("Settings/General/Keyboards"). It needs full access to get
 access to features like haptic and audio feedback.
 
 Note that this demo adds KeyboardKit as a local package and
 not as a remote package, as you would normally add it. This
 is done to make it possible to change the package from this
 project and make it easier to quickly try out new things.
 */
@objc(AirTurnReplacementKeyboardViewController) public class AirTurnReplacementKeyboardViewController: KeyboardInputViewController {
    
    /**
     Here, we register demo-specific services which are then
     used by the keyboard.
     */
    public override func viewDidLoad() {
        
        view.translatesAutoresizingMaskIntoConstraints = false

        // Setup an custom input set provider.
        // 💡 Have a look at the other demo projects, where this is done.
        // inputSetProvider = ...
        
        // Setup a demo-specific keyboard appearance.
        // 💡 You can change this appearance to see how the keyboard style changes.
        keyboardAppearance = KeyboardAppearance(context: keyboardContext)
        
        // Setup a demo-specific keyboard action handler.
        // 💡 You can change this handler to see how the keyboard behavior changes.
        keyboardActionHandler = KeyboardActionHandler(
            inputViewController: self)
        
        // Setup a demo-specific keyboard layout provider.
        // 💡 You can change this provider to see how the keyboard layout changes.
        keyboardLayoutProvider = KeyboardLayoutProvider(
            inputSetProvider: inputSetProvider,
            dictationReplacement: nil)
        
        // Call super to perform the base initialization
        super.viewDidLoad()
    }
    
    /**
     This function is called whenever the keyboard should be
     created or updated.
     
     Here, we use the ``KeyboardView`` to setup the keyboard.
     This will create a `SystemKeyboard`-based keyboard that
     looks like a native keyboard.
     */
    public override func viewWillSetupKeyboard() {
        super.viewWillSetupKeyboard()
        
        // Setup the demo with demo-specific keyboard view.
        setup(with: AirTurnReplacementKeyboardView())
    }
}