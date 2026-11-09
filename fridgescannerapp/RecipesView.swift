//
//  RecipesView.swift
//  fridgescannerapp
//

import SwiftUI

// Recipes that can be made from the fridge, grouped by how many ingredients are missing.
// Searches only run from the button or pull-to-refresh, since each one costs quota.
struct RecipesView: View {
    let model: RecipeSearchModel
    // Switches to the Preferences tab.
    var onEditPreferences: () -> Void = {}

    @Environment(RecipeHistoryStore.self) private var history

    var body: some View {
        VStack(spacing: 12) {
            ingredientsSummaryRow
            preferencesSummaryRow
            searchButton
            if let quotaLeft = model.quotaLeft {
                Text("Spoonacular points left today: \(Int(quotaLeft))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if model.resultsAreOutdated {
                Text("Your fridge or preferences changed. Tap Find Recipes to update.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            resultsSection
        }
        .padding()
        .navigationTitle("Recipes")
    }

    private var ingredientsSummaryRow: some View {
        HStack {
            Image(systemName: "carrot")
            Text(
                model.ingredients.isEmpty
                    ? "No ingredients added"
                    : "\(model.ingredients.count) ingredient\(model.ingredients.count == 1 ? "" : "s") in your fridge"
            )
            Spacer()
        }
        .foregroundStyle(.secondary)
    }

    private var preferencesSummaryRow: some View {
        Button(action: onEditPreferences) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                Text(model.preferences.summary ?? "No meal preferences set")
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    private var searchButton: some View {
        Button {
            Task { await model.search() }
        } label: {
            if model.isLoading {
                ProgressView()
            } else {
                Text("Find Recipes")
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(!model.canSearch)
    }

    @ViewBuilder
    private var resultsSection: some View {
        if let errorMessage = model.errorMessage {
            Text(errorMessage)
                .foregroundStyle(.red)
                .font(.footnote)
        }

        if model.sections.isEmpty && !model.isLoading {
            if model.results.isEmpty {
                ContentUnavailableView(
                    "No Recipes Yet",
                    systemImage: "fork.knife",
                    description: Text("Add ingredients and tap Find Recipes to get started.")
                )
            } else {
                // Results came back, but must-include or max-missing hid all of them.
                ContentUnavailableView(
                    "No Matches",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text(
                        "None of the \(model.results.count) recipes found fit your preferences. Try allowing more missing ingredients or removing a must-include ingredient."
                    )
                )
            }
        } else {
            List {
                ForEach(model.sections) { section in
                    Section(section.title) {
                        ForEach(section.recipes) { recipe in
                            NavigationLink {
                                RecipeDetailView(recipe: recipe)
                            } label: {
                                RecipeRow(recipe: recipe, isFavorite: history.isLiked(recipe))
                            }
                            .swipeActions {
                                favoriteButton(for: recipe)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .refreshable {
                await model.search()
            }
        }
    }

    private func favoriteButton(for recipe: RecipeMatch) -> some View {
        let isFavorite = history.isLiked(recipe)
        return Button {
            history.toggleLike(recipe)
        } label: {
            Label(
                isFavorite ? "Unfavorite" : "Favorite",
                systemImage: isFavorite ? "heart.slash" : "heart"
            )
        }
        .tint(.pink)
    }
}

private struct RecipeRow: View {
    let recipe: RecipeMatch
    let isFavorite: Bool

    var body: some View {
        HStack {
            AsyncImage(url: recipe.image.flatMap { URL(string: $0) }) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.secondary.opacity(0.2)
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.title)
                    .font(.headline)
                Text(ingredientsText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if isFavorite {
                Spacer()
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink)
            }
        }
    }

    private var ingredientsText: String {
        let uses = "Uses \(recipe.usedIngredientCount)"
        guard !recipe.missedIngredients.isEmpty else {
            return uses + " • You have everything"
        }
        return uses + " • Missing: " + recipe.missedIngredients.map(\.name).joined(separator: ", ")
    }
}
