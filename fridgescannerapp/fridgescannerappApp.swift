//
//  fridgescannerappApp.swift
//  fridgescannerapp
//
//  Created by Valdov, Tyler on 9/30/26.
//
//  App entry point. Sets up SwiftData storage for all six models, then
//  RootView shows the sign-in screens or the main app.
//

import SwiftUI
import SwiftData

@main
struct fridgescannerappApp: App {
    init() {
            ExpirationNotifier.shared.setup()
        }
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Household.self, User.self, FridgeItem.self, ShoppingListItem.self, SavedRecipe.self, MealPreferences.self])
    }
}

/// Adds the demo households on first launch, then shows sign-in or the main app.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var auth: AuthModel?

    var body: some View {
        Group {
            if let auth {
                if let account = auth.account {
                    if account.user.needsDietaryOnboarding == true {
                        DietaryOnboardingView(user: account.user)
                    } else {
                        ContentView(account: account)
                            .id(ObjectIdentifier(account))
                    }
                } else {
                    SignInView()
                }
            } else {
                ProgressView()
                    .onAppear {
                        SampleData.seedIfNeeded(in: modelContext)
                        let items = (try? modelContext.fetch(FetchDescriptor<FridgeItem>())) ?? []  
                        ExpirationNotifier.shared.sync(items)
                        auth = AuthModel(context: modelContext)
                    }
            }
        }
        .environment(auth)
    }
}
