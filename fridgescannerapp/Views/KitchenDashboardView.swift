//
//  KitchenDashboardView.swift
//  fridgescannerapp
//
//  The iPad Home screen: a dashboard for planning from the kitchen. What to
//  use soon, the shared shopping list, favorites and recently cooked recipes
//  sit side by side, so planning doesn't need four screens. iPhone uses HomeView.
//

import SwiftUI

struct KitchenDashboardView: View {
    @Environment(RecipeSearchModel.self) private var model
    @Environment(ShoppingListModel.self) private var shopping
    @Environment(SavedRecipeStore.self) private var history
    /// Switches to the Recipes section.
    var onFindRecipes: () -> Void = {}
    @State private var toast: Toast?

    /// Items that expire within 3 days (or already have), soonest first.
    private var useSoonItems: [FridgeItem] {
        let cutoff = Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now
        // Functional: keep items with a date before the cutoff, then sort soonest first
        return model.items
            .filter { ($0.expirationDate ?? .distantFuture) <= cutoff }
            .sorted { ($0.expirationDate ?? .now) < ($1.expirationDate ?? .now) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    // Two columns side by side; drops to one on a narrow window.
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 20, alignment: .top)], spacing: 20) {
                        useSoonCard
                        shoppingCard
                        recipesCard("Favorites", systemImage: "heart.fill", recipes: history.likedRecipes,
                                    emptyText: "Tap the heart on a recipe to save it here.")
                        recipesCard("Recently Cooked", systemImage: "clock.fill", recipes: history.recentRecipes,
                                    emptyText: "Recipes you mark as cooked appear here.")
                    }
                }
                .padding(24)
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationToast($toast)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Hi, \(model.account.user.firstName)")
                    .font(.largeTitle.bold())
                // Polymorphism: admins and members get different text from their Account subclass
                Text(model.account.homeGreeting)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Find Recipes", systemImage: "fork.knife", action: onFindRecipes)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }

    // Golden rule "reduce short-term memory load": what's about to spoil is
    // visible while choosing what to cook.
    private var useSoonCard: some View {
        DashboardCard(title: "Use Soon", systemImage: "exclamationmark.triangle") {
            if useSoonItems.isEmpty {
                Text("Nothing expires in the next 3 days.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(useSoonItems) { item in
                    HStack {
                        Text(item.name.capitalized)
                        Spacer()
                        if let date = item.expirationDate {
                            Text(expirationText(for: date))
                                .font(.subheadline)
                                .foregroundStyle(isExpiringSoon(date) ? .red : .secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var shoppingCard: some View {
        DashboardCard(title: "Shopping List", systemImage: "cart") {
            if shopping.items.isEmpty {
                Text("Nothing to buy.")
                    .foregroundStyle(.secondary)
            }
            ForEach(shopping.items) { item in
                ShoppingItemRow(item: item) {
                    withAnimation { shopping.toggle(item) }
                }
            }
            if shopping.checkedCount > 0 {
                Button("Move \(shopping.checkedCount) Checked to Fridge", systemImage: "refrigerator") {
                    let count = withAnimation(.default) { shopping.moveCheckedToFridge() }
                    toast = Toast(message: "Moved \(pluralize("item", count: count)) to the fridge", systemImage: "refrigerator")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func recipesCard(_ title: String, systemImage: String, recipes: [RecipeMatch], emptyText: String) -> some View {
        DashboardCard(title: title, systemImage: systemImage) {
            if recipes.isEmpty {
                Text(emptyText)
                    .foregroundStyle(.secondary)
            }
            ForEach(recipes) { recipe in
                NavigationLink {
                    RecipeDetailView(recipe: recipe)
                } label: {
                    HStack {
                        Text(recipe.title)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// One rounded panel on the dashboard, with a title and any content.
private struct DashboardCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview(traits: .landscapeLeft) {
    KitchenDashboardView()
        .previewEnvironment(SampleData.makePreviewSession())
}
