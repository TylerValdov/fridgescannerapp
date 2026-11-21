//
//  IngredientEntryView.swift
//  fridgescannerapp
//
//  The Fridge tab: add ingredients (by typing with autocomplete, or by
//  scanning a barcode) with an optional expiration date, see who added what,
//  and swipe to remove with Undo.
//

import SwiftUI
import SwiftData

struct IngredientEntryView: View {
    @Environment(RecipeSearchModel.self) private var model
    @State private var tracksExpiration = false
    @State private var isScanning = false
    @State private var expirationDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now

    private var chosenExpiration: Date? {
        tracksExpiration ? expirationDate : nil
    }

    var body: some View {
        @Bindable var model = model

        Form {
            Section {
                HStack {
                    TextField("e.g. Tomatoes", text: $model.newIngredientText)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit { model.addIngredient(expirationDate: chosenExpiration) }
                        .onChange(of: model.newIngredientText) { _, _ in
                            model.clearEntryMessage()
                            model.scheduleSuggestionsUpdate()
                        }

                    Button("Add") { model.addIngredient(expirationDate: chosenExpiration) }
                        .disabled(model.newIngredientText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                // Only on devices with a camera; the simulator has none.
                if ScannerView.isAvailable {
                    Button("Scan a Barcode", systemImage: "barcode.viewfinder") { isScanning = true }
                }

                // Error prevention: duplicates get a visible message instead of being ignored.
                if let message = model.entryMessage {
                    Label(message, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }

                ForEach(model.suggestions) { suggestion in
                    Button(suggestion.name.capitalized) {
                        model.selectSuggestion(suggestion, expirationDate: chosenExpiration)
                    }
                }

                Toggle("Expiration date", isOn: $tracksExpiration)
                if tracksExpiration {
                    DatePicker("Expires", selection: $expirationDate, in: Date.now..., displayedComponents: .date)
                }
            } header: {
                Text("Add an Ingredient")
            } footer: {
                Text("Everyone in \(model.household.name) shares this fridge.")
            }

            Section("In the Fridge") {
                if model.items.isEmpty {
                    ContentUnavailableView(
                        "The fridge is empty",
                        systemImage: "refrigerator",
                        description: Text("Add what you have, and Recipes will show what you can make.")
                    )
                } else {
                    ForEach(model.items) { item in
                        FridgeItemRow(item: item)
                    }
                    .onDelete(perform: model.removeItems)
                }
            }
        }
        .navigationTitle("Fridge")
        .fridgeUndoBanner()
        // A scan fills in the name; the user can still edit it, set a date, then tap Add.
        .sheet(isPresented: $isScanning) {
            ScannerView { name in model.newIngredientText = name }
        }
    }
}

private struct FridgeItemRow: View {
    let item: FridgeItem

    private var isExpiring: Bool {
        item.expirationDate.map { isExpiringSoon($0) } ?? false
    }

    private var details: String {
        // Functional: compactMap drops the parts that don't apply, then join them
        [
            item.addedBy.map { "Added by \($0.firstName)" },
            item.expirationDate.map { expirationText(for: $0) }
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name.capitalized)
                if !details.isEmpty {
                    Text(details)
                        .font(.caption)
                        .foregroundStyle(isExpiring ? .red : .secondary)
                }
            }
            Spacer()
            // An icon as well as color, so the warning doesn't rely on color alone.
            if isExpiring {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .accessibilityLabel("Expiring")
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let session = SampleData.makePreviewSession()
    NavigationStack {
        IngredientEntryView()
    }
    .previewEnvironment(session)
}
