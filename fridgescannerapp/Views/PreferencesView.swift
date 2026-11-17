//
//  PreferencesView.swift
//  fridgescannerapp
//
//  The household's diet rules, used by every member's recipe search. The
//  admin can change them; members see them read-only. Saved as soon as
//  anything changes.
//

import SwiftUI
import SwiftData

struct PreferencesView: View {
    @Environment(RecipeSearchModel.self) private var model
    @State private var isConfirmingReset = false

    private var canEdit: Bool {
        // Polymorphism: AdminAccount and MemberAccount answer differently
        model.account.canEditPreferences
    }

    var body: some View {
        @Bindable var preferences = model.preferences

        Form {
            if !canEdit {
                Section {
                    Label(
                        "Only \(model.household.admin?.displayName ?? "your household's admin") can change these. They apply to everyone in \(model.household.name).",
                        systemImage: "lock"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }

            Group {
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
                    IngredientListEditor(ingredients: $preferences.mustInclude, placeholder: "e.g. Chicken", canEdit: canEdit)
                } header: {
                    Text("Must Include")
                } footer: {
                    Text("Only show recipes that use all of these.")
                }

                Section {
                    IngredientListEditor(ingredients: $preferences.excluded, placeholder: "e.g. Mushrooms", canEdit: canEdit)
                } header: {
                    Text("Exclude")
                } footer: {
                    Text("Recipes with these are left out, even if they're in the fridge.")
                }

                Section {
                    Stepper(value: $preferences.maxMissing, in: 1...5) {
                        Text("Missing up to \(pluralize("ingredient", count: preferences.maxMissing))")
                    }
                } header: {
                    Text("Recipe Matching")
                } footer: {
                    Text("Recipes that need more ingredients than this are hidden.")
                }
            }
            .disabled(!canEdit)

            if canEdit {
                Section {
                    Button("Reset Preferences", role: .destructive) {
                        isConfirmingReset = true
                    }
                }
            }
        }
        .navigationTitle("Preferences")
        .onChange(of: preferences.signature) {
            model.savePreferences()
        }
        // Error prevention: confirm before clearing every rule at once.
        .confirmationDialog("Reset all preferences?", isPresented: $isConfirmingReset, titleVisibility: .visible) {
            Button("Reset Preferences", role: .destructive) {
                model.resetPreferences()
            }
        } message: {
            Text("This clears the diet, intolerances and ingredient lists for everyone in \(model.household.name).")
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

// Text field with autocomplete that edits a list of ingredient names.
private struct IngredientListEditor: View {
    @Environment(RecipeSearchModel.self) private var model
    @Binding var ingredients: [String]
    let placeholder: String
    let canEdit: Bool

    @State private var text = ""
    @State private var suggestions: [IngredientSuggestion] = []

    var body: some View {
        if canEdit {
            HStack {
                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit { add(text) }

                Button("Add") { add(text) }
                    .disabled(normalizedIngredientName(text).isEmpty)
            }
            // Debounced: each keystroke cancels the previous task.
            .task(id: text) {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                let results = await model.autocomplete(normalizedIngredientName(text))
                guard !Task.isCancelled else { return }
                suggestions = results
            }

            ForEach(suggestions) { suggestion in
                Button(suggestion.name.capitalized) {
                    add(suggestion.name)
                }
            }
        }

        if ingredients.isEmpty && !canEdit {
            Text("None")
                .foregroundStyle(.secondary)
        }

        ForEach(ingredients, id: \.self) { ingredient in
            Text(ingredient.capitalized)
        }
        .onDelete { offsets in
            ingredients.remove(atOffsets: offsets)
        }
        .deleteDisabled(!canEdit)
    }

    private func add(_ name: String) {
        let name = normalizedIngredientName(name)
        guard !name.isEmpty else { return }
        if !ingredients.contains(name) {
            ingredients.append(name)
        }
        text = ""
        suggestions = []
    }
}

#Preview {
    let session = SampleData.makePreviewSession(role: .member)
    NavigationStack {
        PreferencesView()
    }
    .modelContainer(session.container)
    .environment(RecipeSearchModel(account: session.account, household: session.account.household!, context: session.container.mainContext))
}
