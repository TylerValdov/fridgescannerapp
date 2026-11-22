//
//  DietaryOnboardingView.swift
//  fridgescannerapp
//
//  Created by lending on 11/22/26.
//
//  Shown once, right after creating an account: asks for the person's own
//  diet and food intolerances. They're saved on the User, used for recipe
//  warnings, and can be changed later in Preferences.
//

import SwiftUI
import SwiftData

struct DietaryOnboardingView: View {
    @Environment(\.modelContext) private var modelContext

    let user: User

    @State private var selectedDiet: Diet = .noPreference
    @State private var selectedIntolerances: Set<Intolerance> = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Welcome to Fridge Scanner!")
                        .font(.title2.bold())

                    Text("Tell us about your dietary needs so we can help you find recipes that work for you.")
                        .foregroundStyle(.secondary)
                }

                Section {
                    Picker("Diet", selection: $selectedDiet) {
                        ForEach(Diet.personalOptions) { diet in
                            Text(diet.displayName).tag(diet)
                        }
                    }
                } header: {
                    Text("Your Diet")
                } footer: {
                    Text("Choose your primary diet, or leave it as No Preference.")
                }

                Section {
                    ForEach(Intolerance.allCases) { intolerance in
                        Toggle(
                            intolerance.rawValue.capitalized,
                            isOn: Binding(
                                get: {
                                    selectedIntolerances.contains(intolerance)
                                },
                                set: { isSelected in
                                    if isSelected {
                                        selectedIntolerances.insert(intolerance)
                                    } else {
                                        selectedIntolerances.remove(intolerance)
                                    }
                                }
                            )
                        )
                    }
                } header: {
                    Text("Food Intolerances")
                } footer: {
                    Text("Select all that apply, or leave everything unchecked.")
                }

                Section {
                    Button(action: savePreferences) {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Dietary Preferences")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func savePreferences() {
        user.personalDietRaw = selectedDiet.rawValue

        user.personalIntolerancesRaw = selectedIntolerances
            .map(\.rawValue)
            .sorted()

        user.needsDietaryOnboarding = false

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = "Could not save your preferences. Please try again."
        }
    }
}
