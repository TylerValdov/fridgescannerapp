//
//  fridgescannerappApp.swift
//  fridgescannerapp
//
//  Created by Valdov, Tyler on 9/30/26.
//

import SwiftUI
import SwiftData

@main
struct fridgescannerappApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: PersistedIngredient.self)
    }
}
