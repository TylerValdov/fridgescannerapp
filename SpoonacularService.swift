
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

    init(apiKey: String = "",
         session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func findRecipes(
        byIngredients ingredients: [String],
        number: Int = 5
    ) async throws -> SpoonacularResult {

        var components = URLComponents(
            string: "https://api.spoonacular.com/recipes/findByIngredients"
        )

        components?.queryItems = [
            URLQueryItem(
                name: "ingredients",
                value: ingredients.joined(separator: ",")
            ),
            URLQueryItem(name: "number", value: String(number)),
            URLQueryItem(name: "ranking", value: "2"),
            URLQueryItem(name: "ignorePantry", value: "true"),
            URLQueryItem(name: "apiKey", value: apiKey)
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

        let recipes = try JSONDecoder().decode(
            [RecipeMatch].self,
            from: data
        )

        let quota = quota(from: httpResponse)

        return SpoonacularResult(recipes: recipes, quota: quota)
    }

    func autocompleteIngredients(
        matching query: String,
        number: Int = 5
    ) async throws -> [IngredientSuggestion] {

        var components = URLComponents(
            string: "https://api.spoonacular.com/food/ingredients/autocomplete"
        )

        components?.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "number", value: String(number)),
            URLQueryItem(name: "apiKey", value: apiKey)
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

        return try JSONDecoder().decode(
            [IngredientSuggestion].self,
            from: data
        )
    }

    private func quota(
        from response: HTTPURLResponse
    ) -> SpoonacularQuota? {

        guard
            let usedString = response.value(
                forHTTPHeaderField: "X-API-Quota-Used"
            ),
            let leftString = response.value(
                forHTTPHeaderField: "X-API-Quota-Left"
            ),
            let used = Double(usedString),
            let left = Double(leftString)
        else {
            return nil
        }

        return SpoonacularQuota(used: used, left: left)
    }
}
