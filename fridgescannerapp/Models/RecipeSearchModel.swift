//
//  RecipeSearchModel.swift
//  fridgescannerapp
//
//  The signed-in household's fridge, recipe search, and recipe details.
//  Created once per sign-in and shared with every screen through the
//  environment. Falls back to demo data when the API quota runs out or the
//  device is offline.
//

import Foundation
import Observation
import SwiftData

struct RecipeSection: Identifiable {
    let title: String
    let recipes: [RecipeMatch]

    var id: String { title }
}

/// Fridge items that were just removed, kept so the Undo banner can put
/// them back: one swiped item, or everything a cooked recipe used.
struct FridgeRemoval: Identifiable {
    struct Item {
        let name: String
        let expirationDate: Date?
        let dateAdded: Date
        let addedBy: User?
    }

    let id = UUID()
    let message: String
    let items: [Item]
}

@MainActor
@Observable
final class RecipeSearchModel {
    var newIngredientText = ""
    private(set) var suggestions: [IngredientSuggestion] = []
    private(set) var results: [RecipeMatch] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    /// Shown under the ingredient field, e.g. "Eggs is already in the fridge."
    private(set) var entryMessage: String?
    /// The last removal, while its Undo banner is showing.
    private(set) var recentlyRemoved: FridgeRemoval?
    /// True when the last search failed for lack of a connection, so demo recipes are showing.
    private(set) var isShowingOfflineResults = false

    let account: Account
    let household: Household
    let preferences: MealPreferences

    private var provider: RecipeProvider
    private let modelContext: ModelContext
    // Autocomplete and details are cached so repeating them doesn't spend API quota.
    private var suggestionCache: [String: [IngredientSuggestion]] = [:]
    private var detailsCache: [Int: RecipeDetails] = [:]
    private var suggestionTask: Task<Void, Never>?

    /// `provider` is only passed in by tests, to use the demo recipes and spend no API quota.
    init(account: Account, household: Household, context: ModelContext, provider: RecipeProvider? = nil) {
        self.account = account
        self.household = household
        self.modelContext = context
        self.provider = provider ?? RecipeProvider.makeDefault()

        if let existing = household.preferences {
            self.preferences = existing
        } else {
            let created = MealPreferences()
            household.attachPreferences(created, in: context)
            self.preferences = created
        }
    }

    /// True when results come from the bundled demo recipes.
    var isUsingDemoData: Bool { provider.isDemoData }

    // MARK: - Fridge

    /// Oldest first, so the list doesn't jump around as items are added.
    var items: [FridgeItem] {
        household.items.sorted { $0.dateAdded < $1.dateAdded }
    }

    var ingredients: [String] {
        // Functional: map turns model objects into the names the API needs
        items.map(\.name)
    }

    func addIngredient(expirationDate: Date? = nil) {
        let name = normalizedIngredientName(newIngredientText)
        guard !name.isEmpty else { return }
        // Error prevention: duplicates get a message instead of being ignored.
        guard !ingredients.contains(name) else {
            entryMessage = "\(name.capitalized) is already in the fridge."
            return
        }

        household.addItem(FridgeItem(name: name, expirationDate: expirationDate), addedBy: account.user, in: modelContext)
        save()
        newIngredientText = ""
        entryMessage = nil
        suggestions = []
        suggestionTask?.cancel()
    }

    func selectSuggestion(_ suggestion: IngredientSuggestion, expirationDate: Date? = nil) {
        newIngredientText = suggestion.name
        addIngredient(expirationDate: expirationDate)
    }

    func clearEntryMessage() {
        entryMessage = nil
    }

    func removeItems(at offsets: IndexSet) {
        let removed = offsets.map { items[$0] }
        let message = removed.count == 1 ? "Removed \(removed[0].name)" : "Removed \(pluralize("item", count: removed.count))"
        remove(removed, message: message)
    }

    /// Mark as Cooked: removes the fridge items the recipe used.
    func removeAfterCooking(_ recipe: RecipeMatch, details: RecipeDetails?) {
        let names = ingredientNames(of: recipe, details: details)
        let used = items.filter { item in names.contains { ingredientNamesMatch($0, item.name) } }
        remove(used, message: "Cooked. Removed \(pluralize("item", count: used.count))")
    }

    /// Removes the items as one group, so a single Undo restores all of them.
    private func remove(_ removedItems: [FridgeItem], message: String) {
        guard !removedItems.isEmpty else { return }
        let copies = removedItems.map {
            FridgeRemoval.Item(name: $0.name, expirationDate: $0.expirationDate, dateAdded: $0.dateAdded, addedBy: $0.addedBy)
        }
        recentlyRemoved = FridgeRemoval(message: message, items: copies)
        removedItems.forEach { household.removeItem($0, in: modelContext) }
        save()
    }

    /// Puts the last removed items back, with their original dates and who added them.
    func undoRemoval() {
        guard let removal = recentlyRemoved else { return }
        for copy in removal.items {
            let item = FridgeItem(name: copy.name, expirationDate: copy.expirationDate, dateAdded: copy.dateAdded)
            household.addItem(item, addedBy: copy.addedBy, in: modelContext)
        }
        save()
        recentlyRemoved = nil
    }

