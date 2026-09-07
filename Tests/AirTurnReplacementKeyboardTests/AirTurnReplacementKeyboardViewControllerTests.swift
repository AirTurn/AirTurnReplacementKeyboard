import XCTest
import KeyboardKit
@testable import AirTurnReplacementKeyboard

@MainActor
final class AirTurnReplacementKeyboardViewControllerTests: XCTestCase {
    func testConfiguredKeyboardKitLocalesMapsIdentifiersAndDeduplicates() {
        let locales = AirTurnReplacementKeyboardViewController.configuredKeyboardKitLocales(
            from: ["en-GB", "en_US", "en-GB", "fr", "fr_CA"]
        )

        let identifiers = locales.map { $0.identifier.replacingOccurrences(of: "-", with: "_") }

        XCTAssertEqual(Set(identifiers).count, identifiers.count)
        XCTAssertTrue(identifiers.count >= 2)
        XCTAssertTrue(identifiers.contains { $0.hasPrefix("en") })
    }

    func testConfiguredKeyboardKitLocalesFallsBackToEnglish() {
        let locales = AirTurnReplacementKeyboardViewController.configuredKeyboardKitLocales(
            from: ["not-a-locale", "zz-ZZ"]
        )

        XCTAssertEqual(locales.count, 1)
        XCTAssertEqual(locales[0].identifier, "en")
    }

    func testDefaultLocaleChoosesPreferredFirst() {
        let locales = [
            Locale(identifier: "fr_FR"),
            Locale(identifier: "de_DE"),
            Locale(identifier: "en_US")
        ]
        let selected = AirTurnReplacementKeyboardViewController.defaultLocale(
            for: locales,
            preferredLocale: Locale(identifier: "de_DE"),
            storedLocaleIdentifier: "en_US"
        )

        XCTAssertEqual(selected.identifier, Locale(identifier: "de_DE").identifier)
    }

    func testDefaultLocaleFallsBackToStoredLocaleAndThenFirst() {
        let locales = [
            Locale(identifier: "fr_FR"),
            Locale(identifier: "de_DE")
        ]

        let fromStored = AirTurnReplacementKeyboardViewController.defaultLocale(
            for: locales,
            preferredLocale: Locale(identifier: "en_US"),
            storedLocaleIdentifier: "de_DE"
        )
        XCTAssertEqual(fromStored.identifier, "de_DE")

        let fromFirst = AirTurnReplacementKeyboardViewController.defaultLocale(
            for: locales,
            preferredLocale: Locale(identifier: "en_US"),
            storedLocaleIdentifier: "it_IT"
        )
        XCTAssertEqual(fromFirst.identifier, "fr_FR")
    }

    func testFooterControlsLeaveSpaceRowUnchanged() {
        let layout = KeyboardLayout(itemRows: [
            [
                KeyboardLayoutItem(
                    action: .space,
                    size: KeyboardLayoutItem.Size(width: .input, height: 0)
                )
            ]
        ])

        let updated = AirTurnReplacementKeyboardView.layoutForSeparateControls(layout)

        let actions = updated.itemRows[0].map(\.action)
        XCTAssertEqual(actions, [.space])
        XCTAssertFalse(updated.hasKey(for: .keyboardType(.emojis)))
    }

    func testFooterControlsRemoveSystemSwitcherFromKeyRows() {
        let layout = KeyboardLayout(itemRows: [
            [
                KeyboardLayoutItem(
                    action: .nextKeyboard,
                    size: KeyboardLayoutItem.Size(width: .input, height: 0)
                ),
                KeyboardLayoutItem(
                    action: .space,
                    size: KeyboardLayoutItem.Size(width: .input, height: 0)
                )
            ]
        ])

        let updated = AirTurnReplacementKeyboardView.layoutForSeparateControls(layout)

        XCTAssertFalse(updated.hasKey(for: .nextLocale))
        XCTAssertFalse(updated.hasKey(for: .nextKeyboard))
    }

