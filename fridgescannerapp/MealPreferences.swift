//
//  MealPreferences.swift
//  fridgescannerapp
//

import Foundation
import SwiftData

// Spoonacular's 11 diets. The raw value is exactly what complexSearch's `diet` parameter expects.
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

    // nil means "don't send the parameter".
    var apiValue: String? {
        self == .noPreference ? nil : rawValue
    }

    var displayName: String {
        switch self {
        case .noPreference: "No Preference"
        case .glutenFree: "Gluten Free"
        case .ketogenic: "Ketogenic"
        case .vegetarian: "Vegetarian"
        case .lactoVegetarian: "Lacto-Vegetarian"
        case .ovoVegetarian: "Ovo-Vegetarian"
        case .vegan: "Vegan"
        case .pescetarian: "Pescetarian"
        case .paleo: "Paleo"
        case .primal: "Primal"
        case .lowFODMAP: "Low FODMAP"
        case .whole30: "Whole30"
        }
    }

    var explanation: String {
        switch self {
        case .noPreference: "Show recipes for any diet."
        case .glutenFree: "No wheat, barley, rye or other gluten-containing grains."
        case .ketogenic: "High fat and very low carb, so no grains, sugar or starchy foods."
        case .vegetarian: "No meat or fish. Eggs and dairy are fine."
        case .lactoVegetarian: "Vegetarian with dairy, but no eggs."
        case .ovoVegetarian: "Vegetarian with eggs, but no dairy."
        case .vegan: "No meat, fish, eggs, dairy, honey or other animal products."
        case .pescetarian: "Vegetarian, plus fish and seafood."
        case .paleo: "No grains, dairy, legumes, refined sugar or processed foods."
        case .primal: "Like paleo, but allows some dairy."
        case .lowFODMAP: "Avoids foods high in fermentable carbs, such as onion, garlic and wheat."
        case .whole30: "No grains, dairy, legumes, added sugar or alcohol."
        }
    }
}

enum Intolerance: String, CaseIterable, Identifiable {
    case dairy, egg, gluten, grain, peanut, seafood, sesame, shellfish, soy, sulfite
    case treeNut = "tree nut"
    case wheat

    var id: Self { self }

    var displayName: String { rawValue.capitalized }
}

// Single row holding the user's meal preferences. RecipeSearchModel creates it on first launch.
@Model
final class MealPreferences {
    var dietRaw: String = ""
    var intolerancesRaw: [String] = []
    var mustInclude: [String] = []
    var excluded: [String] = []
    var maxMissing: Int = 3

    init() {}
}

extension MealPreferences {
    var diet: Diet {
        get { Diet(rawValue: dietRaw) ?? .noPreference }
        set { dietRaw = newValue.rawValue }
    }

    var intolerances: Set<Intolerance> {
        get { Set(intolerancesRaw.compactMap(Intolerance.init(rawValue:))) }
        // Sorted so the same selection always produces the same cache key.
        set { intolerancesRaw = newValue.map(\.rawValue).sorted() }
    }

    // Everything that changes what the API returns. Part of the search cache key.
    var requestKey: String {
        [dietRaw, intolerancesRaw.joined(separator: ","), excluded.sorted().joined(separator: ",")]
            .joined(separator: "|")
    }

    // Changes whenever any preference changes, so the view knows when to save.
    var signature: String {
        [requestKey, mustInclude.joined(separator: ","), String(maxMissing)].joined(separator: "|")
    }

    // e.g. "Vegan · No dairy · Excluding mushrooms", or nil when nothing is set.
    var summary: String? {
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
