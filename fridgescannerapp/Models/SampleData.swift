//
//  SampleData.swift
//  fridgescannerapp
//
//  Two demo households with 8 users (2 admins, 6 members), stocked fridges,
//  shopping lists and diet rules. Added on first launch only. Every demo
//  account's password is "Fridge123".
//

import Foundation
import SwiftData

enum SampleData {
    static let demoPassword = "Fridge123"

    private struct SampleHousehold {
        let name: String
        let inviteCode: String
        let intolerances: [String]
        /// (username, display name); the first one is the admin.
        let users: [(String, String)]
        /// (ingredient, days until it expires or nil, username of who added it)
        let fridge: [(String, Int?, String)]
        let shoppingList: [String]
    }

    private static let households = [
        SampleHousehold(
            name: "Maple St Apartment",
            inviteCode: "MAPLE1",
            intolerances: [],
            users: [("dana", "Dana Whitfield"), ("marcus", "Marcus Lee"), ("priya", "Priya Shah"), ("leo", "Leo Martinez")],
            fridge: [
                ("eggs", 5, "marcus"), ("milk", 3, "dana"), ("spinach", 0, "priya"), ("cheddar cheese", 20, "dana"),
                ("tomatoes", 4, "leo"), ("onion", nil, "dana"), ("chicken breast", 1, "marcus"), ("rice", nil, "priya"),
                ("bell pepper", 6, "leo"), ("tortillas", 9, "marcus"), ("garlic", nil, "dana"), ("butter", 30, "priya")
            ],
            shoppingList: ["potato", "avocado", "coffee"]
        ),
        SampleHousehold(
            name: "Valdov Family",
            inviteCode: "VALDOV",
            intolerances: ["dairy"],
            users: [("tyler", "Tyler Valdov"), ("sam", "Sam Valdov"), ("jordan", "Jordan Valdov"), ("ava", "Ava Valdov")],
            fridge: [
                ("eggs", 8, "tyler"), ("chicken thighs", 2, "sam"), ("potatoes", nil, "tyler"), ("carrots", 10, "jordan"),
                ("broccoli", -1, "ava"), ("pasta", nil, "tyler"), ("ground beef", 1, "sam"), ("lemons", 12, "jordan"),
                ("garlic", nil, "tyler"), ("onion", nil, "ava"), ("canned tomatoes", nil, "tyler"), ("apples", 14, "jordan")
            ],
            shoppingList: ["penne", "parsley", "oat milk"]
        )
    ]

    /// Shown on the sign-in screen, e.g. "Maple St Apartment: dana (admin), marcus, priya, leo".
    static var demoAccountsDescription: String {
        households.map { household in
            // Functional: map each user to a label, marking the admin
            let names = household.users.enumerated().map { index, user in index == 0 ? "\(user.0) (admin)" : user.0 }
            return "\(household.name): \(names.joined(separator: ", "))"
        }
        .joined(separator: "\n")
    }

    /// Adds the demo households if there are none yet.
    static func seedIfNeeded(in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Household>())) ?? []
        if existing.isEmpty {
            insertSampleData(into: context)
        }
    }

    /// An in-memory store with the demo data, for SwiftUI previews.
    static func makePreviewSession(role: UserRole = .admin) -> (container: ModelContainer, account: Account) {
        let container = try! ModelContainer(
            for: Household.self, User.self, FridgeItem.self, SavedRecipe.self, MealPreferences.self, ShoppingListItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        insertSampleData(into: container.mainContext)
        let users = (try? container.mainContext.fetch(FetchDescriptor<User>())) ?? []
        let user = users.first { $0.role == role }!
        return (container, Account.make(for: user))
    }

    private static func insertSampleData(into context: ModelContext) {
        for sample in households {
            let household = Household(name: sample.name, inviteCode: sample.inviteCode)
            context.insert(household)

            let preferences = MealPreferences()
            preferences.intolerancesRaw = sample.intolerances
            household.attachPreferences(preferences, in: context)

            var usersByName: [String: User] = [:]
            for (index, (username, displayName)) in sample.users.enumerated() {
                let user = User(
                    username: username,
                    displayName: displayName,
                    credential: makeCredential(for: demoPassword),
                    role: index == 0 ? .admin : .member
                )
                household.addMember(user, in: context)
                usersByName[username] = user
            }

            // Items are added a minute apart so the fridge list has a stable order.
            for (index, (name, expiresInDays, addedBy)) in sample.fridge.enumerated() {
                let item = FridgeItem(
                    name: name,
                    expirationDate: expiresInDays.flatMap { Calendar.current.date(byAdding: .day, value: $0, to: .now) },
                    dateAdded: Date.now.addingTimeInterval(Double(index - sample.fridge.count) * 60)
                )
                household.addItem(item, addedBy: usersByName[addedBy], in: context)
            }

            for (index, name) in sample.shoppingList.enumerated() {
                household.addShoppingItem(ShoppingListItem(name: name, addedAt: Date.now.addingTimeInterval(Double(index))), in: context)
            }
        }
        try? context.save()
    }
}
