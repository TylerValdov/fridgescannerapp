//
//  ContentView.swift
//  fridgescannerapp
//
//  Created by Valdov, Tyler on 9/30/26.
//
//  The main app for a signed-in account. iPhone gets a tab bar; iPad (or any
//  wide window) gets a sidebar, so each platform has its own layout.
//

import SwiftUI
import SwiftData

/// The app's sections, shown as tabs on iPhone and sidebar rows on iPad.
enum AppSection: String, CaseIterable, Identifiable {
    case home, fridge, recipes, household, preferences

    var id: Self { self }

    var title: String {
        switch self {
        case .home: "Home"
        case .fridge: "Fridge"
        case .recipes: "Recipes"
        case .household: "Household"
        case .preferences: "Preferences"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .fridge: "refrigerator"
        case .recipes: "fork.knife"
        case .household: "person.3"
        case .preferences: "slider.horizontal.3"
        }
    }
}

struct ContentView: View {
    let account: Account

    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(AuthModel.self) private var auth
    @State private var model: RecipeSearchModel?
    @State private var savedRecipes: SavedRecipeStore?
    @State private var selection: AppSection? = .home

    var body: some View {
        if let household = account.household {
            if let model, let savedRecipes {
                layout
                    .environment(model)
                    .environment(savedRecipes)
            } else {
                ProgressView()
                    .task {
                        model = RecipeSearchModel(account: account, household: household, context: modelContext)
                        savedRecipes = SavedRecipeStore(user: account.user, context: modelContext)
                    }
            }
        } else {
            ContentUnavailableView {
                Label("No Household", systemImage: "house.slash")
            } description: {
                Text("This account isn't part of a household anymore.")
            } actions: {
                Button("Sign Out") { auth.signOut() }
            }
        }
    }

    @ViewBuilder
    private var layout: some View {
        if horizontalSizeClass == .regular {
            sidebarLayout
        } else {
            tabLayout
        }
    }

    // iPhone: one tab per section.
    private var tabLayout: some View {
        TabView(selection: Binding(get: { selection ?? .home }, set: { selection = $0 })) {
            ForEach(AppSection.allCases) { section in
                screen(for: section)
                    .tabItem { Label(section.title, systemImage: section.systemImage) }
                    .tag(section)
            }
        }
    }

    // iPad: a sidebar of sections beside the selected screen.
    private var sidebarLayout: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
            }
            .navigationTitle(account.household?.name ?? "Fridge Scanner")
        } detail: {
            screen(for: selection ?? .home)
        }
    }

    @ViewBuilder
    private func screen(for section: AppSection) -> some View {
        switch section {
        case .home:
            // HomeView has its own NavigationStack.
            HomeView(onFindRecipes: { selection = .recipes })
        case .fridge:
            NavigationStack { IngredientEntryView() }
        case .recipes:
            NavigationStack { RecipesView(onEditPreferences: { selection = .preferences }) }
        case .household:
            NavigationStack { HouseholdView() }
        case .preferences:
            NavigationStack { PreferencesView() }
        }
    }
}

#Preview {
    let session = SampleData.makePreviewSession()
    ContentView(account: session.account)
        .modelContainer(session.container)
        .environment(AuthModel(context: session.container.mainContext))
}
