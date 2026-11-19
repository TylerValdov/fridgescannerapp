//
//  ModelLinks.swift
//  fridgescannerapp
//
//  The one place models get connected to each other. Each helper inserts
//  the new object first, then sets the relationship, because SwiftData
//  requires both objects to be in the same context. Setting one side is
//  enough: SwiftData fills in the other (e.g. household.members).
//

import Foundation
import SwiftData

extension Household {
    func addMember(_ user: User, in context: ModelContext) {
        context.insert(user)
        user.household = self
    }

    /// Their favorites and cooking history are deleted with them.
    func removeMember(_ user: User, in context: ModelContext) {
        user.household = nil
        context.delete(user)
    }

    func addItem(_ item: FridgeItem, addedBy user: User?, in context: ModelContext) {
        context.insert(item)
        item.household = self
        item.addedBy = user
    }

    func removeItem(_ item: FridgeItem, in context: ModelContext) {
        item.household = nil
        context.delete(item)
    }

    func addShoppingItem(_ item: ShoppingListItem, in context: ModelContext) {
        context.insert(item)
        item.household = self
    }

    func removeShoppingItem(_ item: ShoppingListItem, in context: ModelContext) {
        item.household = nil
        context.delete(item)
    }

    func attachPreferences(_ preferences: MealPreferences, in context: ModelContext) {
        context.insert(preferences)
        preferences.household = self
    }
}

extension User {
    func addSavedRecipe(_ recipe: SavedRecipe, in context: ModelContext) {
        context.insert(recipe)
        recipe.user = self
    }

    func removeSavedRecipe(_ recipe: SavedRecipe, in context: ModelContext) {
        recipe.user = nil
        context.delete(recipe)
    }
}
