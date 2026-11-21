//
//  HouseholdView.swift
//  fridgescannerapp
//
//  The household's name, invite code and members, a link to the meal
//  preferences, and signing out. Admins can also rename the household and
//  remove members.
//

import SwiftUI

struct HouseholdView: View {
    @Environment(AuthModel.self) private var auth
    @Environment(RecipeSearchModel.self) private var model
    @State private var memberToRemove: User?
    @State private var householdName = ""

    private var account: Account { model.account }
    private var household: Household { model.household }

    var body: some View {
        List {
            Section("Household") {
                // Polymorphism: only AdminAccount can manage the household
                if account.canManageMembers {
                    TextField("Household name", text: $householdName)
                        .submitLabel(.done)
                        .onSubmit { auth.renameHousehold(to: householdName) }
                } else {
                    LabeledContent("Name", value: household.name)
                }
                LabeledContent("Your role", value: account.role.displayName)
                if account.canManageMembers {
                    LabeledContent("Invite code", value: household.inviteCode)
                        .textSelection(.enabled)
                }
            }

            Section {
                ForEach(household.sortedMembers) { member in
                    LabeledContent(member === account.user ? "\(member.displayName) (You)" : member.displayName,
                                   value: member.role.displayName)
                        .swipeActions {
                            if auth.canRemove(member) {
                                Button("Remove", role: .destructive) {
                                    memberToRemove = member
                                }
                            }
                        }
                }
            } header: {
                Text("Members")
            } footer: {
                if account.canManageMembers {
                    Text("Share the invite code so others can join. Swipe left on a member to remove them.")
                }
            }

            Section {
                // On iPhone this is the way to Preferences, since it isn't a tab there.
                NavigationLink {
                    PreferencesView()
                } label: {
                    Label("Meal Preferences", systemImage: "slider.horizontal.3")
                }
                Button("Sign Out", role: .destructive) {
                    auth.signOut()
                }
            }
        }
        .navigationTitle("Household")
        .onAppear { householdName = household.name }
        // Error prevention: removing someone asks first.
        .confirmationDialog(
            "Remove \(memberToRemove?.displayName ?? "member")?",
            isPresented: Binding(get: { memberToRemove != nil }, set: { if !$0 { memberToRemove = nil } }),
            titleVisibility: .visible,
            presenting: memberToRemove
        ) { member in
            Button("Remove", role: .destructive) {
                auth.remove(member)
            }
        } message: { _ in
            Text("They'll lose access to this fridge, and their favorites will be deleted.")
        }
    }
}

#Preview {
    NavigationStack {
        HouseholdView()
    }
    .previewEnvironment(SampleData.makePreviewSession())
}
