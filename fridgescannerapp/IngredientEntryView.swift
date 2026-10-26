import SwiftUI

// Lets users enter and manage ingredients they currently have.
struct IngredientEntryView: View {
    @State private var ingredientName = ""
    @State private var ingredients: [String] = []

    var body: some View {
        Form {
            Section {
                HStack {
                    TextField("e.g. Tomatoes", text: $ingredientName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit(addIngredient)

                    Button("Add", action: addIngredient)
                        .disabled(ingredientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } header: {
                Text("Add an Ingredient")
            } footer: {
                Text("Enter an ingredient you have in your fridge or pantry.")
            }

            Section("My Ingredients") {
                if ingredients.isEmpty {
                    Text("No ingredients added yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(ingredients, id: \.self) { ingredient in
                        Text(ingredient)
                    }
                    .onDelete(perform: removeIngredients)
                }
            }
        }
        .navigationTitle("My Ingredients")
    }

    private func addIngredient() {
        let name = ingredientName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        // Don't add the same ingredient twice, even with different capitalization.
        guard !ingredients.contains(where: { $0.localizedCaseInsensitiveCompare(name) == .orderedSame }) else {
            ingredientName = ""
            return
        }

        ingredients.append(name)
        ingredientName = ""
    }

    private func removeIngredients(at offsets: IndexSet) {
        ingredients.remove(atOffsets: offsets)
    }
}

#Preview {
    NavigationStack {
        IngredientEntryView()
    }
}
