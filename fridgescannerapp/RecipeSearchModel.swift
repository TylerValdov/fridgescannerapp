//
//  RecipeSearchModel.swift
//  fridgescannerapp
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

@MainActor
@Observable
final class RecipeSearchModel {
    var newIngredientText: String = ""
    private(set) var ingredients: [String] = []
    private(set) var suggestions: [IngredientSuggestion] = []
    private(set) var results: [RecipeMatch] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var quotaLeft: Double?
    let preferences: MealPreferences

    let service: SpoonacularService
    private let modelContext: ModelContext
    // Keyed by the fridge contents plus the preferences sent to the API, so re-running
    // an identical search (e.g. after removing then re-adding the same ingredient) doesn't spend quota twice.
    private var cache: [String: [RecipeMatch]] = [:]
    private var suggestionCache: [String: [IngredientSuggestion]] = [:]
    private var suggestionTask: Task<Void, Never>?
    // The key `results` came from, to tell when they're out of date.
    private var lastSearchKey: String?

    init(context: ModelContext, service: SpoonacularService? = nil) {
        self.modelContext = context
        self.service = service ?? SpoonacularService()
        self.preferences = Self.loadOrCreatePreferences(in: context)
        loadPersistedIngredients()
    }

    private static func loadOrCreatePreferences(in context: ModelContext) -> MealPreferences {
        if let existing = (try? context.fetch(FetchDescriptor<MealPreferences>()))?.first {
            return existing
        }
        let created = MealPreferences()
        context.insert(created)
        try? context.save()
        return created
    }

    private func loadPersistedIngredients() {
        let descriptor = FetchDescriptor<PersistedIngredient>(sortBy: [SortDescriptor(\.dateAdded)])
        let rows = (try? modelContext.fetch(descriptor)) ?? []
        ingredients = rows.map(\.name)
    }

    func savePreferences() {
        try? modelContext.save()
    }

    func addIngredient() {
        let trimmed = newIngredientText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !ingredients.contains(trimmed) else { return }
        ingredients.append(trimmed)
        newIngredientText = ""
        suggestions = []
        suggestionTask?.cancel()

        modelContext.insert(PersistedIngredient(name: trimmed))
        try? modelContext.save()
    }

    func selectSuggestion(_ suggestion: IngredientSuggestion) {
        newIngredientText = suggestion.name
        addIngredient()
    }

    // Debounced so a fast typist doesn't fire an autocomplete request per keystroke.
    func scheduleSuggestionsUpdate() {
        suggestionTask?.cancel()
        let query = newIngredientText.trimmingCharacters(in: .whitespacesAndNewlines)
        suggestionTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await fetchSuggestions(for: query)
        }
    }

    private func fetchSuggestions(for query: String) async {
        let results = await autocomplete(query)
        guard !Task.isCancelled else { return }
        suggestions = results
    }

    // Shared with the Preferences screen's ingredient lists, so they use the same cache.
    func autocomplete(_ query: String) async -> [IngredientSuggestion] {
        guard query.count >= 2 else { return [] }

        let key = query.lowercased()
        if let cached = suggestionCache[key] {
            return cached
        }

        do {
            let results = try await service.autocompleteIngredients(matching: query)
            suggestionCache[key] = results
            return results
        } catch {
            return []
        }
    }

    func removeIngredient(_ ingredient: String) {
        ingredients.removeAll { $0 == ingredient }
        deletePersistedIngredient(named: ingredient)
    }

    func removeIngredients(at offsets: IndexSet) {
        let namesToRemove = offsets.map { ingredients[$0] }
        ingredients.remove(atOffsets: offsets)
        namesToRemove.forEach(deletePersistedIngredient)
    }

    private func deletePersistedIngredient(named name: String) {
        let descriptor = FetchDescriptor<PersistedIngredient>(
            predicate: #Predicate { $0.name == name }
        )
        guard let rows = try? modelContext.fetch(descriptor) else { return }
        rows.forEach(modelContext.delete)
        try? modelContext.save()
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
            let response = try await service.searchRecipes(
                including: fridge,
                excluding: preferences.excluded,
                diet: preferences.diet.apiValue,
                intolerances: preferences.intolerancesRaw
            )
            results = response.recipes
            cache[key] = response.recipes
            lastSearchKey = key
            if let quota = response.quota {
                quotaLeft = quota.left
            }
        } catch {
            errorMessage = error.localizedDescription
            results = []
            lastSearchKey = nil
        }
    }

    // Must-include and max-missing are applied here rather than in the request, so
    // changing them doesn't cost another search. (Sending must-include ingredients as
    // includeIngredients would also make the API treat them as already in the fridge.)
    var sections: [RecipeSection] {
        let maxMissing = preferences.maxMissing
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
}
