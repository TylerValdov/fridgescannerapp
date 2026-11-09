//
//  PreferencesView.swift
//  fridgescannerapp
//

import SwiftUI
import SwiftData

// Meal preferences used by the Recipes tab. Saved as soon as anything changes.
struct PreferencesView: View {
    let model: RecipeSearchModel

    var body: some View {
        @Bindable var preferences = model.preferences

        Form {
            Section {
                Picker("Diet", selection: $preferences.diet) {
                    ForEach(Diet.allCases) { diet in
                        Text(diet.displayName).tag(diet)
                    }
                }
            } header: {
                Text("Diet")
            } footer: {
                Text(preferences.diet.explanation)
            }

            Section {
                ForEach(Intolerance.allCases) { intolerance in
                    Toggle(intolerance.displayName, isOn: binding(for: intolerance, in: preferences))
                }
            } header: {
                Text("Intolerances")
            } footer: {
                Text("Recipes containing these are left out.")
            }

            Section {
                IngredientListEditor(model: model, ingredients: $preferences.mustInclude, placeholder: "e.g. Chicken")
            } header: {
                Text("Must Include")
            } footer: {
                Text("Only show recipes that use all of these.")
            }

            Section {
                IngredientListEditor(model: model, ingredients: $preferences.excluded, placeholder: "e.g. Mushrooms")
            } header: {
                Text("Exclude")
            } footer: {
                Text("Recipes with these are left out, even if they're in your fridge.")
            }

            Section {
                Stepper(value: $preferences.maxMissing, in: 1...5) {
                    Text("Missing up to \(preferences.maxMissing) ingredient\(preferences.maxMissing == 1 ? "" : "s")")
                }
            } header: {
                Text("Recipe Matching")
            } footer: {
                Text("Recipes that need more ingredients than this are hidden.")
            }
        }
        .navigationTitle("Preferences")
        .onChange(of: preferences.signature) {
            model.savePreferences()
        }
    }

    private func binding(for intolerance: Intolerance, in preferences: MealPreferences) -> Binding<Bool> {
        Binding(
            get: { preferences.intolerances.contains(intolerance) },
            set: { isOn in
                if isOn {
                    preferences.intolerances.insert(intolerance)
                } else {
                    preferences.intolerances.remove(intolerance)
                }
            }
        )
    }
}

// Text field with Spoonacular autocomplete that edits a list of ingredient names.
private struct IngredientListEditor: View {
    let model: RecipeSearchModel
    @Binding var ingredients: [String]
    let placeholder: String

    @State private var text = ""
    @State private var suggestions: [IngredientSuggestion] = []

    var body: some View {
        HStack {
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit { add(text) }

            Button("Add") { add(text) }
                .disabled(trimmed(text).isEmpty)
        }
        // Debounced: each keystroke cancels the previous task.
        .task(id: text) {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let results = await model.autocomplete(trimmed(text))
            guard !Task.isCancelled else { return }
            suggestions = results
        }

        ForEach(suggestions) { suggestion in
            Button(suggestion.name.capitalized) {
                add(suggestion.name)
            }
        }

        ForEach(ingredients, id: \.self) { ingredient in
            Text(ingredient.capitalized)
        }
        .onDelete { offsets in
            ingredients.remove(atOffsets: offsets)
        }
    }

    private func add(_ name: String) {
        let name = trimmed(name).lowercased()
        guard !name.isEmpty else { return }
        if !ingredients.contains(name) {
            ingredients.append(name)
        }
        text = ""
        suggestions = []
    }

    private func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: PersistedIngredient.self, MealPreferences.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    NavigationStack {
        PreferencesView(model: RecipeSearchModel(context: container.mainContext))
    }
}
