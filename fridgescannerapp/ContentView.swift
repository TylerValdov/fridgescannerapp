//
//  ContentView.swift
//  fridgescannerapp
//
//  Created by Valdov, Tyler on 9/30/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var model: RecipeSearchModel?

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    FridgeScannerContent(model: model)
                } else {
                    ProgressView()
                        .task {
                            if model == nil {
                                model = RecipeSearchModel(context: modelContext)
                            }
                        }
                }
            }
            .navigationTitle("Fridge Scanner")
        }
    }
}

private struct FridgeScannerContent: View {
    let model: RecipeSearchModel

    var body: some View {
        VStack(spacing: 12) {
            ingredientsSummaryRow
            searchButton
            if let quotaLeft = model.quotaLeft {
                Text("Spoonacular points left today: \(Int(quotaLeft))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            resultsSection
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink("Manage Ingredients") {
                    IngredientEntryView(model: model)
                }
            }
        }
    }

    private var ingredientsSummaryRow: some View {
        HStack {
            Image(systemName: "carrot")
            Text(
                model.ingredients.isEmpty
                    ? "No ingredients added"
                    : "\(model.ingredients.count) ingredient\(model.ingredients.count == 1 ? "" : "s")"
            )
            Spacer()
        }
        .foregroundStyle(.secondary)
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
        .disabled(model.ingredients.isEmpty || model.isLoading || (model.quotaLeft ?? 1) <= 0)
    }

    @ViewBuilder
    private var resultsSection: some View {
        if let errorMessage = model.errorMessage {
            Text(errorMessage)
                .foregroundStyle(.red)
                .font(.footnote)
        }

        if model.results.isEmpty && !model.isLoading {
            ContentUnavailableView(
                "No Recipes Yet",
                systemImage: "fork.knife",
                description: Text(
                    "Add ingredients and tap Find Recipes to get started."
                )
            )
        } else {
            List(model.results) { recipe in
                NavigationLink {
                    RecipeDetailView(recipe: recipe)
                } label: {
                    RecipeRow(recipe: recipe)
                }
            }
            .listStyle(.plain)
        }
    }
}

private struct RecipeRow: View {
    let recipe: RecipeMatch

    var body: some View {
        HStack {
            AsyncImage(url: URL(string: recipe.image)) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.secondary.opacity(0.2)
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading) {
                Text(recipe.title)
                    .font(.headline)
                Text("Uses \(recipe.usedIngredientCount) • Missing \(recipe.missedIngredientCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: PersistedIngredient.self, inMemory: true)
}
