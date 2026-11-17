//
//  SavedRecipe.swift
//  fridgescannerapp
//
//  A recipe one user has favorited or cooked. Stores a small snapshot of
//  the recipe so Home can show it without a network request.
//

import Foundation
import SwiftData

// OOP: a SwiftData model class.
@Model
final class SavedRecipe {
    var recipeID: Int
    var title: String
    var imageURL: String?
    var usedIngredientCount: Int     // From when it was saved, not the current fridge
    var missedIngredientCount: Int
    var isFavorite: Bool = false
    var favoritedAt: Date?
    var timesCooked: Int = 0
    var lastCookedAt: Date?
    var user: User?

    init(recipe: RecipeMatch) {
        self.recipeID = recipe.id
        self.title = recipe.title
        self.imageURL = recipe.image
        self.usedIngredientCount = recipe.usedIngredientCount
        self.missedIngredientCount = recipe.missedIngredientCount
    }
}

extension SavedRecipe {
    /// The snapshot as a RecipeMatch, so existing views can show it.
    var match: RecipeMatch {
        RecipeMatch(
            id: recipeID,
            title: title,
            image: imageURL,
            usedIngredientCount: usedIngredientCount,
            missedIngredientCount: missedIngredientCount,
            missedIngredients: [],
            usedIngredients: []
        )
    }

    /// Neither a favorite nor cooked, so there's no reason to keep it.
    var isUnused: Bool {
        !isFavorite && timesCooked == 0
    }
}
