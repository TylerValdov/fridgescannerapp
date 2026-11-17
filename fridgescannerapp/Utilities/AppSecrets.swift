//
//  AppSecrets.swift
//  fridgescannerapp
//
//  Reads the Spoonacular API key from Secrets.plist, which is gitignored.
//  Without it, the app still builds and runs, using the bundled demo data.
//

import Foundation

/// Where bundled files are loaded from. (A local Linux build swaps this
/// line for its own resource bundle; Xcode builds always use Bundle.main.)
enum AppResources {
    static let bundle = Bundle.main
}

enum AppSecrets {
    private static let placeholder = "YOUR_SPOONACULAR_API_KEY"

    /// nil when Secrets.plist is missing or still has the placeholder.
    static var spoonacularAPIKey: String? {
        guard
            let url = AppResources.bundle.url(forResource: "Secrets", withExtension: "plist"),
            let values = NSDictionary(contentsOf: url) as? [String: Any],
            let key = values["SpoonacularAPIKey"] as? String,
            !key.isEmpty,
            key != placeholder
        else { return nil }
        return key
    }
}
