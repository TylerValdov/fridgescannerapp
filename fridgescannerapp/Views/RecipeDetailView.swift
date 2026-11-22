//
//  RecipeDetailView.swift
//  fridgescannerapp
//
//  One recipe's photo, summary, ingredients and instructions, with buttons
//  to favorite it, add what's missing to the shopping list, and mark it as
//  cooked (which removes the ingredients it used from the fridge, with Undo).
//  Loads details through RecipeSearchModel, so it works with live or demo data.
//

import SwiftUI

struct RecipeDetailView: View {
    private static let readableWidth: CGFloat = 700

    let recipe: RecipeMatch

    @Environment(SavedRecipeStore.self) private var history
    @Environment(RecipeSearchModel.self) private var model
    @Environment(ShoppingListModel.self) private var shopping
    @State private var markedCooked = false
    @State private var details: RecipeDetails?
    @State private var isLoading = true
    @State private var errorMessage: String?
    /// A short confirmation after favoriting or adding to the list ("dialogs yield closure").
    @State private var toast: Toast?

    private var title: String { details?.title ?? recipe.title }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                recipeImage

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    if let details {
                        let warnings = model.dietaryWarnings(for: recipe, details: details)

                        if !warnings.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label(
                                    "Dietary Warning",
                                    systemImage: "exclamationmark.triangle.fill"
                                )
                                .font(.headline)

                                ForEach(warnings, id: \.self) { warning in
                                    Text("• \(warning)")
                                        .font(.subheadline)
                                }
                            }
                            .foregroundStyle(.red)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                Color.red.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                        }
                    }

                    
                    HStack(spacing: 16) {
                        if let minutes = details?.readyInMinutes {
                            Label(
                                "\(minutes) min",
                                systemImage: "clock"
                            )
                        }

                        if let servings = details?.servings {
                            Label(
                                "\(servings) servings",
                                systemImage: "person.2"
                            )
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    // Adds the recipe to "Recently Used" on Home and removes the
                    // fridge items it used. The Undo banner puts them back.
                    Button {
                        history.addToRecent(recipe)
                        markedCooked = true
                        withAnimation {
                            model.removeAfterCooking(recipe, details: details)
                        }
                    } label: {
                        Label(
                            markedCooked ? "Added to Recently Used" : "Mark as Cooked",
                            systemImage: markedCooked ? "checkmark" : "frying.pan"
                        )
                    }
                    .buttonStyle(.bordered)
                    .disabled(markedCooked)

                    let timesCooked = history.timesCooked(recipe)
                    if timesCooked > 0 {
                        Text("You've cooked this \(timesCooked == 1 ? "once" : "\(timesCooked) times").")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if isLoading {
                    ProgressView("Loading recipe details...")
                        .frame(maxWidth: .infinity)
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)

                    Button("Try Again") {
                        Task {
                            await loadDetails()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let details {
                    if let summary = details.summary,
                       !summary.isEmpty {
                        sectionTitle("About This Recipe")

                        Text(stripHTML(summary))
                            .font(.body)
                    }

                    sectionTitle("Ingredients")

                    if let ingredients = details.extendedIngredients,
                       !ingredients.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(ingredients) { ingredient in
                                Label(ingredient.original, systemImage: "circle")
                                    .font(.body)
                            }
                        }
                        missingIngredientsButton
                    } else {
                        Text("Ingredient details are unavailable.")
                            .foregroundStyle(.secondary)
                    }

                    sectionTitle("Cooking Instructions")

                    if let instructions = details.instructions,
                       !stripHTML(instructions).isEmpty {
                        Text(stripHTML(instructions))
                            .font(.body)
                            .lineSpacing(5)
                    } else {
                        Text(
                            "Cooking instructions are not available for this recipe."
                        )
                        .foregroundStyle(.secondary)
                    }

                    if let source = details.sourceUrl,
                       let url = URL(string: source) {
                        Link(
                            "View Original Recipe",
                            destination: url
                        )
                        .font(.headline)
                    }
                }
            }
            .padding()
            // On iPad, keep lines a readable length instead of stretching across the screen.
            .frame(maxWidth: RecipeDetailView.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .confirmationToast($toast)
        .fridgeUndoBanner()
        .navigationTitle("Recipe Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    history.toggleLike(recipe)
                    toast = history.isLiked(recipe) ? Toast(message: "Saved to Favorites", systemImage: "heart.fill") : nil
                } label: {
                    Image(systemName: history.isLiked(recipe) ? "heart.fill" : "heart")
                }
                .accessibilityLabel(history.isLiked(recipe) ? "Remove from Favorites" : "Add to Favorites")
            }
        }
        .task {
            await loadDetails()
        }
    }

    private var recipeImage: some View {
        AsyncImage(
            url: (details?.image ?? recipe.image).flatMap {
                URL(string: $0)
            }
        ) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            ZStack {
                Color.secondary.opacity(0.15)
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        // Decorative: the title below already says what it shows.
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var missingIngredientsButton: some View {
        let missing = model.missingIngredients(for: recipe, details: details)
        // Functional: filter keeps only what isn't already on the list
        let notOnList = missing.filter { !shopping.contains($0) }

        if !notOnList.isEmpty {
            Button {
                shopping.addAll(notOnList)
                toast = Toast(message: "Added \(notOnList.count) to your shopping list", systemImage: "cart.badge.plus")
            } label: {
                Label("Add \(notOnList.count) Missing to Shopping List", systemImage: "cart.badge.plus")
            }
            .buttonStyle(.bordered)
        } else if !missing.isEmpty {
            Label("Everything missing is on your shopping list.", systemImage: "cart")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title2)
            .fontWeight(.semibold)
            .padding(.top, 4)
    }

    private func loadDetails() async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            details = try await model.recipeDetails(id: recipe.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    // Breakfast Tacos, from the demo data.
    let recipe = RecipeMatch(id: 511748, title: "Breakfast Tacos", image: nil, usedIngredientCount: 0,
                             missedIngredientCount: 0, missedIngredients: [], usedIngredients: [])
    NavigationStack {
        RecipeDetailView(recipe: recipe)
    }
    .previewEnvironment(SampleData.makePreviewSession())
}
