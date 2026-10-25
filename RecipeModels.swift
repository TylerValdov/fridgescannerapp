//
//  RecipeModels.swift
//  fridgescannerapp
//

import Foundation

struct IngredientRef: Decodable, Hashable {
    let id: Int
    let name: String
    let image: String
}

struct IngredientSuggestion: Decodable, Identifiable, Hashable {
    let name: String
    var id: String { name }
}

struct RecipeMatch: Decodable, Identifiable, Hashable {
    let id: Int
    let title: String
    let image: String
    let usedIngredientCount: Int
    let missedIngredientCount: Int
    let missedIngredients: [IngredientRef]
    let usedIngredients: [IngredientRef]
}
struct RecipeDetails: Decodable {
    let id: Int
    let title: String
    let image: String?
    let readyInMinutes: Int?
    let servings: Int?
    let summary: String?
    let instructions: String?
    let sourceUrl: String?
    let extendedIngredients: [RecipeDetailIngredient]?
}

struct RecipeDetailIngredient: Decodable, Identifiable {
    let original: String

    var id: String { original }
}
