//
//  SavedRecipeStore.swift
//  fridgescannerapp
//
//  The signed-in user's favorites and cooking history, saved with SwiftData
//  as SavedRecipe rows. (Replaces the UserDefaults version; the method names
//  are unchanged so HomeView and the recipe screens work as before.)
//

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class SavedRecipeStore {
    private static let maxRecent = 20

    private let user: User
    private let context: ModelContext

    init(user: User, context: ModelContext) {
        self.user = user
        self.context = context
    }

    /// Most recently favorited first.
    var likedRecipes: [RecipeMatch] {
        // Functional: filter, sort and map the user's saved rows into display values
        user.savedRecipes
            .filter(\.isFavorite)
            .sorted { ($0.favoritedAt ?? .distantPast) > ($1.favoritedAt ?? .distantPast) }
            .map(\.match)
    }

    /// Most recently cooked first.
    var recentRecipes: [RecipeMatch] {
        user.savedRecipes
            .filter { $0.lastCookedAt != nil }
            .sorted { ($0.lastCookedAt ?? .distantPast) > ($1.lastCookedAt ?? .distantPast) }
            .prefix(SavedRecipeStore.maxRecent)
            .map(\.match)
    }

    func isLiked(_ recipe: RecipeMatch) -> Bool {
        savedRecipe(withID: recipe.id)?.isFavorite == true
    }

    func timesCooked(_ recipe: RecipeMatch) -> Int {
        savedRecipe(withID: recipe.id)?.timesCooked ?? 0
    }

    func toggleLike(_ recipe: RecipeMatch) {
        let saved = savedRecipe(for: recipe)
        saved.isFavorite.toggle()
        saved.favoritedAt = saved.isFavorite ? .now : nil
        removeIfUnused(saved)
        try? context.save()
    }

    /// Records that the user cooked this recipe ("Mark as Cooked").
    func addToRecent(_ recipe: RecipeMatch) {
        let saved = savedRecipe(for: recipe)
        saved.timesCooked += 1
        saved.lastCookedAt = .now
        try? context.save()
    }

    private func savedRecipe(withID id: Int) -> SavedRecipe? {
        user.savedRecipes.first { $0.recipeID == id }
    }

    /// The existing row for this recipe, or a new one.
    private func savedRecipe(for recipe: RecipeMatch) -> SavedRecipe {
        if let existing = savedRecipe(withID: recipe.id) {
            return existing
        }
        let saved = SavedRecipe(recipe: recipe)
        user.addSavedRecipe(saved, in: context)
        return saved
    }

    private func removeIfUnused(_ saved: SavedRecipe) {
        if saved.isUnused {
            user.removeSavedRecipe(saved, in: context)
        }
    }
}
