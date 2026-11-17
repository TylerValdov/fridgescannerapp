//
//  UndoBanner.swift
//  fridgescannerapp
//
//  A short-lived bar at the bottom of the screen with an Undo button,
//  shown after something is removed.
//

import SwiftUI

struct UndoBanner: View {
    let message: String
    let onUndo: () -> Void

    var body: some View {
        HStack {
            Text(message)
            Spacer()
            Button("Undo", action: onUndo)
                .fontWeight(.semibold)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

#Preview {
    UndoBanner(message: "Removed eggs") {}
}
