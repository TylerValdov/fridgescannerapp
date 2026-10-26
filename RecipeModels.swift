//
//  RecipeModels.swift
//  fridgescannerapp
//

import Foundation

struct IngredientRef: Codable, Hashable {
    let id: Int
    let name: String
    let image: String
}

struct IngredientSuggestion: Decodable, Identifiable, Hashable {
    let name: String
    var id: String { name }
}

struct RecipeMatch: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let image: String
    let usedIngredientCount: Int
    let missedIngredientCount: Int
    let missedIngredients: [IngredientRef]
    let usedIngredients: [IngredientRef]
}
