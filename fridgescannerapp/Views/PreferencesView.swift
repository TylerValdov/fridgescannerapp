//
//  PreferencesView.swift
//  fridgescannerapp
//
//  Two kinds of diet rules:
//    - Personal: your own diet and intolerances. Anyone can change theirs,
//      and recipes that conflict with them show warnings.
//    - Household: the rules every member's recipe search follows. The admin
//      can change them; members see them read-only.
//

import SwiftUI

struct PreferencesView: View {
    @Environment(RecipeSearchModel.self) private var model

    private var canEdit: Bool {
        // Polymorphism: AdminAccount and MemberAccount answer differently
        model.account.canEditPreferences
    }

    private var user: User {
        model.account.user
    }

    var body: some View {
        @Bindable var preferences = model.preferences

        Form {
            // MARK: - Personal Dietary Preferences

            Section {
                Picker("My Diet", selection: personalDietBinding) {
                    ForEach(Diet.personalOptions) { diet in
                        Text(diet.displayName).tag(diet)
                    }
                }
            } header: {
                Text("Personal Dietary Preferences")
            } footer: {
                Text(
                    "These preferences belong to your account and can be changed at any time."
                )
            }

            Section {
                ForEach(Intolerance.allCases) { intolerance in
                    Toggle(
                        intolerance.rawValue.capitalized,
                        isOn: personalIntoleranceBinding(for: intolerance)
                    )
                }
            } header: {
                Text("My Food Intolerances")
            } footer: {
                Text(
                    "Your personal dietary restrictions are used to show warnings on recipes."
                )
            }

            // MARK: - Household Preferences

            Section {
                if !canEdit {
                    Label(
                        "Only \(model.household.admin?.displayName ?? "the admin") can change household preferences.",
                        systemImage: "lock"
                    )
                    .foregroundStyle(.secondary)
                }

                Group {
                    Picker("Household Diet", selection: $preferences.diet) {
                        ForEach(Diet.allCases) { diet in
                            Text(diet.displayName).tag(diet)
                        }
                    }

                    ForEach(Intolerance.allCases) { intolerance in
                        Toggle(
                            intolerance.rawValue.capitalized,
                            isOn: binding(for: intolerance)
                        )
                    }
                }
                .disabled(!canEdit)

            } header: {
                Text("Household Dietary Preferences")
            } footer: {
                Text(
                    "These restrictions are shared by everyone in the household. Only the admin can change them."
                )
            }

            Section("Only recipes with") {
                IngredientListEditor(
                    ingredients: $preferences.mustInclude,
                    canEdit: canEdit
                )
            }

            Section("Leave out recipes with") {
                IngredientListEditor(
                    ingredients: $preferences.excluded,
                    canEdit: canEdit
                )
            }

            Section {
                Stepper(
                    "Missing up to \(pluralize("ingredient", count: preferences.maxMissing))",
                    value: $preferences.maxMissing,
                    in: 1...5
                )
                .disabled(!canEdit)
            }
        }
        .navigationTitle("Preferences")
        .onDisappear {
            model.save()
        }
    }

    // MARK: - Personal Diet Binding

    private var personalDietBinding: Binding<Diet> {
        Binding(
            get: {
                Diet(rawValue: user.personalDietRaw) ?? .noPreference
            },
            set: { newDiet in
                user.personalDietRaw = newDiet.rawValue
                model.save()
            }
        )
    }

    // MARK: - Personal Intolerance Binding

    private func personalIntoleranceBinding(
        for intolerance: Intolerance
    ) -> Binding<Bool> {
        Binding(
            get: {
                user.personalIntolerancesRaw.contains(
                    intolerance.rawValue
                )
            },
            set: { isSelected in
                user.personalIntolerancesRaw.removeAll {
                    $0 == intolerance.rawValue
                }

                if isSelected {
                    user.personalIntolerancesRaw.append(
                        intolerance.rawValue
                    )
                }

                model.save()
            }
        )
    }

    // MARK: - Household Intolerance Binding

    private func binding(
        for intolerance: Intolerance
    ) -> Binding<Bool> {
        let preferences = model.preferences

        return Binding(
            get: {
                preferences.intolerancesRaw.contains(
                    intolerance.rawValue
                )
            },
            set: { isOn in
                preferences.intolerancesRaw.removeAll {
                    $0 == intolerance.rawValue
                }

                if isOn {
                    preferences.intolerancesRaw.append(
                        intolerance.rawValue
                    )
                }
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
