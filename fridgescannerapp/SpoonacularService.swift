//
//  SpoonacularService.swift
//  fridgescannerapp
//

import Foundation

enum SpoonacularError: LocalizedError {
    case invalidURL
    case requestFailed(statusCode: Int)
    case quotaExceeded

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Couldn't build the Spoonacular request URL."
        case .requestFailed(let statusCode):
            return "Spoonacular request failed (HTTP \(statusCode))."
        case .quotaExceeded:
            return "Daily Spoonacular quota used up - try again tomorrow."
        }
    }
}

struct SpoonacularQuota {
    let used: Double
    let left: Double
}

struct SpoonacularResult {
    let recipes: [RecipeMatch]
    let quota: SpoonacularQuota?
}

struct SpoonacularService {
    private let apiKey: String
    private let session: URLSession

    init(apiKey: String = Secrets.spoonacularAPIKey, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    // Spoonacular's free tier is capped at 50 points/day. complexSearch is used rather than
    // findByIngredients because only it can filter by diet, intolerances and excluded
    // ingredients. With fillIngredients it costs ~1 point plus ~0.035 per result.
    func searchRecipes(
        including ingredients: [String],
        excluding excluded: [String] = [],
        diet: String? = nil,
        intolerances: [String] = [],
        number: Int = 20
    ) async throws -> SpoonacularResult {
        var components = URLComponents(string: "https://api.spoonacular.com/recipes/complexSearch")
        var queryItems = [
            // Ranks by how many of these a recipe uses; it doesn't require all of them.
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
        guard let url = components?.url else { throw SpoonacularError.invalidURL }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpoonacularError.requestFailed(statusCode: -1)
        }

        if httpResponse.statusCode == 402 {
            throw SpoonacularError.quotaExceeded
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw SpoonacularError.requestFailed(statusCode: httpResponse.statusCode)
        }

        let page = try JSONDecoder().decode(RecipeSearchPage.self, from: data)
        let quota = quota(from: httpResponse)
        return SpoonacularResult(recipes: page.results, quota: quota)
    }

    // Resolves partial/misspelled/ambiguous text (e.g. "chik" -> "chicken") against
    // Spoonacular's real ingredient list, before it's ever sent to complexSearch.
    func autocompleteIngredients(matching query: String, number: Int = 5) async throws -> [IngredientSuggestion] {
        var components = URLComponents(string: "https://api.spoonacular.com/food/ingredients/autocomplete")
        components?.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "number", value: String(number)),
            URLQueryItem(name: "apiKey", value: apiKey)
        ]
        guard let url = components?.url else { throw SpoonacularError.invalidURL }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpoonacularError.requestFailed(statusCode: -1)
        }

        if httpResponse.statusCode == 402 {
            throw SpoonacularError.quotaExceeded
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw SpoonacularError.requestFailed(statusCode: httpResponse.statusCode)
        }

        return try JSONDecoder().decode([IngredientSuggestion].self, from: data)
    }
    func getRecipeDetails(id: Int) async throws -> RecipeDetails {
        var components = URLComponents(
            string: "https://api.spoonacular.com/recipes/\(id)/information"
        )

        components?.queryItems = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "includeNutrition", value: "false")
        ]

        guard let url = components?.url else {
            throw SpoonacularError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpoonacularError.requestFailed(statusCode: -1)
        }

        if httpResponse.statusCode == 402 {
            throw SpoonacularError.quotaExceeded
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw SpoonacularError.requestFailed(
                statusCode: httpResponse.statusCode
            )
        }

        return try JSONDecoder().decode(RecipeDetails.self, from: data)
    }
    private func quota(from response: HTTPURLResponse) -> SpoonacularQuota? {
        guard
            let usedString = response.value(forHTTPHeaderField: "X-API-Quota-Used"),
            let leftString = response.value(forHTTPHeaderField: "X-API-Quota-Left"),
            let used = Double(usedString),
            let left = Double(leftString)
        else { return nil }
        return SpoonacularQuota(used: used, left: left)
    }
}
