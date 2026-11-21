//
//  fridgescannerappUITests.swift
//  fridgescannerapp
//
//  UI test (XCTest): signs in as the demo admin, adds a uniquely named item
//  on the Fridge tab, checks it shows up, then swipes it away so repeated
//  runs leave the demo fridge unchanged. Covers requirements 1 and 2.
//

import XCTest

final class fridgescannerappUITests: XCTestCase {

    override func setUpWithError() throws {
        // Stop at the first failure; later steps depend on earlier ones.
        continueAfterFailure = false
    }

    @MainActor
    func testSignInAddAndRemoveFridgeItem() throws {
        let app = XCUIApplication()
        app.launch()

        // Sign in as the Maple St admin.
        let username = app.textFields["Username"]
        XCTAssertTrue(username.waitForExistence(timeout: 5), "Sign-in screen didn't appear")
        username.tap()
        username.typeText("dana")
        let password = app.secureTextFields["Password"]
        password.tap()
        password.typeText("Fridge123")
        app.buttons["Sign In"].tap()

        // Go to the Fridge tab.
        let fridgeTab = app.tabBars.buttons["Fridge"]
        XCTAssertTrue(fridgeTab.waitForExistence(timeout: 5), "Didn't reach the tabs after signing in")
        tapUntil(fridgeTab, matches: "selected == true")

        // Add an item with a unique name, so old runs can't make this pass.
        let name = "uitest item \(Int.random(in: 1000...9999))"
        let field = app.textFields["e.g. Tomatoes"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        tapUntil(field, matches: "hasKeyboardFocus == true")
        field.typeText(name)
        app.buttons["Add"].tap()

        // The row shows the name capitalized ("Uitest Item 1234"), plus who added it.
        // New items go at the bottom, so scroll down until it's on screen.
        let row = app.cells.containing(NSPredicate(format: "label CONTAINS[c] %@", name)).firstMatch
        var swipes = 0
        while !(row.exists && row.isHittable) && swipes < 10 {
            app.collectionViews.firstMatch.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(row.exists, "New item didn't appear in the fridge")

        // Clean up: swipe to delete, and check it's gone.
        row.swipeLeft()
        app.buttons["Delete"].tap()
        XCTAssertFalse(row.waitForExistence(timeout: 2), "Item is still in the fridge after deleting")
    }

    /// Taps an element until `condition` is true, e.g. a tab is selected or a
    /// field has the cursor. A tap during a screen transition can be lost.
    @MainActor
    private func tapUntil(_ element: XCUIElement, matches condition: String) {
        let predicate = NSPredicate(format: condition)
        for _ in 1...3 {
            element.tap()
            if XCTWaiter.wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: 2) == .completed {
                return
            }
        }
        XCTFail("Tapping \(element) never made \(condition)")
    }
}
