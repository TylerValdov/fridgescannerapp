//
//  SpoonacularProvider.swift
//  fridgescannerapp
//
//  Live recipe data from the Spoonacular API. The free tier allows 50
//  points a day; a 20-result search costs about 1.7.
//

import Foundation

// OOP: subclass of RecipeProvider that makes real network requests.
final class SpoonacularProvider: RecipeProvider {
    private let apiKey: String

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        super.init(session: session)
    }

    // complexSearch rather than findByIngredients, because only it can filter by
    // diet, intolerances and excluded ingredients. It ranks recipes by how many
    // listed ingredients they use; it doesn't require all of them.
    override func searchRecipes(
        including ingredients: [String],
        excluding excluded: [String],
        diet: String?,
        intolerances: [String],
        number: Int
    ) async throws -> SpoonacularResult {
        var components = URLComponents(string: "https://api.spoonacular.com/recipes/complexSearch")
        var queryItems = [
            URLQueryItem(name: "includeIngredients", value: ingredients.joined(separator: ",")),
            URLQueryItem(name: "sort", value: "min-missing-ingredients"),
            // Adds used/missed ingredient lists and counts, matching RecipeMatch.
            URLQueryItem(name: "fillIngredients", value: "true"),
            URLQueryItem(name: "ignorePantry", value: "true"),
            URLQueryItem(name: "number", value: String(number)),
            URLQueryItem(name: "apiKey", value: apiKey)
        ]
        if !excluded.isEmpty {
            queryItems.append(URLQueryItem(name: "excludeIngredients", value: excluded.joined(separator: ",")))
        }
        if let diet {
            queryItems.append(URLQueryItem(name: "diet", value: diet))
        }
        if !intolerances.isEmpty {
            queryItems.append(URLQueryItem(name: "intolerances", value: intolerances.joined(separator: ",")))
        }
        components?.queryItems = queryItems

        let (page, response) = try await fetch(RecipeSearchPage.self, from: components)
        return SpoonacularResult(recipes: page.results, quota: quota(from: response))
    }

    // Resolves partial or misspelled text (e.g. "chik" -> "chicken") against
    // Spoonacular's real ingredient list before it's ever searched.
    override func autocompleteIngredients(matching query: String, number: Int) async throws -> [IngredientSuggestion] {
        var components = URLComponents(string: "https://api.spoonacular.com/food/ingredients/autocomplete")
        components?.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "number", value: String(number)),
            URLQueryItem(name: "apiKey", value: apiKey)
        ]
        return try await fetch([IngredientSuggestion].self, from: components).0
    }

    override func recipeDetails(id: Int) async throws -> RecipeDetails {
        var components = URLComponents(string: "https://api.spoonacular.com/recipes/\(id)/information")
        components?.queryItems = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "includeNutrition", value: "false")
        ]
        return try await fetch(RecipeDetails.self, from: components).0
    }
}
