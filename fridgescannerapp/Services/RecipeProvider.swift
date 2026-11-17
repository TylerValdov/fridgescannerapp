//
//  RecipeProvider.swift
//  fridgescannerapp
//
//  The base class for where recipes come from, plus the shared result and
//  error types. RecipeSearchModel only talks to `RecipeProvider`, so it can
//  switch from the live API to demo data without any other changes.
//

import Foundation

enum SpoonacularError: LocalizedError {
    case invalidURL
    case requestFailed(statusCode: Int)
    case quotaExceeded
    case notInDemoData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Couldn't build the Spoonacular request URL."
        case .requestFailed(let statusCode):
            return "Spoonacular request failed (HTTP \(statusCode))."
        case .quotaExceeded:
            return "Daily Spoonacular quota used up - try again tomorrow."
        case .notInDemoData:
            return "This recipe isn't in the demo data. Add a Spoonacular key to see it."
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

// OOP: base class. SpoonacularProvider and MockRecipeProvider override the
// three requests; the shared HTTP handling lives here so it isn't repeated.
class RecipeProvider {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// True for the bundled sample data, so the app can label it.
    var isDemoData: Bool { false }

    /// Spoonacular when a key is set up in Secrets.plist, otherwise demo data.
    static func makeDefault() -> RecipeProvider {
        if let key = AppSecrets.spoonacularAPIKey {
            return SpoonacularProvider(apiKey: key)
        }
        return MockRecipeProvider()
    }

    // MARK: - Requests (every subclass overrides these)

    func searchRecipes(
        including ingredients: [String],
        excluding excluded: [String] = [],
        diet: String? = nil,
        intolerances: [String] = [],
        number: Int = 20
    ) async throws -> SpoonacularResult {
        preconditionFailure("Subclasses must override searchRecipes")
    }

    func autocompleteIngredients(matching query: String, number: Int = 5) async throws -> [IngredientSuggestion] {
        preconditionFailure("Subclasses must override autocompleteIngredients")
    }

    func recipeDetails(id: Int) async throws -> RecipeDetails {
        preconditionFailure("Subclasses must override recipeDetails")
    }

    // MARK: - Shared networking

    /// Sends a GET request, checks the status code, and decodes the JSON.
    func fetch<Response: Decodable>(
        _ type: Response.Type,
        from components: URLComponents?
    ) async throws -> (Response, HTTPURLResponse) {
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

        return (try JSONDecoder().decode(type, from: data), httpResponse)
    }

    /// Reads the points used and left today from Spoonacular's response headers.
    func quota(from response: HTTPURLResponse) -> SpoonacularQuota? {
        guard
            let usedString = response.value(forHTTPHeaderField: "X-API-Quota-Used"),
            let leftString = response.value(forHTTPHeaderField: "X-API-Quota-Left"),
            let used = Double(usedString),
            let left = Double(leftString)
        else { return nil }
        return SpoonacularQuota(used: used, left: left)
    }
}
