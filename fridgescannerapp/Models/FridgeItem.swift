//
//  FridgeItem.swift
//  fridgescannerapp
//
//  One ingredient in a household's fridge, with an optional expiration
//  date and the member who added it.
//

import Foundation
import SwiftData

// OOP: a SwiftData model class.
@Model
final class FridgeItem {
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
