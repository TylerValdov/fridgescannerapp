//
//  ContentView.swift
//  fridgescannerapp
//
//  Created by Valdov, Tyler on 9/30/26.
//

import SwiftUI

struct ContentView: View {
    @State private var model = RecipeSearchModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ingredientInputRow
                if !model.ingredients.isEmpty {
                    ingredientChips
                }
                searchButton
                if let quotaLeft = model.quotaLeft {
                    Text("Spoonacular points left today: \(Int(quotaLeft))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                resultsSection
            }
            .padding()
            .navigationTitle("Fridge Scanner")
        }
    }

    private var ingredientInputRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                TextField("Add an ingredient (e.g. eggs)", text: $model.newIngredientText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { model.addIngredient() }
                    .onChange(of: model.newIngredientText) { _, _ in
                        model.scheduleSuggestionsUpdate()
                    }
                Button("Add") { model.addIngredient() }
                    .disabled(model.newIngredientText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if !model.suggestions.isEmpty {
                suggestionsList
            }
        }
    }

    private var suggestionsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(model.suggestions) { suggestion in
                Button {
                    model.selectSuggestion(suggestion)
                } label: {
                    Text(suggestion.name.capitalized)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var ingredientChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(model.ingredients, id: \.self) { ingredient in
                    IngredientChip(name: ingredient) {
                        model.removeIngredient(ingredient)
                    }
                }
            }
        }
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

private struct IngredientChip: View {
    let name: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(name)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
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
}
