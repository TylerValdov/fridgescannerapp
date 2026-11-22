//
//  RecipeAPI.swift
//  fridgescannerapp
//
//  Where recipes come from. RecipeSearchModel only talks to the base class,
//  `RecipeProvider`, so it can switch between the two subclasses freely:
//    - SpoonacularProvider: the live Spoonacular API (needs a key in Secrets.swift)
//    - MockRecipeProvider:  24 real recipes bundled in MockData/MockRecipes.json,
//      used with no key, after the daily quota runs out, or offline
//

import Foundation

// MARK: - Recipe data

// Codable (not just Decodable) so a recipe can also be built in code.
struct IngredientRef: Codable, Hashable {
    let id: Int
    let name: String
    let image: String?
}

struct IngredientSuggestion: Decodable, Identifiable, Hashable {
    let name: String
    var id: String { name }
}

/// One search result: a recipe and how well it matches the fridge.
struct RecipeMatch: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let image: String?          // Some recipes have no photo
    let usedIngredientCount: Int
    let missedIngredientCount: Int
    let missedIngredients: [IngredientRef]
    let usedIngredients: [IngredientRef]
}

/// One page of /recipes/complexSearch results.
private struct RecipeSearchPage: Decodable {
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

    // Spoonacular's diet flags, used for personal dietary warnings
    let vegetarian: Bool?
    let vegan: Bool?
    let glutenFree: Bool?
    let dairyFree: Bool?
}

struct RecipeDetailIngredient: Decodable, Identifiable {
    let name: String?           // Plain name, e.g. "eggs"
    let original: String        // As written in the recipe, e.g. "2 large eggs"

    var id: String { original }
}

enum RecipeError: LocalizedError {
    case requestFailed(statusCode: Int)
    case quotaExceeded
    case notInDemoData
    case offline

    var errorDescription: String? {
        switch self {
        case .requestFailed(let statusCode): "Spoonacular request failed (HTTP \(statusCode))."
        case .quotaExceeded: "Daily Spoonacular quota used up. Try again tomorrow."
        case .notInDemoData: "This recipe isn't in the demo data. Add a Spoonacular key to see it."
        case .offline: "You're offline. Connect to the internet to see this recipe."
        }
    }
}

// MARK: - Base class

// OOP: base class. The two subclasses override the three requests.
class RecipeProvider {
    /// True for the bundled demo recipes, so the app can label them.
    var isDemoData: Bool { false }

    /// Spoonacular when a key is set up in Secrets.swift, otherwise demo data.
    static func makeDefault() -> RecipeProvider {
        if let key = AppSecrets.spoonacularAPIKey {
            return SpoonacularProvider(apiKey: key)
        }
        return MockRecipeProvider()
    }

    func searchRecipes(including ingredients: [String], preferences: MealPreferences) async throws -> [RecipeMatch] {
        preconditionFailure("Subclasses must override searchRecipes")
    }

    func autocompleteIngredients(matching query: String) async throws -> [IngredientSuggestion] {
        preconditionFailure("Subclasses must override autocompleteIngredients")
    }

    func recipeDetails(id: Int) async throws -> RecipeDetails {
        preconditionFailure("Subclasses must override recipeDetails")
    }
}

// MARK: - Spoonacular

// OOP: subclass that makes real network requests. The free tier allows
// 50 points a day; a 20-result search costs about 1.7.
final class SpoonacularProvider: RecipeProvider {
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // complexSearch rather than findByIngredients, because only it can filter by
    // diet, intolerances and excluded ingredients.
    override func searchRecipes(including ingredients: [String], preferences: MealPreferences) async throws -> [RecipeMatch] {
        var query = [
            "includeIngredients": ingredients.joined(separator: ","),
            "sort": "min-missing-ingredients",
            "fillIngredients": "true",      // Adds the used/missed ingredient lists
            "ignorePantry": "true",         // Don't count salt, water, etc. as missing
            "number": "20",
            "excludeIngredients": preferences.excluded.joined(separator: ","),
            "intolerances": preferences.intolerancesRaw.joined(separator: ",")
        ]
        query["diet"] = preferences.diet.apiValue
        return try await fetch(RecipeSearchPage.self, path: "recipes/complexSearch", query: query).results
    }

    override func autocompleteIngredients(matching query: String) async throws -> [IngredientSuggestion] {
        try await fetch([IngredientSuggestion].self, path: "food/ingredients/autocomplete", query: ["query": query, "number": "5"])
    }

    override func recipeDetails(id: Int) async throws -> RecipeDetails {
        try await fetch(RecipeDetails.self, path: "recipes/\(id)/information", query: [:])
    }

    /// Sends a GET request, checks the status code, and decodes the JSON.
    private func fetch<Response: Decodable>(_ type: Response.Type, path: String, query: [String: String]) async throws -> Response {
        var components = URLComponents(string: "https://api.spoonacular.com/\(path)")!
        // Functional: drop empty parameters, then turn the rest into query items
        components.queryItems = query.filter { !$0.value.isEmpty }.map { URLQueryItem(name: $0.key, value: $0.value) }
            + [URLQueryItem(name: "apiKey", value: apiKey)]

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        if status == 402 { throw RecipeError.quotaExceeded }
        guard (200..<300).contains(status) else { throw RecipeError.requestFailed(statusCode: status) }
        return try JSONDecoder().decode(type, from: data)
    }
}

// MARK: - Demo data

