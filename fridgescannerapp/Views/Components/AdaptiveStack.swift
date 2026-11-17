//
//  AdaptiveStack.swift
//  fridgescannerapp
//
//  Lays content out in a row, then switches to a column at the larger
//  accessibility text sizes so nothing gets squeezed or cut off.
//

import SwiftUI

struct AdaptiveStack<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ViewBuilder let content: () -> Content

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))

        layout {
            content()
        }
    }
}
