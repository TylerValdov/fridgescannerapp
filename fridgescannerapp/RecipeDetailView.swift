
import SwiftUI

struct RecipeDetailView: View {
    let recipe: RecipeMatch

    @State private var details: RecipeDetails?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let service = SpoonacularService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                recipeImage

                VStack(alignment: .leading, spacing: 8) {
                    Text(details?.title ?? recipe.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    HStack(spacing: 16) {
                        if let minutes = details?.readyInMinutes {
                            Label(
                                "\(minutes) min",
                                systemImage: "clock"
                            )
                        }

                        if let servings = details?.servings {
                            Label(
                                "\(servings) servings",
                                systemImage: "person.2"
                            )
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                if isLoading {
                    ProgressView("Loading recipe details...")
                        .frame(maxWidth: .infinity)
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)

                    Button("Try Again") {
                        Task {
                            await loadDetails()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let details {
                    if let summary = details.summary,
                       !summary.isEmpty {
                        sectionTitle("About This Recipe")

                        Text(cleanHTML(summary))
                            .font(.body)
                    }

                    sectionTitle("Ingredients")

                    if let ingredients = details.extendedIngredients,
                       !ingredients.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(ingredients) { ingredient in
                                Label(
                                    ingredient.original,
                                    systemImage: "circle"
                                )
                                .font(.body)
                            }
                        }
                    } else {
                        Text("Ingredient details are unavailable.")
                            .foregroundStyle(.secondary)
                    }

                    sectionTitle("Cooking Instructions")

                    if let instructions = details.instructions,
                       !cleanHTML(instructions).isEmpty {
                        Text(cleanHTML(instructions))
                            .font(.body)
                            .lineSpacing(5)
                    } else {
                        Text(
                            "Cooking instructions are not available for this recipe."
                        )
                        .foregroundStyle(.secondary)
                    }

                    if let source = details.sourceUrl,
                       let url = URL(string: source) {
                        Link(
                            "View Original Recipe",
                            destination: url
                        )
                        .font(.headline)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Recipe Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDetails()
        }
    }

    private var recipeImage: some View {
        AsyncImage(
            url: URL(
                string: details?.image ?? recipe.image
            )
        ) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            ZStack {
                Color.secondary.opacity(0.15)
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title2)
            .fontWeight(.semibold)
            .padding(.top, 4)
    }

    private func loadDetails() async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            details = try await service.getRecipeDetails(
                id: recipe.id
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cleanHTML(_ html: String) -> String {
        guard let data = html.data(using: .utf8) else {
            return html
        }

        guard let attributed = try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        ) else {
            return html
                .replacingOccurrences(
                    of: "<[^>]+>",
                    with: " ",
                    options: .regularExpression
                )
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return attributed.string
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
