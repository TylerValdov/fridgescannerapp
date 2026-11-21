//
//  ShoppingListView.swift
//  fridgescannerapp
//
//  The Shopping tab: the household's shared list. Tap an item to check it
//  off, then move everything checked into the fridge in one step.
//

import SwiftUI

struct ShoppingListView: View {
    @Environment(ShoppingListModel.self) private var shopping
    @State private var toast: Toast?

    var body: some View {
        @Bindable var shopping = shopping

        List {
            Section {
                HStack {
                    TextField("e.g. Milk", text: $shopping.newItemText)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit { shopping.addItem() }
                        .onChange(of: shopping.newItemText) { _, _ in
                            shopping.clearEntryMessage()
                        }
                    Button("Add") { shopping.addItem() }
                        .disabled(normalizedIngredientName(shopping.newItemText).isEmpty)
                }
                if let message = shopping.entryMessage {
                    Label(message, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Add an Item")
            } footer: {
                Text("Everyone in \(shopping.household.name) shares this list.")
            }

            Section("To Buy") {
                if shopping.items.isEmpty {
                    ContentUnavailableView(
                        "Nothing to buy",
                        systemImage: "cart",
                        description: Text("Add items here, or from a recipe's missing ingredients.")
                    )
                }
                ForEach(shopping.items) { item in
                    ShoppingItemRow(item: item) {
                        withAnimation { shopping.toggle(item) }
                    }
                }
                .onDelete(perform: shopping.remove)
            }

            if shopping.checkedCount > 0 {
                Section {
                    Button("Move \(shopping.checkedCount) Checked to Fridge") {
                        let count = withAnimation(.default) { shopping.moveCheckedToFridge() }
                        toast = Toast(message: "Moved \(pluralize("item", count: count)) to the fridge", systemImage: "refrigerator")
                    }
                } footer: {
                    Text("They're added with no expiration date.")
                }
            }
        }
        .navigationTitle("Shopping List")
        .confirmationToast($toast)
    }
}

/// One checkable item. Also used by the iPad dashboard (KitchenDashboardView).
struct ShoppingItemRow: View {
    let item: ShoppingListItem
    let onToggle: () -> Void

    var body: some View {
        // The whole row is the button, so it's an easy target at the store.
        Button(action: onToggle) {
            HStack {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                Text(item.name.capitalized)
                    .strikethrough(item.isChecked)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.name.capitalized)
        .accessibilityValue(item.isChecked ? "Checked" : "Not checked")
    }
}

#Preview {
    let session = SampleData.makePreviewSession(role: .member)
    NavigationStack {
        ShoppingListView()
    }
    .previewEnvironment(session)
}
