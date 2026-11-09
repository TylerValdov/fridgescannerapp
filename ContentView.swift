//
//  ContentView.swift
//  fridgescannerapp
//
//  Created by Valdov, Tyler on 9/30/26.
//


import SwiftUI

struct ContentView: View {
    @State private var history = RecipeHistoryStore()

    var body: some View {
        HomeView(history: history)
    }
}

#Preview {
    ContentView()
}
