//
//  RecipeDetailView.swift
//  fridgescannerapp
//
//  One recipe's photo, summary, ingredients and instructions, with buttons
//  to favorite it and mark it as cooked. Loads details through
//  RecipeSearchModel, so it works with live or demo data.
//

import SwiftUI

struct RecipeDetailView: View {
    private static let readableWidth: CGFloat = 700

    let recipe: RecipeMatch

    @Environment(SavedRecipeStore.self) private var history
    @Environment(RecipeSearchModel.self) private var model
    @State private var markedCooked = false
    @State private var details: RecipeDetails?
    @State private var isLoading = true
    @State private var errorMessage: String?
    /// A short confirmation after favoriting ("dialogs yield closure").
    @State private var confirmation: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                recipeImage

                VStack(alignment: .leading, spacing: 8) {
                    Text(details?.title ?? recipe.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)

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

                    // Adds the recipe to "Recently Used" on the Home tab.
                    Button {
                        history.addToRecent(recipe)
                        markedCooked = true
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
                                Label(
                                    ingredient.original,
                                    systemImage: "circle"
                                )
                                .font(.body)
                            }
                        }
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
        .overlay(alignment: .bottom) {
            if let confirmation {
                Label(confirmation, systemImage: "heart.fill")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation { self.confirmation = nil }
                    }
            }
        }
        .navigationTitle("Recipe Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    history.toggleLike(recipe)
                    withAnimation {
                        confirmation = history.isLiked(recipe) ? "Saved to Favorites" : nil
                    }
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
