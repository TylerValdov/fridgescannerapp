//
//  ContentView.swift
//  fridgescannerapp
//
//  Created by Valdov, Tyler on 9/30/26.
//

import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case home, fridge, recipes, preferences
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var model: RecipeSearchModel?
    // One shared store, so a favorite added on any screen shows up everywhere.
    @State private var history = RecipeHistoryStore()
    @State private var selectedTab: AppTab = .home

    var body: some View {
        Group {
            if let model {
                tabs(for: model)
            } else {
                ProgressView()
                    .task {
                        if model == nil {
                            model = RecipeSearchModel(context: modelContext)
                        }
                    }
            }
        }
        .environment(history)
    }

    private func tabs(for model: RecipeSearchModel) -> some View {
        TabView(selection: $selectedTab) {
            // HomeView has its own NavigationStack.
            HomeView(history: history, onFindRecipes: { selectedTab = .recipes })
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppTab.home)

            NavigationStack {
                IngredientEntryView(model: model)
            }
            .tabItem { Label("Fridge", systemImage: "refrigerator") }
            .tag(AppTab.fridge)

            NavigationStack {
                RecipesView(model: model, onEditPreferences: { selectedTab = .preferences })
            }
            .tabItem { Label("Recipes", systemImage: "fork.knife") }
            .tag(AppTab.recipes)

            NavigationStack {
                PreferencesView(model: model)
            }
            .tabItem { Label("Preferences", systemImage: "slider.horizontal.3") }
            .tag(AppTab.preferences)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [PersistedIngredient.self, MealPreferences.self], inMemory: true)
}
