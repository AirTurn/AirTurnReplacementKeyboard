//
//  KeyboardViewController.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2021-02-11.
//  Copyright © 2021 Daniel Saidi. All rights reserved.
//

#if ATRK_STANDARD
import KeyboardKit
#else
import KeyboardKitPro
#endif
import SwiftUI
import Combine

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
    
    private let userDefaultsCurrentLocaleKey = "com.airturn.AirTurnReplacementKeyboard.currentLocale"
    
    private let kbView = AirTurnReplacementKeyboardView()
    
    @objc(enableAutoCorrect) public var enableAutoCorrect: Bool {
        set {
            kbView.enableAutoCorrect = newValue
        }
        get {
            kbView.enableAutoCorrect
        }
    }
    
#if ATRK_PRO
    /// Set your KeyboardKitPro license key to this property to enable KeyboardKitPro functionality. Leave nil for KeyboardKit standard.
    @objc(keyboardKitProLicenseKey) public static var keyboardKitProLicenseKey: String?
#endif
    
    /**
     Here, we register demo-specific services which are then
     used by the keyboard.
     */
    private var currentLocaleCancellable: AnyCancellable?
    public override func viewDidLoad() {
        
        view.translatesAutoresizingMaskIntoConstraints = false

        keyboardAppearance = KeyboardAppearance(context: keyboardContext)
        
        keyboardActionHandler = KeyboardActionHandler(
            inputViewController: self)
        
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
        
        let view = AirTurnReplacementKeyboardView()
        
#if ATRK_STANDARD
        setup(with: view)
#else
        if let key = Self.keyboardKitProLicenseKey {
            try? setupPro(withLicenseKey: key, view: view)
        } else {
            setup(with: view)
        }
#endif
        
        
        currentLocaleCancellable?.cancel()
        if let currentLocale = UserDefaults.standard.string(forKey: userDefaultsCurrentLocaleKey), let locale = keyboardContext.locales.first(where: { $0.identifier == currentLocale }) {
            keyboardContext.locale = locale
        }
        
        currentLocaleCancellable = keyboardContext.$locale.sink(receiveValue: { UserDefaults.standard.set($0.identifier, forKey: self.userDefaultsCurrentLocaleKey) })
    }
}
