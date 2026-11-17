//
//  EmptyStateView.swift
//  fridgescannerapp
//
//  A friendly placeholder for screens with nothing to show yet: a large
//  symbol in a tinted circle, an optional badge, a title and a hint.
//

import SwiftUI

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let message: String
    var badgeSystemImage: String?

    // Grows with the user's text size.
    @ScaledMetric(relativeTo: .largeTitle) private var circleSize: CGFloat = 88

    var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: systemImage)
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                    .frame(width: circleSize, height: circleSize)
                    .background(.tint.opacity(0.12), in: Circle())

                if let badgeSystemImage {
                    Image(systemName: badgeSystemImage)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(.tint, in: Circle())
                }
            }
            .accessibilityHidden(true)

            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    EmptyStateView(
        title: "The fridge is empty",
        systemImage: "refrigerator",
        message: "Add what you have, and Recipes will show what you can make.",
        badgeSystemImage: "plus"
    )
}
