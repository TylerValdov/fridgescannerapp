//
//  RecipeSearchModel.swift
//  fridgescannerapp
//

import Foundation
import Observation
import SwiftData
import SwiftUI

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

    private let service: SpoonacularService
    private let modelContext: ModelContext
    // Keyed by the sorted ingredient list, so re-running an identical search
    // (e.g. after removing then re-adding the same chip) doesn't spend quota twice.
    private var cache: [String: [RecipeMatch]] = [:]
    private var suggestionCache: [String: [IngredientSuggestion]] = [:]
    private var suggestionTask: Task<Void, Never>?

    init(context: ModelContext, service: SpoonacularService? = nil) {
        self.modelContext = context
        self.service = service ?? SpoonacularService()
        loadPersistedIngredients()
    }

    private func loadPersistedIngredients() {
        let descriptor = FetchDescriptor<PersistedIngredient>(sortBy: [SortDescriptor(\.dateAdded)])
        let rows = (try? modelContext.fetch(descriptor)) ?? []
        ingredients = rows.map(\.name)
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
        guard query.count >= 2 else {
            suggestions = []
            return
        }

        let key = query.lowercased()
        if let cached = suggestionCache[key] {
            suggestions = cached
            return
        }

        do {
            let results = try await service.autocompleteIngredients(matching: query)
            guard !Task.isCancelled else { return }
            suggestionCache[key] = results
            suggestions = results
        } catch {
            suggestions = []
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

    func search() async {
        guard !ingredients.isEmpty else { return }

        let cacheKey = ingredients.sorted().joined(separator: ",")
        if let cached = cache[cacheKey] {
            results = cached
            errorMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await service.findRecipes(byIngredients: ingredients)
            results = response.recipes
            cache[cacheKey] = response.recipes
            if let quota = response.quota {
                quotaLeft = quota.left
            }
        } catch {
            errorMessage = error.localizedDescription
            results = []
        }
    }
}
