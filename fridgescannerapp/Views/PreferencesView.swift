//
//  PreferencesView.swift
//  fridgescannerapp
//
//  The household's diet rules, used by every member's recipe search. The
//  admin can change them; members see them read-only.
//

import SwiftUI

struct PreferencesView: View {
    @Environment(RecipeSearchModel.self) private var model

    private var canEdit: Bool {
        // Polymorphism: AdminAccount and MemberAccount answer differently
        model.account.canEditPreferences
    }

    var body: some View {
        @Bindable var preferences = model.preferences

        Form {
            if !canEdit {
                Label("Only \(model.household.admin?.displayName ?? "the admin") can change these.", systemImage: "lock")
                    .foregroundStyle(.secondary)
            }

            Group {
                Picker("Diet", selection: $preferences.diet) {
                    ForEach(Diet.allCases) { diet in
                        Text(diet.displayName).tag(diet)
                    }
                }

                Section {
                    ForEach(Intolerance.allCases) { intolerance in
                        Toggle(intolerance.rawValue.capitalized, isOn: binding(for: intolerance))
                    }
                } header: {
                    Text("Intolerances")
                } footer: {
                    Text("Recipes containing these are left out.")
                }

                Section("Only recipes with") {
                    IngredientListEditor(ingredients: $preferences.mustInclude, canEdit: canEdit)
                }

                Section("Leave out recipes with") {
                    IngredientListEditor(ingredients: $preferences.excluded, canEdit: canEdit)
                }

                Stepper("Missing up to \(pluralize("ingredient", count: preferences.maxMissing))",
                        value: $preferences.maxMissing, in: 1...5)
            }
            .disabled(!canEdit)
        }
        .navigationTitle("Preferences")
        .onDisappear { model.save() }
    }

    private func binding(for intolerance: Intolerance) -> Binding<Bool> {
        let preferences = model.preferences
        return Binding(
            get: { preferences.intolerancesRaw.contains(intolerance.rawValue) },
            set: { isOn in
                preferences.intolerancesRaw.removeAll { $0 == intolerance.rawValue }
                if isOn { preferences.intolerancesRaw.append(intolerance.rawValue) }
            }
        )
    }
}

/// A text field with autocomplete that edits a list of ingredient names.
private struct IngredientListEditor: View {
    @Environment(RecipeSearchModel.self) private var model
    @Binding var ingredients: [String]
    let canEdit: Bool

    @State private var text = ""
    @State private var suggestions: [IngredientSuggestion] = []

    var body: some View {
        if canEdit {
            HStack {
                TextField("Ingredient", text: $text)
                    .autocorrectionDisabled()
                    .onSubmit { add(text) }
                Button("Add") { add(text) }
                    .disabled(normalizedIngredientName(text).isEmpty)
            }
            // Waits until typing pauses: each keystroke restarts this task.
            .task(id: text) {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                suggestions = await model.autocomplete(text)
            }

            ForEach(suggestions) { suggestion in
                Button(suggestion.name.capitalized) { add(suggestion.name) }
            }
        }

        if ingredients.isEmpty && !canEdit {
            Text("None")
                .foregroundStyle(.secondary)
        }
        ForEach(ingredients, id: \.self) { ingredient in
            Text(ingredient.capitalized)
        }
        .onDelete { ingredients.remove(atOffsets: $0) }
        .deleteDisabled(!canEdit)
    }

    private func add(_ name: String) {
        let name = normalizedIngredientName(name)
        if !name.isEmpty && !ingredients.contains(name) {
            ingredients.append(name)
        }
        text = ""
        suggestions = []
    }
}

#Preview {
    NavigationStack {
        PreferencesView()
    }
    .previewEnvironment(SampleData.makePreviewSession(role: .member))
}
