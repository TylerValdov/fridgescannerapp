//
//  RecipeBrowserView.swift
//  fridgescannerapp
//
//  The iPad Recipes screen: search results on the left and the chosen
//  recipe's details on the right, so recipes can be compared without going
//  back and forth. iPhone pushes RecipeDetailView from RecipesView instead.
//

import SwiftUI

struct RecipeBrowserView: View {
    /// Switches to the Preferences section.
    var onEditPreferences: (() -> Void)?

    @Environment(RecipeSearchModel.self) private var model
    @State private var selectedRecipe: RecipeMatch?

    var body: some View {
        HStack(spacing: 0) {
            NavigationStack {
                RecipesView(onEditPreferences: onEditPreferences, selection: $selectedRecipe)
            }
            .frame(width: 380)

            Divider()

            NavigationStack {
                if let selectedRecipe {
                    // .id gives each recipe a fresh detail screen, so its details load.
                    RecipeDetailView(recipe: selectedRecipe)
                        .id(selectedRecipe.id)
                } else {
                    ContentUnavailableView(
                        "Choose a Recipe",
                        systemImage: "fork.knife",
                        description: Text("Tap Find Recipes, then pick a recipe to see it here.")
                    )
                }
            }
        }
        // A new search may not include the chosen recipe; clear it rather than show a stale one.
        .onChange(of: model.results) { _, results in
            if let selectedRecipe, !results.contains(selectedRecipe) {
                self.selectedRecipe = nil
            }
        }
    }
}

#Preview(traits: .landscapeLeft) {
    RecipeBrowserView()
        .previewEnvironment(SampleData.makePreviewSession())
}
