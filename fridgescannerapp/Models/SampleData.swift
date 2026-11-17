//
//  SampleData.swift
//  fridgescannerapp
//
//  Two demo households with 8 users (2 admins, 6 members), fridge items,
//  diet rules, favorites and cooking history. Added on first launch only.
//  Every demo account's password is "Fridge123".
//

import Foundation
import SwiftData

enum SampleData {
    static let demoPassword = "Fridge123"

    private struct SampleUser {
        let username: String
        let displayName: String
        let role: UserRole
        var favorites: [Int] = []       // Recipe IDs from MockData/MockRecipes.json
        var cooked: [Int] = []
    }

    private struct SampleItem {
        let name: String
        let expiresInDays: Int?
        let addedBy: String
    }

    private struct SampleHousehold {
        let name: String
        let inviteCode: String
        let intolerances: [Intolerance]
        let users: [SampleUser]
        let items: [SampleItem]
    }

    private static let households = [
        SampleHousehold(
            name: "Maple St Apartment",
            inviteCode: "MAPLE1",
            intolerances: [],
            users: [
                SampleUser(username: "dana", displayName: "Dana Whitfield", role: .admin, favorites: [511748, 637686], cooked: [636769]),
                SampleUser(username: "marcus", displayName: "Marcus Lee", role: .member, favorites: [769775], cooked: [511748]),
                SampleUser(username: "priya", displayName: "Priya Shah", role: .member, favorites: [1674265]),
                SampleUser(username: "leo", displayName: "Leo Martinez", role: .member, cooked: [641808])
            ],
            items: [
                SampleItem(name: "eggs", expiresInDays: 5, addedBy: "marcus"),
                SampleItem(name: "milk", expiresInDays: 3, addedBy: "dana"),
                SampleItem(name: "spinach", expiresInDays: 0, addedBy: "priya"),
                SampleItem(name: "cheddar cheese", expiresInDays: 20, addedBy: "dana"),
                SampleItem(name: "tomatoes", expiresInDays: 4, addedBy: "leo"),
                SampleItem(name: "onion", expiresInDays: nil, addedBy: "dana"),
                SampleItem(name: "chicken breast", expiresInDays: 1, addedBy: "marcus"),
                SampleItem(name: "rice", expiresInDays: nil, addedBy: "priya"),
                SampleItem(name: "bell pepper", expiresInDays: 6, addedBy: "leo"),
                SampleItem(name: "tortillas", expiresInDays: 9, addedBy: "marcus"),
                SampleItem(name: "garlic", expiresInDays: nil, addedBy: "dana"),
                SampleItem(name: "butter", expiresInDays: 30, addedBy: "priya")
            ]
        ),
        SampleHousehold(
            name: "Valdov Family",
            inviteCode: "VALDOV",
            intolerances: [.dairy],
            users: [
                SampleUser(username: "tyler", displayName: "Tyler Valdov", role: .admin, favorites: [648300, 655573], cooked: [632356]),
                SampleUser(username: "sam", displayName: "Sam Valdov", role: .member, favorites: [635807]),
                SampleUser(username: "jordan", displayName: "Jordan Valdov", role: .member, favorites: [648983]),
                SampleUser(username: "ava", displayName: "Ava Valdov", role: .member, cooked: [655573])
            ],
            items: [
                SampleItem(name: "eggs", expiresInDays: 8, addedBy: "tyler"),
                SampleItem(name: "chicken thighs", expiresInDays: 2, addedBy: "sam"),
                SampleItem(name: "potatoes", expiresInDays: nil, addedBy: "tyler"),
                SampleItem(name: "carrots", expiresInDays: 10, addedBy: "jordan"),
                SampleItem(name: "broccoli", expiresInDays: -1, addedBy: "ava"),
                SampleItem(name: "pasta", expiresInDays: nil, addedBy: "tyler"),
                SampleItem(name: "ground beef", expiresInDays: 1, addedBy: "sam"),
                SampleItem(name: "lemons", expiresInDays: 12, addedBy: "jordan"),
                SampleItem(name: "garlic", expiresInDays: nil, addedBy: "tyler"),
                SampleItem(name: "onion", expiresInDays: nil, addedBy: "ava"),
                SampleItem(name: "canned tomatoes", expiresInDays: nil, addedBy: "tyler"),
                SampleItem(name: "apples", expiresInDays: 14, addedBy: "jordan")
            ]
        )
    ]

