//
//  ShoppingListModel.swift
//  fridgescannerapp
//
//  The household's shared shopping list: add items (by hand or from a
//  recipe's missing ingredients), check them off, and move bought items
//  into the fridge. Created once per sign-in, like RecipeSearchModel.
//

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ShoppingListModel {
    var newItemText = ""
    /// Shown under the add field when the item is already on the list.
    private(set) var entryMessage: String?

    let account: Account
    let household: Household
    private let modelContext: ModelContext

    init(account: Account, household: Household, context: ModelContext) {
        self.account = account
        self.household = household
        self.modelContext = context
    }

    /// Unchecked items first, then oldest first.
    var items: [ShoppingListItem] {
        household.shoppingItems.sorted {
            if $0.isChecked != $1.isChecked { return !$0.isChecked }
            return $0.addedAt < $1.addedAt
        }
    }

    var checkedCount: Int {
        // Functional: filter keeps the checked items, then count them
        household.shoppingItems.filter(\.isChecked).count
    }

    func contains(_ name: String) -> Bool {
        household.shoppingItems.contains { ingredientNamesMatch($0.name, name) }
    }

    func addItem() {
        let name = normalizedIngredientName(newItemText)
        guard !name.isEmpty else { return }
        guard !contains(name) else {
            entryMessage = "\(name.capitalized) is already on the list."
            return
        }
        add(name)
        newItemText = ""
        entryMessage = nil
    }

    /// Adds several names at once, e.g. a recipe's missing ingredients.
    func addAll(_ names: [String]) {
        names.filter { !contains($0) }.forEach(add)
    }

    func toggle(_ item: ShoppingListItem) {
        item.isChecked.toggle()
        save()
    }

    func remove(at offsets: IndexSet) {
        let current = items
        offsets.map { current[$0] }.forEach { household.removeShoppingItem($0, in: modelContext) }
        save()
    }

    /// Moves every checked item into the fridge (with no expiration date) and
    /// off the list. Returns how many were moved.
    func moveCheckedToFridge() -> Int {
        let checked = household.shoppingItems.filter(\.isChecked)
        for item in checked {
            if !household.items.contains(where: { $0.name == item.name }) {
                household.addItem(FridgeItem(name: item.name), addedBy: account.user, in: modelContext)
            }
            household.removeShoppingItem(item, in: modelContext)
        }
        save()
        return checked.count
    }

    func clearEntryMessage() {
        entryMessage = nil
    }

    private func add(_ name: String) {
        household.addShoppingItem(ShoppingListItem(name: normalizedIngredientName(name)), in: modelContext)
        save()
    }

    private func save() {
        try? modelContext.save()
    }
}