// OOP: subclass that answers from the bundled JSON, with no network.
final class MockRecipeProvider: RecipeProvider {
    private let recipes: [MockRecipe] = {
        guard
            let url = AppResources.bundle.url(forResource: "MockRecipes", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let recipes = try? JSONDecoder().decode([MockRecipe].self, from: data)
        else {
            assertionFailure("MockRecipes.json is missing from the app bundle")
            return []
        }
        return recipes
    }()

    override var isDemoData: Bool { true }

    override func searchRecipes(including ingredients: [String], preferences: MealPreferences) async throws -> [RecipeMatch] {
        // Functional: filter, map and sort the demo recipes, the way
        // complexSearch filters and ranks the real catalog.
        recipes
            .filter { $0.fits(preferences) }
            .map { $0.match(against: ingredients) }
            .filter { $0.usedIngredientCount > 0 }
            .sorted { $0.missedIngredientCount < $1.missedIngredientCount }
    }

    override func autocompleteIngredients(matching query: String) async throws -> [IngredientSuggestion] {
        let query = normalizedIngredientName(query)
        return MockRecipeProvider.commonIngredients
            .filter { $0.hasPrefix(query) }
            .prefix(5)
            .map { IngredientSuggestion(name: $0) }
    }

    override func recipeDetails(id: Int) async throws -> RecipeDetails {
        guard let recipe = recipes.first(where: { $0.id == id }) else {
            throw RecipeError.notInDemoData
        }
        return recipe.details
    }

    /// Also used by the scanner to simplify product names.
    static let commonIngredients = [
        "apple", "avocado", "bacon", "banana", "basil", "beef", "bell pepper", "black beans",
        "bread", "broccoli", "butter", "cabbage", "canned tomatoes", "carrots", "cauliflower",
        "celery", "cheddar cheese", "chicken breast", "chicken thighs", "chickpeas", "cilantro",
        "corn", "cream cheese", "cucumber", "eggs", "garlic", "ginger", "green onions",
        "ground beef", "ground turkey", "ham", "heavy cream", "honey", "kale", "lemons", "lettuce",
        "limes", "milk", "mozzarella", "mushrooms", "onion", "parmesan cheese", "pasta", "penne",
        "potatoes", "rice", "salmon", "sausage", "shrimp", "spinach", "sweet potatoes", "tofu",
        "tomatoes", "tortillas", "yogurt", "zucchini"
    ]
}

/// One recipe in MockRecipes.json (a trimmed Spoonacular /information response).
private struct MockRecipe: Decodable {
    struct Ingredient: Decodable {
        let id: Int
        let name: String
        let original: String
        let image: String?
    }

    let id: Int
    let title: String
    let image: String?
    let readyInMinutes: Int?
    let servings: Int?
    let summary: String?
    let instructions: String?
    let sourceUrl: String?
    let diets: [String]
    let vegetarian: Bool
    let vegan: Bool
    let glutenFree: Bool
    let dairyFree: Bool
    let extendedIngredients: [Ingredient]

    var details: RecipeDetails {
        RecipeDetails(
            id: id, title: title, image: image,
            readyInMinutes: readyInMinutes, servings: servings,
            summary: summary, instructions: instructions, sourceUrl: sourceUrl,
            extendedIngredients: extendedIngredients.map { RecipeDetailIngredient(name: $0.name, original: $0.original) },
            vegetarian: vegetarian, vegan: vegan, glutenFree: glutenFree, dairyFree: dairyFree
        )
    }

    /// Splits the recipe's ingredients into what the fridge has and what's missing.
    func match(against fridge: [String]) -> RecipeMatch {
        let needed = extendedIngredients.filter { !isPantryStaple($0.name) }
        let inFridge: (Ingredient) -> Bool = { ingredient in
            fridge.contains { ingredientNamesMatch($0, ingredient.name) }
        }
        let toRef: (Ingredient) -> IngredientRef = { IngredientRef(id: $0.id, name: $0.name, image: $0.image) }
        let used = needed.filter(inFridge)
        let missed = needed.filter { !inFridge($0) }

        return RecipeMatch(
            id: id, title: title, image: image,
            usedIngredientCount: used.count, missedIngredientCount: missed.count,
            missedIngredients: missed.map(toRef), usedIngredients: used.map(toRef)
        )
    }

    /// Approximates Spoonacular's diet, intolerance and exclusion rules with the flags in the data.
    func fits(_ preferences: MealPreferences) -> Bool {
        let names = extendedIngredients.map(\.name)
        let uses: (String) -> Bool = { word in names.contains { $0.contains(word) } }

        let fitsDiet: Bool = switch preferences.diet {
        case .noPreference: true
        case .glutenFree: glutenFree
        case .vegetarian, .lactoVegetarian, .ovoVegetarian: vegetarian
        case .vegan: vegan
        case .pescetarian: vegetarian || diets.contains("pescatarian")
        case .lowFODMAP: diets.contains("fodmap friendly")
        case .whole30: diets.contains("whole 30")
        default: diets.contains { $0.contains(preferences.diet.rawValue) }   // ketogenic, paleo, primal
        }
        let avoidsIntolerances = preferences.intolerancesRaw.allSatisfy { intolerance in
            switch intolerance {
            case "dairy": dairyFree
            case "gluten", "wheat", "grain": glutenFree
            case "seafood", "shellfish": !["fish", "salmon", "shrimp", "crab"].contains(where: uses)
            default: !uses(intolerance)
            }
        }
        return fitsDiet && avoidsIntolerances && !preferences.excluded.contains(where: uses)
    }
}
