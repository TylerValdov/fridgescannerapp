//
//  DataModels.swift
//  fridgescannerapp
//
//  Every SwiftData model the app saves:
//    Household ─┬─ many User ── many SavedRecipe
//               ├─ many FridgeItem
//               ├─ many ShoppingListItem
//               └─ one MealPreferences
//  Deleting a household deletes everything it owns. Relationships are
//  connected in ModelLinks.swift.
//

import Foundation
import SwiftData

// OOP: each @Model below is a class that SwiftData saves to the device.

/// A group of people who share one fridge, such as roommates or a family.
@Model
final class Household {
    var name: String
    var inviteCode: String      // 6 characters; new members enter it to join

    @Relationship(deleteRule: .cascade, inverse: \User.household)
    var members: [User] = []

    @Relationship(deleteRule: .cascade, inverse: \FridgeItem.household)
    var items: [FridgeItem] = []

    @Relationship(deleteRule: .cascade, inverse: \ShoppingListItem.household)
    var shoppingItems: [ShoppingListItem] = []

    @Relationship(deleteRule: .cascade, inverse: \MealPreferences.household)
    var preferences: MealPreferences?

    init(name: String, inviteCode: String) {
        self.name = name
        self.inviteCode = inviteCode
    }
}

extension Household {
    var admin: User? {
        members.first { $0.role == .admin }
    }

    /// Admin first, then everyone else by name.
    var sortedMembers: [User] {
        members.sorted { first, second in
            if first.role != second.role { return first.role == .admin }
            return first.displayName < second.displayName
        }
    }
}

// MARK: - Users

enum UserRole: String {
    case admin
    case member

    var displayName: String { rawValue.capitalized }
}

/// A person who signs in. Belongs to one household, and keeps their own
/// favorites and cooking history.
@Model
final class User {
    var username: String        // Lowercase; AuthModel keeps it unique
    var displayName: String
    var passwordHash: Data      // Salted SHA-256 of the password, never the password itself
    var passwordSalt: Data
    var roleRaw: String
    var household: Household?
    
    var personalDietRaw: String = ""
    var personalIntolerancesRaw: [String] = []

    var needsDietaryOnboarding: Bool? = nil


    @Relationship(deleteRule: .cascade, inverse: \SavedRecipe.user)
    var savedRecipes: [SavedRecipe] = []

    init(username: String, displayName: String, credential: PasswordCredential, role: UserRole) {
        self.username = username
        self.displayName = displayName
        self.passwordHash = credential.hash
        self.passwordSalt = credential.salt
        self.roleRaw = role.rawValue
    }
}

extension User {
    var role: UserRole {
        UserRole(rawValue: roleRaw) ?? .member
    }

    var firstName: String {
        displayName.components(separatedBy: " ").first ?? displayName
    }

    var credential: PasswordCredential {
        PasswordCredential(salt: passwordSalt, hash: passwordHash)
    }
}

// MARK: - Fridge and shopping list

/// One ingredient in the household's fridge.
@Model
final class FridgeItem {
    var id: UUID = UUID()
    var name: String            // Lowercase, as sent to the recipe search
    var expirationDate: Date?
    var dateAdded: Date
    var household: Household?
    var addedBy: User?

    init(name: String, expirationDate: Date? = nil, dateAdded: Date = .now) {
        self.name = name
        self.expirationDate = expirationDate
        self.dateAdded = dateAdded
    }
}

/// One thing the household needs to buy.
@Model
final class ShoppingListItem {
    var name: String
    var isChecked: Bool = false // True once it's in the cart
    var addedAt: Date
    var household: Household?

    init(name: String, addedAt: Date = .now) {
        self.name = name
        self.addedAt = addedAt
    }
}

// MARK: - Saved recipes

/// A recipe one user has favorited or cooked. Keeps a small copy of the
/// recipe so Home can show it without a network request.
@Model
final class SavedRecipe {
    var recipeID: Int
    var title: String
    var imageURL: String?
    var usedIngredientCount: Int     // From when it was saved, not the current fridge
    var missedIngredientCount: Int
    var isFavorite: Bool = false
    var favoritedAt: Date?
    var timesCooked: Int = 0
    var lastCookedAt: Date?
    var user: User?

    init(recipe: RecipeMatch) {
        self.recipeID = recipe.id
        self.title = recipe.title
        self.imageURL = recipe.image
        self.usedIngredientCount = recipe.usedIngredientCount
        self.missedIngredientCount = recipe.missedIngredientCount
    }
}

extension SavedRecipe {
    /// The saved copy as a RecipeMatch, so the recipe screens can show it.
    var match: RecipeMatch {
        RecipeMatch(
            id: recipeID, title: title, image: imageURL,
            usedIngredientCount: usedIngredientCount,
            missedIngredientCount: missedIngredientCount,
            missedIngredients: [], usedIngredients: []
        )
    }
}

// MARK: - Meal preferences

// Spoonacular's 11 diets. The raw value is exactly what the API's `diet` parameter expects.
enum Diet: String, CaseIterable, Identifiable {
    case noPreference = ""
    case glutenFree = "gluten free"
    case ketogenic = "ketogenic"
    case vegetarian = "vegetarian"
    case lactoVegetarian = "lacto-vegetarian"
    case ovoVegetarian = "ovo-vegetarian"
    case vegan = "vegan"
    case pescetarian = "pescetarian"
    case paleo = "paleo"
    case primal = "primal"
    case lowFODMAP = "low fodmap"
    case whole30 = "whole30"

    var id: Self { self }

    /// The diets a person can pick for themselves: the ones whose conflicts
    /// can be spotted from ingredient names (see RecipeSearchModel.dietaryWarnings).
    static let personalOptions: [Diet] = [.noPreference, .vegetarian, .lactoVegetarian, .ovoVegetarian, .vegan, .pescetarian, .glutenFree]

    /// nil means "don't send the parameter".
    var apiValue: String? {
        self == .noPreference ? nil : rawValue
    }

    var displayName: String {
        switch self {
        case .noPreference: "No Preference"
        case .lowFODMAP: "Low FODMAP"
        case .whole30: "Whole30"
        default: rawValue.capitalized   // "Gluten Free", "Lacto-Vegetarian"
        }
    }
}

enum Intolerance: String, CaseIterable, Identifiable {
    case dairy, egg, gluten, grain, peanut, seafood, sesame, shellfish, soy, sulfite
    case treeNut = "tree nut"
    case wheat

    var id: Self { self }
}

/// The household's shared diet rules. Only the admin can change them.
@Model
final class MealPreferences {
    var dietRaw: String = ""
    var intolerancesRaw: [String] = []
    var mustInclude: [String] = []
    var excluded: [String] = []
    var maxMissing: Int = 3
    var household: Household?

    init() {}
}

extension MealPreferences {
    var diet: Diet {
        get { Diet(rawValue: dietRaw) ?? .noPreference }
        set { dietRaw = newValue.rawValue }
    }

    // e.g. "Vegan · No dairy · Excluding mushrooms", or nil when nothing is set.
    var summary: String? {
        // Procedural: builds the summary step by step
        var parts: [String] = []
        if diet != .noPreference {
            parts.append(diet.displayName)
        }
        if !intolerancesRaw.isEmpty {
            parts.append("No " + intolerancesRaw.joined(separator: ", "))
        }
        if !mustInclude.isEmpty {
            parts.append("With " + mustInclude.joined(separator: ", "))
        }
        if !excluded.isEmpty {
            parts.append("Excluding " + excluded.joined(separator: ", "))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
