//
//  HomeView.swift
//  fridgescannerapp
//
//  Created by lending on 10/25/26.
//


import SwiftUI

struct HomeView: View {
    let history: RecipeHistoryStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {

                    // Welcome header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: "refrigerator")
                                .foregroundStyle(.primary)
                                .font(.largeTitle)

                            Text("Fridge Scanner")
                                .font(.largeTitle.bold())
                        }

                        Text("Turn your ingredients into something delicious!")
                            .foregroundStyle(.secondary)
                    }

                    // Find recipes button
                    
                    NavigationLink {
                        IngredientSearchView()
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "fork.knife")
                                .font(.title2)

                            VStack(alignment: .leading, spacing: 5) {
                                Text("Find Recipes")
                                    .font(.headline)

                                Text("Enter ingredients from your fridge")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.primary)
                        .padding(18)
                        .background(
                            Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                    }
                    .buttonStyle(.plain)


                    // Liked recipes
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Liked Recipes", systemImage: "heart.fill")
                            .font(.title2.bold())
                            .foregroundStyle(.primary)

                        if history.likedRecipes.isEmpty {
                            emptySection(
                                message: "No liked recipes yet",
                                subtitle: "Tap the heart on recipes you love!",
                                icon: "heart"
                            )
                        } else {
                            ForEach(history.likedRecipes) { recipe in
                                HomeRecipeCard(
                                    recipe: recipe,
                                    isLiked: history.isLiked(recipe),
                                    onLike: {
                                        history.toggleLike(recipe)
                                    }
                                )
                            }
                        }
                    }

                    // Recently cooked recipes
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Recently Used", systemImage: "clock.fill")
                            .font(.title2.bold())

                        if history.recentRecipes.isEmpty {
                            emptySection(
                                message: "No cooked recipes yet",
                                subtitle: "Recipes you mark as cooked will appear here.",
                                icon: "frying.pan"
                            )
                        } else {
                            ForEach(history.recentRecipes) { recipe in
                                HomeRecipeCard(
                                    recipe: recipe,
                                    isLiked: history.isLiked(recipe),
                                    onLike: {
                                        history.toggleLike(recipe)
                                    }
                                )
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func emptySection(
        message: String,
        subtitle: String,
        icon: String
    ) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 35))
                .foregroundStyle(.secondary)

            Text(message)
                .font(.headline)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .background(
            Color.gray.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 16)
        )
    }
}

// Recipe card displayed on homepage
private struct HomeRecipeCard: View {
    let recipe: RecipeMatch
    let isLiked: Bool
    let onLike: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: URL(string: recipe.image)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.2)
            }
            .frame(width: 90, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 8) {
                Text(recipe.title)
                    .font(.headline)
                    .lineLimit(2)

                Text("Uses \(recipe.usedIngredientCount) ingredients")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Missing \(recipe.missedIngredientCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onLike) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .foregroundStyle(.primary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            Color.gray.opacity(0.07),
            in: RoundedRectangle(cornerRadius: 14)
        )
    }
}
