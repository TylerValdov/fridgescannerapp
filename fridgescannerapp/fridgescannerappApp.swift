//
//  fridgescannerappApp.swift
//  fridgescannerapp
//
//  Created by Valdov, Tyler on 9/30/26.
//
//  App entry point. Sets up SwiftData storage for all five models and
//  hands off to RootView, which shows sign-in or the main app.
//

import SwiftUI
import SwiftData

@main
struct fridgescannerappApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Household.self, User.self, FridgeItem.self, SavedRecipe.self, MealPreferences.self])
    }
}
