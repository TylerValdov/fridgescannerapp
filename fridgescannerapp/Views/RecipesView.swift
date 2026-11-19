//
//  RecipesView.swift
//  fridgescannerapp
//
//  The Recipes tab: what the household can make from its fridge, grouped by
//  how many ingredients are missing. Searches only run from the button or
//  pull-to-refresh, since each one costs API quota.
//

import SwiftUI

struct RecipesView: View {
    /// Switches to the Preferences section (iPad). When nil, Preferences opens as a sheet.
    var onEditPreferences: (() -> Void)?

    @Environment(RecipeSearchModel.self) private var model
    @Environment(SavedRecipeStore.self) private var history
    @State private var isShowingPreferences = false

    var body: some View {
        List {
            Section {
                Label(pluralize("ingredient", count: model.ingredients.count) + " in your fridge", systemImage: "carrot")
                preferencesButton
                Button {
                    Task { await model.search() }
                } label: {
                    if model.isLoading {
                        ProgressView()
                    } else {
                        Text("Find Recipes")
                    }
                }
                .disabled(!model.canSearch)
                statusMessages
            }

            if model.sections.isEmpty && !model.isLoading {
                ContentUnavailableView(
                    model.results.isEmpty ? "No recipes yet" : "No matches",
                    systemImage: "fork.knife",
                    description: Text(model.results.isEmpty
                        ? "Add ingredients to the fridge, then tap Find Recipes."
                        : "None of the recipes found fit your preferences. Try allowing more missing ingredients.")
                )
            }

            ForEach(model.sections) { section in
                Section(section.title) {
                    ForEach(section.recipes) { recipe in
                        NavigationLink {
                            RecipeDetailView(recipe: recipe)
                        } label: {
                            RecipeRow(recipe: recipe, isFavorite: history.isLiked(recipe))
                        }
                        .swipeActions {
                            Button(history.isLiked(recipe) ? "Unfavorite" : "Favorite", systemImage: "heart") {
                                history.toggleLike(recipe)
                            }
                            .tint(.pink)
                        }
                    }
                }
            }
        }
        .navigationTitle("Recipes")
        .refreshable { await model.search() }
        .sheet(isPresented: $isShowingPreferences) {
            NavigationStack {
                PreferencesView()
                    .toolbar {
                        Button("Done") { isShowingPreferences = false }
                    }
            }
        }
    }

    // Golden rule "reduce short-term memory load": the active diet rules are always visible here.
    private var preferencesButton: some View {
        Button {
            if let onEditPreferences {
                onEditPreferences()
            } else {
                isShowingPreferences = true
            }
        } label: {
            Label(model.preferences.summary ?? "No meal preferences set", systemImage: "slider.horizontal.3")
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel("Meal preferences: \(model.preferences.summary ?? "none set")")
    }

    @ViewBuilder
    private var statusMessages: some View {
        if model.isShowingOfflineResults {
            Label("You're offline. Showing demo recipes.", systemImage: "wifi.slash")
                .font(.caption)
                .foregroundStyle(.orange)
        } else if model.isUsingDemoData {
            Label("Showing demo recipes. Add a Spoonacular key, or try again tomorrow if the daily limit was reached.", systemImage: "shippingbox")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        if let errorMessage = model.errorMessage {
            Text(errorMessage)
                .font(.footnote)
                .foregroundStyle(.red)
        }
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
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.title)
                    .font(.headline)
                Text(missingIngredientsText(for: recipe))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if isFavorite {
                Spacer()
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink)
                    .accessibilityLabel("Favorite")
            }
        }
    }
}

#Preview {
    NavigationStack {
        RecipesView()
    }
    .previewEnvironment(SampleData.makePreviewSession())
}
