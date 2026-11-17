//
//  MockRecipeProvider.swift
//  fridgescannerapp
//
//  Demo recipe data that works with no network or API key. Searches 24
//  real Spoonacular recipes saved in MockData/MockRecipes.json, matching them
//  against the fridge on the device. Used when there's no key in
//  Secrets.plist, or after the daily quota runs out.
//

import Foundation

// OOP: subclass of RecipeProvider that answers from bundled JSON.
final class MockRecipeProvider: RecipeProvider {
    private let recipes: [MockRecipe]

    init() {
        recipes = MockRecipeProvider.loadRecipes()
        super.init()
    }

    override var isDemoData: Bool { true }

    override func searchRecipes(
        including ingredients: [String],
        excluding excluded: [String],
        diet: String?,
        intolerances: [String],
        number: Int
    ) async throws -> SpoonacularResult {
        // Functional: filter, map and sort the sample recipes, the same way
        // complexSearch filters and ranks the real catalog.
        let matches = recipes
            .filter { $0.fits(diet: diet) && $0.avoids(intolerances) && !$0.uses(anyOf: excluded) }
            .map { $0.match(against: ingredients) }
            .filter { $0.usedIngredientCount > 0 }
            .sorted {
                ($0.missedIngredientCount, -$0.usedIngredientCount) < ($1.missedIngredientCount, -$1.usedIngredientCount)
            }
        return SpoonacularResult(recipes: Array(matches.prefix(number)), quota: nil)
    }

    override func autocompleteIngredients(matching query: String, number: Int) async throws -> [IngredientSuggestion] {
        let query = normalizedIngredientName(query)
        // Functional: names that start with the text come before names that only contain it
        let starts = MockRecipeProvider.commonIngredients.filter { $0.hasPrefix(query) }
        let contains = MockRecipeProvider.commonIngredients.filter { !$0.hasPrefix(query) && $0.contains(query) }
        return (starts + contains).prefix(number).map { IngredientSuggestion(name: $0) }
    }

    override func recipeDetails(id: Int) async throws -> RecipeDetails {
        guard let recipe = recipes.first(where: { $0.id == id }) else {
            throw SpoonacularError.notInDemoData
        }
        return recipe.details
    }

    /// A demo recipe as a search result for the given fridge (used by SampleData).
    func match(forRecipeID id: Int, against ingredients: [String]) -> RecipeMatch? {
        recipes.first { $0.id == id }?.match(against: ingredients)
    }

    private static func loadRecipes() -> [MockRecipe] {
        guard
            let url = AppResources.bundle.url(forResource: "MockRecipes", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let recipes = try? JSONDecoder().decode([MockRecipe].self, from: data)
        else {
            assertionFailure("MockRecipes.json is missing from the app bundle")
            return []
        }
        return recipes
    }

    private static let commonIngredients = [
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

        var ref: IngredientRef { IngredientRef(id: id, name: name, image: image) }
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
            extendedIngredients: extendedIngredients.map { RecipeDetailIngredient(original: $0.original) }
        )
    }

    /// Splits the recipe's ingredients into what the fridge has and what's missing.
    func match(against fridge: [String]) -> RecipeMatch {
        // Functional: filter out pantry staples, then partition by whether the fridge has each one
        let needed = extendedIngredients.filter { !isPantryStaple($0.name) }
        let inFridge: (Ingredient) -> Bool = { ingredient in
            fridge.contains { ingredientNamesMatch($0, ingredient.name) }
        }
        let used = needed.filter(inFridge)
        let missed = needed.filter { !inFridge($0) }

        return RecipeMatch(
            id: id, title: title, image: image,
            usedIngredientCount: used.count,
            missedIngredientCount: missed.count,
            missedIngredients: missed.map(\.ref),
            usedIngredients: used.map(\.ref)
        )
    }

    /// Approximates Spoonacular's diet rules with the flags in its data.
    func fits(diet: String?) -> Bool {
        switch diet {
        case nil: return true
        case "gluten free": return glutenFree
        case "vegetarian", "lacto-vegetarian", "ovo-vegetarian": return vegetarian
        case "vegan": return vegan
        case "pescetarian": return vegetarian || diets.contains("pescatarian")
        case "paleo": return diets.contains("paleolithic")
        case "low fodmap": return diets.contains("fodmap friendly")
        case "whole30": return diets.contains("whole 30")
        case let other?: return diets.contains(other)   // ketogenic, primal
        }
    }

    func avoids(_ intolerances: [String]) -> Bool {
        intolerances.allSatisfy { intolerance in
            switch intolerance {
            case "dairy": return dairyFree
            case "gluten", "wheat", "grain": return glutenFree
            default: return !uses(anyOf: MockRecipe.keywords(for: intolerance))
            }
        }
    }

    func uses(anyOf names: [String]) -> Bool {
        extendedIngredients.contains { ingredient in
            names.contains { ingredientNamesMatch($0, ingredient.name) }
        }
    }

    private static func keywords(for intolerance: String) -> [String] {
        switch intolerance {
        case "egg": ["egg"]
        case "peanut": ["peanut"]
        case "seafood": ["fish", "salmon", "tuna", "cod", "shrimp", "crab"]
        case "shellfish": ["shrimp", "crab", "lobster", "clam", "mussel", "oyster"]
        case "sesame": ["sesame"]
        case "soy": ["soy", "tofu", "edamame"]
        case "sulfite": ["wine"]
        case "tree nut": ["almond", "walnut", "pecan", "cashew", "pistachio", "hazelnut"]
        default: [intolerance]
        }
    }
}
