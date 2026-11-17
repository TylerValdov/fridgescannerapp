//
//  Household.swift
//  fridgescannerapp
//
//  A group of people who share one fridge, such as roommates or a family.
//  Owns its members, its fridge items, and its meal preferences.
//

import Foundation
import SwiftData

// OOP: a SwiftData model class. Deleting a household deletes everything it owns.
@Model
final class Household {
    var name: String
    var inviteCode: String      // 6 characters; new members enter it to join
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \User.household)
    var members: [User] = []

    @Relationship(deleteRule: .cascade, inverse: \FridgeItem.household)
    var items: [FridgeItem] = []

    @Relationship(deleteRule: .cascade, inverse: \MealPreferences.household)
    var preferences: MealPreferences?

    init(name: String, inviteCode: String, createdAt: Date = .now) {
        self.name = name
        self.inviteCode = inviteCode
        self.createdAt = createdAt
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