    func testPreparedForHostClearsToolbarHeightAndAppliesBottomInset() {
        let context = KeyboardContext()
        context.deviceTypeForKeyboard = .phone
        context.screenSize = CGSize(width: 402, height: 874)
        context.interfaceOrientation = .portrait
        context.locales = [.english]
        context.keyboardType = .alphabetic

        let layout = KeyboardLayout.standard(for: context)
        XCTAssertGreaterThan(layout.configuration.inputToolbarHeight, 0)

        let prepared = layout.preparedForHost(
            hostHeight: 300,
            bottomSafeAreaInset: 34,
            includeAutocompleteToolbar: false
        )

        XCTAssertEqual(prepared.configuration.inputToolbarHeight, 0)
        XCTAssertEqual(prepared.configuration.edgeInsets.bottom, 34, accuracy: 0.1)
        // Rows fill the host above the bottom inset (totalHeight is key rows only).
        XCTAssertEqual(prepared.totalHeight + prepared.configuration.edgeInsets.bottom, 300, accuracy: 1.0)
    }

    func testPreparedForHostScalesShortLayoutUpToFillHost() {
        let context = KeyboardContext()
        context.deviceTypeForKeyboard = .phone
        context.screenSize = CGSize(width: 402, height: 874)
        context.interfaceOrientation = .portrait
        context.locales = [.english]
        context.keyboardType = .alphabetic

        let layout = KeyboardLayout.standard(for: context)
        let naturalHeight = layout.totalHeight
        XCTAssertLessThan(naturalHeight, 280)

        let prepared = layout.preparedForHost(
            hostHeight: 280,
            bottomSafeAreaInset: 0,
            includeAutocompleteToolbar: false
        )

        XCTAssertEqual(prepared.totalHeight, 280, accuracy: 1.0)
        XCTAssertGreaterThan(prepared.configuration.rowHeight, layout.configuration.rowHeight)
    }

    func testSystemKeyboardGeometryPhonePortraitMatchesCommonFrame() {
        let height = SystemKeyboardGeometry.estimatedHeight(
            screenSize: CGSize(width: 402, height: 874),
            orientation: .portrait,
            deviceType: .phone,
            bottomSafeAreaInset: 34,
            includeAutocompleteToolbar: false
        )
        // Classic 216 key rows + 34 home indicator + 24 modern chrome = 274.
        XCTAssertEqual(height, 274, accuracy: 0.1)
    }

    func testSystemKeyboardGeometryIncludesAutocompleteToolbar() {
        let without = SystemKeyboardGeometry.estimatedHeight(
            screenSize: CGSize(width: 393, height: 852),
            orientation: .portrait,
            deviceType: .phone,
            bottomSafeAreaInset: 34,
            includeAutocompleteToolbar: false
        )
        let with = SystemKeyboardGeometry.estimatedHeight(
            screenSize: CGSize(width: 393, height: 852),
            orientation: .portrait,
            deviceType: .phone,
            bottomSafeAreaInset: 34,
            includeAutocompleteToolbar: true
        )
        XCTAssertEqual(
            with - without,
            SystemKeyboardGeometry.autocompleteToolbarHeight,
            accuracy: 0.1
        )
    }

    func testSystemKeyboardGeometryHomeButtonPhoneUsesClassicHeight() {
        let height = SystemKeyboardGeometry.estimatedHeight(
            screenSize: CGSize(width: 375, height: 667),
            orientation: .portrait,
            deviceType: .phone,
            bottomSafeAreaInset: 0,
            includeAutocompleteToolbar: false
        )
        XCTAssertEqual(height, 216, accuracy: 0.1)
    }

    func testFooterOwnsEmojiSwitcher() {
        let layout = KeyboardLayout(itemRows: [
            [
                KeyboardLayoutItem(
                    action: .keyboardType(.emojis),
                    size: KeyboardLayoutItem.Size(width: .input, height: 0)
                ),
                KeyboardLayoutItem(
                    action: .keyboardType(.numeric),
                    size: KeyboardLayoutItem.Size(width: .input, height: 0)
                ),
                KeyboardLayoutItem(
                    action: .space,
                    size: KeyboardLayoutItem.Size(width: .input, height: 0)
                )
            ]
        ])

        let updated = AirTurnReplacementKeyboardView.layoutForSeparateControls(layout)

        XCTAssertFalse(updated.hasKey(for: .keyboardType(.emojis)))
    }
}