    /// Shown on the sign-in screen, e.g. "dana (admin), marcus, priya, leo".
    static var demoAccountsDescription: String {
        households.map { household in
            let names = household.users.map { $0.role == .admin ? "\($0.username) (admin)" : $0.username }
            return "\(household.name): \(names.joined(separator: ", "))"
        }
        .joined(separator: "\n")
    }

    private static var allUsernames: [String] {
        households.flatMap { $0.users.map(\.username) }
    }

    /// Adds the demo households if the store is empty. Password hashing runs
    /// in the background because each hash takes a moment.
    static func seedIfNeeded(in context: ModelContext) async {
        let existing = (try? context.fetch(FetchDescriptor<Household>())) ?? []
        guard existing.isEmpty else { return }

        let usernames = allUsernames
        let password = demoPassword
        let credentials = await Task.detached {
            Dictionary(uniqueKeysWithValues: usernames.map { ($0, makeCredential(for: password)) })
        }.value
        insertSampleData(into: context, credentials: credentials)
    }

    /// An in-memory store with the demo data, for SwiftUI previews.
    static func makePreviewSession(role: UserRole = .admin) -> (container: ModelContainer, account: Account) {
        let container = try! ModelContainer(
            for: Household.self, User.self, FridgeItem.self, SavedRecipe.self, MealPreferences.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let credentials = Dictionary(uniqueKeysWithValues: allUsernames.map { ($0, makeCredential(for: demoPassword)) })
        insertSampleData(into: container.mainContext, credentials: credentials)

        let users = (try? container.mainContext.fetch(FetchDescriptor<User>())) ?? []
        let user = users.first { $0.role == role }!
        return (container, Account.make(for: user))
    }

    private static func insertSampleData(into context: ModelContext, credentials: [String: PasswordCredential]) {
        let demoRecipes = MockRecipeProvider()
        let calendar = Calendar.current

        for sample in households {
            let household = Household(name: sample.name, inviteCode: sample.inviteCode)
            context.insert(household)

            let preferences = MealPreferences()
            preferences.intolerances = Set(sample.intolerances)
            household.attachPreferences(preferences, in: context)

            var usersByName: [String: User] = [:]
            for sampleUser in sample.users {
                let user = User(
                    username: sampleUser.username,
                    displayName: sampleUser.displayName,
                    credential: credentials[sampleUser.username]!,
                    role: sampleUser.role
                )
                household.addMember(user, in: context)
                usersByName[sampleUser.username] = user
            }

            // Items are added an hour apart so the fridge list has a stable order.
            for (index, sampleItem) in sample.items.enumerated() {
                let item = FridgeItem(
                    name: sampleItem.name,
                    expirationDate: sampleItem.expiresInDays.flatMap { calendar.date(byAdding: .day, value: $0, to: .now) },
                    dateAdded: Date.now.addingTimeInterval(Double(index - sample.items.count) * 3600)
                )
                household.addItem(item, addedBy: usersByName[sampleItem.addedBy], in: context)
            }

            let fridge = sample.items.map(\.name)
            for sampleUser in sample.users {
                guard let user = usersByName[sampleUser.username] else { continue }

                for (index, recipeID) in sampleUser.favorites.enumerated() {
                    guard let match = demoRecipes.match(forRecipeID: recipeID, against: fridge) else { continue }
                    let saved = SavedRecipe(recipe: match)
                    saved.isFavorite = true
                    saved.favoritedAt = calendar.date(byAdding: .day, value: -(index + 1), to: .now)
                    user.addSavedRecipe(saved, in: context)
                }

                for (index, recipeID) in sampleUser.cooked.enumerated() {
                    guard let match = demoRecipes.match(forRecipeID: recipeID, against: fridge) else { continue }
                    let saved = user.savedRecipes.first { $0.recipeID == recipeID } ?? {
                        let new = SavedRecipe(recipe: match)
                        user.addSavedRecipe(new, in: context)
                        return new
                    }()
                    saved.timesCooked = index + 1
                    saved.lastCookedAt = calendar.date(byAdding: .day, value: -(index + 2), to: .now)
                }
            }
        }

        try? context.save()
    }
}
