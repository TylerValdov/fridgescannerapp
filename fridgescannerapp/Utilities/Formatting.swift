//
//  Formatting.swift
//  fridgescannerapp
//
//  Small text helpers used across the app: ingredient-name matching,
//  plurals, expiration text, and turning Spoonacular's HTML into plain text.
//

import Foundation
import UIKit

// Procedural: plain functions that take input and return output, with no
// shared state. Any screen can call them.

/// Trims and lowercases a name, so "  Eggs " and "eggs" are the same ingredient.
func normalizedIngredientName(_ name: String) -> String {
    name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
}

/// True when two names mean the same ingredient, e.g. "egg" and "eggs",
/// or "garlic" and "garlic cloves". Used by the demo-data recipe matching.
func ingredientNamesMatch(_ first: String, _ second: String) -> Bool {
    let a = singular(normalizedIngredientName(first))
    let b = singular(normalizedIngredientName(second))
    guard !a.isEmpty, !b.isEmpty else { return false }
    return a == b || a.contains(b) || b.contains(a)
}

private func singular(_ word: String) -> String {
    word.hasSuffix("s") ? String(word.dropLast()) : word
}

/// Ingredients almost every kitchen has, so a recipe isn't counted as missing them.
func isPantryStaple(_ name: String) -> Bool {
    let staples: Set<String> = [
        "water", "salt", "pepper", "black pepper", "salt and pepper", "salt & pepper",
        "oil", "olive oil", "extra virgin olive oil", "vegetable oil", "corn oil",
        "coconut oil", "sugar", "flour", "all purpose flour"
    ]
    return staples.contains(normalizedIngredientName(name))
}

/// "1 ingredient", "3 ingredients".
func pluralize(_ word: String, count: Int) -> String {
    "\(count) \(count == 1 ? word : word + "s")"
}

/// The line under a recipe in search results, e.g. "Uses 3 • Missing: eggs, milk".
func missingIngredientsText(for recipe: RecipeMatch) -> String {
    let uses = "Uses \(recipe.usedIngredientCount)"
    guard !recipe.missedIngredients.isEmpty else {
        return uses + " • You have everything"
    }
    return uses + " • Missing: " + recipe.missedIngredients.map(\.name).joined(separator: ", ")
}

/// "Expires today", "Expires in 3 days", "Expired 2 days ago".
func expirationText(for date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
    let start = calendar.startOfDay(for: now)
    let end = calendar.startOfDay(for: date)
    let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0

    switch days {
    case ..<(-1): return "Expired \(-days) days ago"
    case -1: return "Expired yesterday"
    case 0: return "Expires today"
    case 1: return "Expires tomorrow"
    default: return "Expires in \(days) days"
    }
}

/// True for items that expire today or have already expired.
func isExpiringSoon(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
    calendar.startOfDay(for: date) <= calendar.startOfDay(for: now)
}

/// Spoonacular's summaries and instructions are HTML. This returns plain text,
/// falling back to stripping tags if the HTML can't be parsed.
func stripHTML(_ html: String) -> String {
    guard
        let data = html.data(using: .utf8),
        let attributed = try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        )
    else {
        return html
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    return attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
}
