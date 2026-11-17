//
//  User.swift
//  fridgescannerapp
//
//  A person who signs in. Belongs to one household, and keeps their own
//  favorites and cooking history.
//

import Foundation
import SwiftData

enum UserRole: String, CaseIterable {
    case admin
    case member

    var displayName: String {
        switch self {
        case .admin: "Admin"
        case .member: "Member"
        }
    }
}

// OOP: a SwiftData model class.
@Model
final class User {
    var username: String        // Lowercase; AuthModel keeps it unique
    var displayName: String
    var passwordHash: Data      // PBKDF2-SHA256 of the password, never the password itself
    var passwordSalt: Data
    var roleRaw: String
    var createdAt: Date
    var household: Household?

    @Relationship(deleteRule: .cascade, inverse: \SavedRecipe.user)
    var savedRecipes: [SavedRecipe] = []

    init(username: String, displayName: String, credential: PasswordCredential, role: UserRole, createdAt: Date = .now) {
        self.username = username
        self.displayName = displayName
        self.passwordHash = credential.hash
        self.passwordSalt = credential.salt
        self.roleRaw = role.rawValue
        self.createdAt = createdAt
    }
}

extension User {
    var role: UserRole {
        UserRole(rawValue: roleRaw) ?? .member
    }

    var credential: PasswordCredential {
        PasswordCredential(salt: passwordSalt, hash: passwordHash)
    }
}
