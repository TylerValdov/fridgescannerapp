//
//  RecipesView.swift
//  fridgescannerapp
//
//  The Recipes tab: what the household can make from its fridge, grouped by
//  how many ingredients are missing. On iPad, the list and the selected
//  recipe sit side by side.
//

import SwiftUI
import SwiftData

// Searches only run from the button or pull-to-refresh, since each one costs quota.
struct RecipesView: View {
    private static let listWidth: CGFloat = 380

    // Switches to the Preferences section.
    var onEditPreferences: () -> Void = {}

    @Environment(RecipeSearchModel.self) private var model
    @Environment(SavedRecipeStore.self) private var history
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedRecipe: RecipeMatch?

    private var showsSideBySide: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 12) {
                ingredientsSummaryRow
                preferencesSummaryRow
                searchButton
                statusMessages
            }
            .padding(.horizontal)
            .padding(.top)

            if showsSideBySide {
                HStack(spacing: 0) {
                    resultsSection
                        .frame(width: RecipesView.listWidth)
                    Divider()
                    selectedRecipeDetail
                        .frame(maxWidth: .infinity)
                }
            } else {
                resultsSection
            }
        }
        .navigationTitle("Recipes")
    }

    // MARK: - Header rows

    private var ingredientsSummaryRow: some View {
        HStack {
            Image(systemName: "carrot")
            Text(
                model.ingredients.isEmpty
                    ? "No ingredients added"
                    : pluralize("ingredient", count: model.ingredients.count) + " in your fridge"
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
    private var statusMessages: some View {
        if model.isUsingDemoData {
            Label("Showing demo recipes. Add a Spoonacular key, or try again tomorrow if the daily limit was reached.", systemImage: "shippingbox")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if let quotaLeft = model.quotaLeft {
            Text("Spoonacular points left today: \(Int(quotaLeft))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        if model.resultsAreOutdated {
            Text("Your fridge or preferences changed. Tap Find Recipes to update.")
                .font(.caption)
                .foregroundStyle(.orange)
        }
        if let errorMessage = model.errorMessage {
            Text(errorMessage)
                .foregroundStyle(.red)
                .font(.footnote)
        }
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsSection: some View {
        if model.sections.isEmpty && !model.isLoading {
            ScrollView {
                if model.results.isEmpty {
                    EmptyStateView(
                        title: "No recipes yet",
                        systemImage: "fork.knife",
                        message: "Add ingredients to the fridge, then tap Find Recipes.",
                        badgeSystemImage: "magnifyingglass"
                    )
                } else {
                    // Results came back, but must-include or max-missing hid all of them.
                    EmptyStateView(
                        title: "No matches",
                        systemImage: "line.3.horizontal.decrease.circle",
                        message: "None of the \(model.results.count) recipes found fit your preferences. Try allowing more missing ingredients or removing a must-include ingredient."
                    )
                }
            }
        } else {
            List {
                ForEach(model.sections) { section in
                    Section(section.title) {
                        ForEach(section.recipes) { recipe in
                            row(for: recipe)
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

    // iPhone pushes the detail screen; iPad shows it in the right-hand pane.
    @ViewBuilder
    private func row(for recipe: RecipeMatch) -> some View {
        let label = RecipeRow(recipe: recipe, isFavorite: history.isLiked(recipe))
        if showsSideBySide {
            Button {
                selectedRecipe = recipe
            } label: {
                label
            }
            .buttonStyle(.plain)
            .listRowBackground(selectedRecipe?.id == recipe.id ? Color.accentColor.opacity(0.15) : nil)
        } else {
            NavigationLink {
                RecipeDetailView(recipe: recipe)
            } label: {
                label
            }
        }
    }

    @ViewBuilder
    private var selectedRecipeDetail: some View {
        if let selectedRecipe {
            RecipeDetailView(recipe: selectedRecipe)
                .id(selectedRecipe.id)
        } else {
            EmptyStateView(
                title: "Pick a recipe",
                systemImage: "hand.tap",
                message: "Its ingredients and instructions will show here."
            )
            .frame(maxHeight: .infinity)
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
        .contentShape(Rectangle())
    }
}

#Preview {
    let session = SampleData.makePreviewSession()
    NavigationStack {
        RecipesView()
    }
    .modelContainer(session.container)
    .environment(RecipeSearchModel(account: session.account, household: session.account.household!, context: session.container.mainContext))
    .environment(SavedRecipeStore(user: session.account.user, context: session.container.mainContext))
}
