//
//  SharedViews.swift
//  fridgescannerapp
//
//  Small pieces used by several screens: the Undo banner, the confirmation
//  toast, and the environment SwiftUI previews need.
//

import SwiftUI
import SwiftData

// MARK: - Undo banner

/// Golden rule "permit easy reversal": after fridge items are removed, a bar
/// with an Undo button shows for 5 seconds.
private struct FridgeUndoBanner: ViewModifier {
    @Environment(RecipeSearchModel.self) private var model

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                if let removal = model.recentlyRemoved {
                    HStack {
                        Text(removal.message)
                        Spacer()
                        Button("Undo") {
                            withAnimation { model.undoRemoval() }
                        }
                        .fontWeight(.semibold)
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: removal.id) {
                        try? await Task.sleep(for: .seconds(5))
                        withAnimation { model.dismissUndo(for: removal.id) }
                    }
                }
            }
            .animation(.default, value: model.recentlyRemoved?.id)
    }
}

// MARK: - Confirmation toast

/// Golden rule "design dialogs to yield closure": a short message after an
/// action finishes, e.g. "Saved to Favorites".
struct Toast: Equatable {
    let message: String
    let systemImage: String
}

private struct ConfirmationToast: ViewModifier {
    @Binding var toast: Toast?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let toast {
                    Label(toast.message, systemImage: toast.systemImage)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task(id: toast) {
                            try? await Task.sleep(for: .seconds(2))
                            self.toast = nil
                        }
                }
            }
            .animation(.default, value: toast)
    }
}

extension View {
    func fridgeUndoBanner() -> some View {
        modifier(FridgeUndoBanner())
    }

    func confirmationToast(_ toast: Binding<Toast?>) -> some View {
        modifier(ConfirmationToast(toast: toast))
    }

    /// For previews only: everything a signed-in screen normally gets from
    /// ContentView, using the in-memory demo data.
    func previewEnvironment(_ session: (container: ModelContainer, account: Account)) -> some View {
        let context = session.container.mainContext
        let account = session.account
        let household = account.household!
        return self
            .modelContainer(session.container)
            .environment(AuthModel(context: context))
            .environment(RecipeSearchModel(account: account, household: household, context: context))
            .environment(SavedRecipeStore(user: account.user, context: context))
            .environment(ShoppingListModel(account: account, household: household, context: context))
    }
}
