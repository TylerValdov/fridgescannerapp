//
//  RecipeModels.swift
//  fridgescannerapp
//
//  Plain data types decoded from Spoonacular responses (and from the
//  bundled demo data), shared by every screen that shows a recipe.
//

import Foundation

// Codable (not just Decodable) so recipes can be encoded as well as decoded.
struct IngredientRef: Codable, Hashable {
    let id: Int
    let name: String
    let image: String?
}

struct IngredientSuggestion: Decodable, Identifiable, Hashable {
    let name: String
    var id: String { name }
}

struct RecipeMatch: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    // complexSearch occasionally returns recipes without an image.
    let image: String?
    let usedIngredientCount: Int
    let missedIngredientCount: Int
    let missedIngredients: [IngredientRef]
    let usedIngredients: [IngredientRef]
}

// One page of /recipes/complexSearch results.
struct RecipeSearchPage: Decodable {
    let results: [RecipeMatch]
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
