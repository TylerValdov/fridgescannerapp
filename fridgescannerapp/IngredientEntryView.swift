import SwiftUI
import SwiftData

// Lets users enter and manage ingredients they currently have.
struct IngredientEntryView: View {
    @Bindable var model: RecipeSearchModel

    var body: some View {
        Form {
            Section {
                HStack {
                    TextField("e.g. Tomatoes", text: $model.newIngredientText)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit { model.addIngredient() }
                        .onChange(of: model.newIngredientText) { _, _ in
                            model.scheduleSuggestionsUpdate()
                        }

                    Button("Add", action: model.addIngredient)
                        .disabled(model.newIngredientText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if !model.suggestions.isEmpty {
                    ForEach(model.suggestions) { suggestion in
                        Button(suggestion.name.capitalized) {
                            model.selectSuggestion(suggestion)
                        }
                    }
                }
            } header: {
                Text("Add an Ingredient")
            } footer: {
                Text("Enter an ingredient you have in your fridge or pantry.")
            }

            Section("My Ingredients") {
                if model.ingredients.isEmpty {
                    Text("No ingredients added yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.ingredients, id: \.self) { ingredient in
                        Text(ingredient.capitalized)
                    }
                    .onDelete(perform: model.removeIngredients)
                }
            }
        }
        .navigationTitle("My Ingredients")
    }
}

#Preview {
    let container = try! ModelContainer(
        for: PersistedIngredient.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    NavigationStack {
        IngredientEntryView(model: RecipeSearchModel(context: container.mainContext))
    }
}
