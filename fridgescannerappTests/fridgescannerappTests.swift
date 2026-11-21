//
//  fridgescannerappTests.swift
//  fridgescannerapp
//
//  Unit tests (Swift Testing) for the helpers, the scanner's product names,
//  the sign-up rules, password hashing, the shopping list, Undo in the
//  fridge, and grouping recipes by how many ingredients are missing. Each test builds the demo data in an
//  in-memory store, so nothing touches the app's real data or the API.
//

import Foundation
import SwiftData
import Testing
@testable import fridgescannerapp

// App code runs on the main actor by default, so the tests do too.
@MainActor
struct fridgescannerappTests {

    // MARK: - Helpers.swift

    @Test func ingredientNameHelpers() {
        #expect(normalizedIngredientName("  Eggs ") == "eggs")
        #expect(ingredientNamesMatch("egg", "Eggs"))
        #expect(ingredientNamesMatch("garlic", "garlic cloves"))
        #expect(!ingredientNamesMatch("milk", "rice"))
        #expect(!ingredientNamesMatch("", "rice"))
        #expect(pluralize("item", count: 1) == "1 item")
        #expect(pluralize("item", count: 3) == "3 items")
    }

    // MARK: - Scanner (requirement 2)

    @Test func productNamesBecomeIngredientNames() {
        #expect(ingredientName(fromProduct: "Great Value Whole Milk") == "milk")
        #expect(ingredientName(fromProduct: "Large Brown Eggs") == "eggs")
        #expect(ingredientName(fromProduct: "Organic Green Onions") == "green onions")  // longest match wins
        #expect(ingredientName(fromProduct: "Honey Maid Graham Crackers") == "honey")   // not "ham"
        #expect(ingredientName(fromProduct: "  Sparkling Water ") == "sparkling water") // no match: keep the name
    }

    // MARK: - Sign-up rules (requirement 1)

    @Test func usernameRules() {
        #expect(usernameProblem("dana") == nil)
        #expect(usernameProblem("ab") != nil)                    // too short
        #expect(usernameProblem(String(repeating: "a", count: 21)) != nil)
        #expect(usernameProblem("dana!") != nil)                 // symbol
    }

    @Test func passwordRules() {
        #expect(passwordProblem("Fridge123") == nil)
        #expect(passwordProblem("abc12") != nil)                 // too short
        #expect(passwordProblem("abcdefgh") != nil)              // no number
        #expect(passwordProblem("12345678") != nil)              // no letter
    }

    // MARK: - Password hashing (security requirement)

    @Test func passwordHashing() {
        let credential = makeCredential(for: "Fridge123")
        #expect(verifyPassword("Fridge123", against: credential))
        #expect(!verifyPassword("fridge123", against: credential))

        // A random salt per user: the same password gives a different hash.
        #expect(makeCredential(for: "Fridge123").hash != credential.hash)
    }

    // MARK: - Shopping list (requirement 9)

    @Test func shoppingListRejectsDuplicatesAndMovesToFridge() throws {
        let session = SampleData.makePreviewSession()
        let household = try #require(session.account.household)
        let list = ShoppingListModel(account: session.account, household: household, context: session.container.mainContext)

        list.newItemText = "Zucchini"
        list.addItem()
        #expect(list.contains("zucchini"))
        #expect(list.entryMessage == nil)

        // Error prevention: adding it again shows a message instead.
        list.newItemText = "zucchini "
        list.addItem()
        #expect(list.entryMessage != nil)

        let item = try #require(list.items.first { $0.name == "zucchini" })
        list.toggle(item)
        #expect(list.moveCheckedToFridge() == 1)
        #expect(household.items.contains { $0.name == "zucchini" })
        #expect(!list.contains("zucchini"))
    }

    // MARK: - Fridge Undo (requirements 2 and 5)

    @Test func removingAFridgeItemCanBeUndone() throws {
        let session = SampleData.makePreviewSession(role: .member)
        let household = try #require(session.account.household)
        let model = RecipeSearchModel(
            account: session.account, household: household,
            context: session.container.mainContext, provider: MockRecipeProvider()
        )
        let countBefore = model.items.count
        let removedName = try #require(model.items.first?.name)

        model.removeItems(at: IndexSet(integer: 0))
        #expect(model.items.count == countBefore - 1)
        #expect(model.recentlyRemoved != nil)

        model.undoRemoval()
        #expect(model.items.count == countBefore)
        #expect(model.ingredients.contains(removedName))
        #expect(model.recentlyRemoved == nil)
    }

    // MARK: - Recipe sections (requirement 3)

    @Test func recipesAreGroupedByMissingCount() async throws {
        let session = SampleData.makePreviewSession(role: .member)
        let household = try #require(session.account.household)
        let model = RecipeSearchModel(
            account: session.account, household: household,
            context: session.container.mainContext, provider: MockRecipeProvider()
        )

        await model.search()
        #expect(model.isUsingDemoData)
        #expect(!model.sections.isEmpty)

        // Functional: allSatisfy checks every recipe is in the right section.
        for section in model.sections {
            let fits: (RecipeMatch) -> Bool = switch section.title {
            case "Ready to Make": { $0.missedIngredientCount == 0 }
            case "Missing 1 Ingredient": { $0.missedIngredientCount == 1 }
            default: { $0.missedIngredientCount >= 2 }
            }
            #expect(section.recipes.allSatisfy(fits), "Wrong recipe in \(section.title)")
        }

        // Nothing above the household's "max missing" setting is shown.
        let shown = model.sections.flatMap(\.recipes)
        #expect(shown.allSatisfy { $0.missedIngredientCount <= model.preferences.maxMissing })
    }
}
