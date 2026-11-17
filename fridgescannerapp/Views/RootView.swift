//
//  RootView.swift
//  fridgescannerapp
//
//  Decides what the app shows: a loading screen while the demo data is set
//  up on first launch, the sign-in screens, or the main app.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var auth: AuthModel?

    var body: some View {
        Group {
            if let auth {
                if let account = auth.account {
                    // A new Account object per sign-in, so each user starts fresh.
                    ContentView(account: account)
                        .id(ObjectIdentifier(account))
                } else {
                    SignInView()
                }
            } else {
                ProgressView("Setting up sample households…")
                    .task {
                        await SampleData.seedIfNeeded(in: modelContext)
                        auth = AuthModel(context: modelContext)
                    }
            }
        }
        .environment(auth)
    }
}
