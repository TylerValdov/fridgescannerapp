//
//  RecipeSearchModel.swift
//  fridgescannerapp
//
//  The signed-in household's fridge, recipe search, and recipe details.
//  Created once per sign-in and shared with every screen through the
//  environment. Falls back to demo data when the API quota runs out.
//

import Foundation
import Observation
import SwiftData
import SwiftUI

struct RecipeSection: Identifiable {
    let title: String
    let recipes: [RecipeMatch]

    var id: String { title }
}

/// A fridge item that was just removed, kept so the Undo banner can restore it.
struct RemovedFridgeItem: Identifiable {
    let id = UUID()
    let name: String
    let expirationDate: Date?
    let dateAdded: Date
    let addedBy: User?
}

@MainActor
@Observable
final class RecipeSearchModel {
    var newIngredientText: String = ""
    private(set) var suggestions: [IngredientSuggestion] = []
    private(set) var results: [RecipeMatch] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var quotaLeft: Double?
    /// Shown under the ingredient field, e.g. "Eggs is already in the fridge."
    private(set) var entryMessage: String?
    /// The last removed item, while its Undo banner is showing.
    private(set) var recentlyRemoved: RemovedFridgeItem?

    let account: Account
    let household: Household
    let preferences: MealPreferences

    private var provider: RecipeProvider
    private let modelContext: ModelContext
    // Keyed by the fridge contents plus the preferences sent to the API, so re-running
    // an identical search doesn't spend quota twice.
    private var cache: [String: [RecipeMatch]] = [:]
    private var suggestionCache: [String: [IngredientSuggestion]] = [:]
    private var detailsCache: [Int: RecipeDetails] = [:]
    private var suggestionTask: Task<Void, Never>?
    // The key `results` came from, to tell when they're out of date.
    private var lastSearchKey: String?

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
            try? context.save()
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

    func remove(_ item: FridgeItem) {
        recentlyRemoved = RemovedFridgeItem(
            name: item.name,
            expirationDate: item.expirationDate,
            dateAdded: item.dateAdded,
            addedBy: item.addedBy
        )
        household.removeItem(item, in: modelContext)
        save()
    }

    func removeItems(at offsets: IndexSet) {
        let current = items
        offsets.map { current[$0] }.forEach(remove)
    }

    /// Puts the last removed item back, with its original date and who added it.
    func undoRemoval() {
        guard let removed = recentlyRemoved else { return }
        let item = FridgeItem(name: removed.name, expirationDate: removed.expirationDate, dateAdded: removed.dateAdded)
        household.addItem(item, addedBy: removed.addedBy, in: modelContext)
        save()
        recentlyRemoved = nil
    }

    func dismissUndo(for id: UUID) {
        if recentlyRemoved?.id == id {
            recentlyRemoved = nil
        }
    }

    // MARK: - Autocomplete

    // Debounced so a fast typist doesn't fire an autocomplete request per keystroke.
    func scheduleSuggestionsUpdate() {
        suggestionTask?.cancel()
        let query = newIngredientText.trimmingCharacters(in: .whitespacesAndNewlines)
        suggestionTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let results = await autocomplete(query)
            guard !Task.isCancelled else { return }
            suggestions = results
        }
    }

    // Shared with the Preferences screen's ingredient lists, so they use the same cache.
    func autocomplete(_ query: String) async -> [IngredientSuggestion] {
        guard query.count >= 2 else { return [] }

        let key = query.lowercased()
        if let cached = suggestionCache[key] {
            return cached
        }

        do {
            let results = try await withDemoFallback {
                try await self.provider.autocompleteIngredients(matching: query, number: 5)
            }
            suggestionCache[key] = results
            return results
        } catch {
            return []
        }
    }

    // MARK: - Preferences

    func savePreferences() {
        save()
    }

    func resetPreferences() {
        preferences.reset()
        save()
    }

    // MARK: - Searching

    // Excluded ingredients are left out even when they're in the fridge.
    private var searchIngredients: [String] {
        let excluded = Set(preferences.excluded)
        return ingredients.filter { !excluded.contains($0) }
    }

    private var searchKey: String {
        searchIngredients.sorted().joined(separator: ",") + "|" + preferences.requestKey
    }

    var canSearch: Bool {
        !searchIngredients.isEmpty && !isLoading && (quotaLeft ?? 1) > 0
    }

    // True when the fridge or the API-side preferences changed since the last search.
    var resultsAreOutdated: Bool {
        guard let lastSearchKey else { return false }
        return lastSearchKey != searchKey
    }

    func search() async {
        let fridge = searchIngredients
        guard !fridge.isEmpty else { return }

        let key = searchKey
        if let cached = cache[key] {
            results = cached
            lastSearchKey = key
            errorMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await withDemoFallback {
                try await self.provider.searchRecipes(
                    including: fridge,
                    excluding: self.preferences.excluded,
                    diet: self.preferences.diet.apiValue,
                    intolerances: self.preferences.intolerancesRaw,
                    number: 20
                )
            }
            results = response.recipes
            cache[key] = response.recipes
            lastSearchKey = key
            quotaLeft = response.quota?.left
        } catch {
            errorMessage = error.localizedDescription
            results = []
            lastSearchKey = nil
        }
    }

    /// Details for one recipe, cached so going back and forth costs nothing.
    func recipeDetails(id: Int) async throws -> RecipeDetails {
        if let cached = detailsCache[id] {
            return cached
        }
        let details = try await withDemoFallback {
            try await self.provider.recipeDetails(id: id)
        }
        detailsCache[id] = details
        return details
    }

    /// Runs a request, and if the daily quota is used up, switches to the demo
    /// data and runs it once more. The closure reads `provider` again, so the
    /// second attempt uses the new one.
    private func withDemoFallback<Result>(_ request: () async throws -> Result) async throws -> Result {
        do {
            return try await request()
        } catch SpoonacularError.quotaExceeded where !provider.isDemoData {
            provider = MockRecipeProvider()
            cache.removeAll()
            quotaLeft = nil
            return try await request()
        }
    }

    // Must-include and max-missing are applied here rather than in the request, so
    // changing them doesn't cost another search. (Sending must-include ingredients as
    // includeIngredients would also make the API treat them as already in the fridge.)
    var sections: [RecipeSection] {
        let maxMissing = preferences.maxMissing
        // Functional: filter narrows the results, then each section filters by missing count
        let visible = results.filter {
            $0.missedIngredientCount <= maxMissing && includesRequiredIngredients($0)
        }

        var sections = [
            RecipeSection(title: "Ready to Make", recipes: visible.filter { $0.missedIngredientCount == 0 }),
            RecipeSection(title: "Missing 1 Ingredient", recipes: visible.filter { $0.missedIngredientCount == 1 })
        ]
        if maxMissing >= 2 {
            let title = maxMissing == 2 ? "Missing 2 Ingredients" : "Missing 2–\(maxMissing) Ingredients"
            sections.append(RecipeSection(title: title, recipes: visible.filter { $0.missedIngredientCount >= 2 }))
        }
        return sections.filter { !$0.recipes.isEmpty }
    }

    private func includesRequiredIngredients(_ recipe: RecipeMatch) -> Bool {
        let names = (recipe.usedIngredients + recipe.missedIngredients).map { $0.name.lowercased() }
        // Substring match, so "chicken" also matches "chicken breast".
        return preferences.mustInclude.allSatisfy { required in
            names.contains { $0.contains(required) }
        }
    }

    private func save() {
        try? modelContext.save()
    }
}
