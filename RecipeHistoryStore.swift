//
//  Untitled.swift
//  fridgescannerapp
//
//  Created by lending on 10/25/26.
//


import Foundation
import Observation

@MainActor
@Observable
final class RecipeHistoryStore {
    private(set) var likedRecipes: [RecipeMatch] = []
    private(set) var recentRecipes: [RecipeMatch] = []

    private let likedKey = "likedRecipes"
    private let recentKey = "recentRecipes"

    init() {
        likedRecipes = loadRecipes(forKey: likedKey)
        recentRecipes = loadRecipes(forKey: recentKey)
    }

    func isLiked(_ recipe: RecipeMatch) -> Bool {
        likedRecipes.contains { $0.id == recipe.id }
    }

    func toggleLike(_ recipe: RecipeMatch) {
        if isLiked(recipe) {
            likedRecipes.removeAll { $0.id == recipe.id }
        } else {
            likedRecipes.insert(recipe, at: 0)
        }

        saveRecipes(likedRecipes, forKey: likedKey)
    }

    func addToRecent(_ recipe: RecipeMatch) {
        recentRecipes.removeAll { $0.id == recipe.id }
        recentRecipes.insert(recipe, at: 0)

        // Keep the 20 most recent recipes
        if recentRecipes.count > 20 {
            recentRecipes = Array(recentRecipes.prefix(20))
        }

        saveRecipes(recentRecipes, forKey: recentKey)
    }

    private func saveRecipes(
        _ recipes: [RecipeMatch],
        forKey key: String
    ) {
        guard let data = try? JSONEncoder().encode(recipes) else {
            return
        }

        UserDefaults.standard.set(data, forKey: key)
    }

    private func loadRecipes(forKey key: String) -> [RecipeMatch] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let recipes = try? JSONDecoder().decode(
                [RecipeMatch].self,
                from: data
              ) else {
            return []
        }

        return recipes
    }
}
