//
//  AppSecrets.swift
//  fridgescannerapp
//
//  Reads the Spoonacular API key from Secrets.swift, which is gitignored.
//  Copy Secrets.swift.example to Secrets.swift before building. While the
//  key is still the placeholder, the app uses the bundled demo data.
//

import Foundation

/// Where bundled files are loaded from. (A local Linux build swaps this
/// line for its own resource bundle; Xcode builds always use Bundle.main.)
enum AppResources {
    static let bundle = Bundle.main
}

enum AppSecrets {
    private static let placeholder = "YOUR_SPOONACULAR_API_KEY"

    /// nil when Secrets.swift still has the placeholder.
    static var spoonacularAPIKey: String? {
        let key = Secrets.spoonacularAPIKey
        guard !key.isEmpty, key != placeholder else { return nil }
        return key
    }
}