    func dismissUndo(for id: UUID) {
        if recentlyRemoved?.id == id {
            recentlyRemoved = nil
        }
    }

    // MARK: - Autocomplete

    // Waits until typing pauses, so a fast typist doesn't send a request per keystroke.
    func scheduleSuggestionsUpdate() {
        suggestionTask?.cancel()
        let query = newIngredientText
        suggestionTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let results = await autocomplete(query)
            guard !Task.isCancelled else { return }
            suggestions = results
        }
    }

    // Also used by the Preferences screen's ingredient lists.
    func autocomplete(_ query: String) async -> [IngredientSuggestion] {
        let key = normalizedIngredientName(query)
        guard key.count >= 2 else { return [] }
        if let cached = suggestionCache[key] {
            return cached
        }
        let results = (try? await withDemoFallback { try await self.provider.autocompleteIngredients(matching: key) }) ?? []
        suggestionCache[key] = results
        return results
    }

    // MARK: - Searching

    // Excluded ingredients are left out even when they're in the fridge.
    private var searchIngredients: [String] {
        ingredients.filter { !preferences.excluded.contains($0) }
    }

    var canSearch: Bool {
        !searchIngredients.isEmpty && !isLoading
    }

    func search() async {
        let fridge = searchIngredients
        guard !fridge.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        isShowingOfflineResults = false
        defer { isLoading = false }

        do {
            results = try await withDemoFallback {
                try await self.provider.searchRecipes(including: fridge, preferences: self.preferences)
            }
        } catch let error where isOfflineError(error) {
            // Offline mode: search the bundled demo recipes instead.
            results = (try? await MockRecipeProvider().searchRecipes(including: fridge, preferences: preferences)) ?? []
            isShowingOfflineResults = true
        } catch {
            errorMessage = error.localizedDescription
            results = []
        }
    }

    /// Details for one recipe, cached so going back and forth costs nothing.
    /// Offline, the demo copy is used if there is one.
    func recipeDetails(id: Int) async throws -> RecipeDetails {
        if let cached = detailsCache[id] {
            return cached
        }
        do {
            let details = try await withDemoFallback { try await self.provider.recipeDetails(id: id) }
            detailsCache[id] = details
            return details
        } catch let error where isOfflineError(error) {
            guard let demo = try? await MockRecipeProvider().recipeDetails(id: id) else { throw RecipeError.offline }
            return demo
        }
    }

    /// Runs a request, and if the daily quota is used up, switches to the demo
    /// data and runs it once more. The closure reads `provider` again, so the
    /// second attempt uses the demo data.
    private func withDemoFallback<Result>(_ request: () async throws -> Result) async throws -> Result {
        do {
            return try await request()
        } catch RecipeError.quotaExceeded where !provider.isDemoData {
            provider = MockRecipeProvider()
            return try await request()
        }
    }

    private func isOfflineError(_ error: Error) -> Bool {
        let offlineCodes: [URLError.Code] = [.notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .timedOut]
        return (error as? URLError).map { offlineCodes.contains($0.code) } ?? false
    }

    // Must-include and max-missing are applied here rather than in the request, so
    // changing them doesn't cost another search.
    var sections: [RecipeSection] {
        let maxMissing = preferences.maxMissing
        // Functional: filter narrows the results, then each section filters by missing count
        let visible = results.filter {
            $0.missedIngredientCount <= maxMissing && includesRequiredIngredients($0)
        }
        let sections = [
            RecipeSection(title: "Ready to Make", recipes: visible.filter { $0.missedIngredientCount == 0 }),
            RecipeSection(title: "Missing 1 Ingredient", recipes: visible.filter { $0.missedIngredientCount == 1 }),
            RecipeSection(title: "Missing 2 or More", recipes: visible.filter { $0.missedIngredientCount >= 2 })
        ]
        return sections.filter { !$0.recipes.isEmpty }
    }

    private func includesRequiredIngredients(_ recipe: RecipeMatch) -> Bool {
        let names = (recipe.usedIngredients + recipe.missedIngredients).map { $0.name.lowercased() }
        // Substring match, so "chicken" also matches "chicken breast".
        return preferences.mustInclude.allSatisfy { required in
            names.contains { $0.contains(required) }
        }
    }

    // MARK: - Comparing a recipe with the fridge

    /// Every ingredient name in the recipe. Search results list them; a saved
    /// favorite doesn't, so its details are used instead.
    private func ingredientNames(of recipe: RecipeMatch, details: RecipeDetails?) -> [String] {
        let fromSearch = (recipe.usedIngredients + recipe.missedIngredients).map(\.name)
        if !fromSearch.isEmpty { return fromSearch }
        // Functional: compactMap skips ingredients with no plain name
        return details?.extendedIngredients?.compactMap(\.name) ?? []
    }

    /// What the recipe needs that the fridge doesn't have. Pantry staples
    /// like salt and oil aren't counted.
    func missingIngredients(for recipe: RecipeMatch, details: RecipeDetails?) -> [String] {
        let names = ingredientNames(of: recipe, details: details).map(normalizedIngredientName)
        let missing = names.filter { name in
            !isPantryStaple(name) && !ingredients.contains { ingredientNamesMatch($0, name) }
        }
        return Array(Set(missing)).sorted()
    }

    func save() {
        try? modelContext.save()
    }
}
