//
//  PersistedIngredient.swift
//  fridgescannerapp
//

import Foundation
import SwiftData

@Model
final class PersistedIngredient {
    var name: String
    var dateAdded: Date

    init(name: String, dateAdded: Date = .now) {
        self.name = name
        self.dateAdded = dateAdded
    }
}
