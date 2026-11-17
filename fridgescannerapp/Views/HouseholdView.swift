//
//  HouseholdView.swift
//  fridgescannerapp
//
//  The household's members, the invite code, Face ID sign-in, and signing
//  out. Admins can also rename the household and remove members.
//

import SwiftUI
import SwiftData
import UIKit

struct HouseholdView: View {
    @Environment(AuthModel.self) private var auth
    @Environment(RecipeSearchModel.self) private var model
    @State private var householdName = ""
    @State private var memberToRemove: User?
    @State private var isConfirmingSignOut = false
    @State private var copiedInviteCode = false

    private var account: Account { model.account }
    private var household: Household { model.household }

    var body: some View {
        List {
            householdSection
            if account.canManageMembers {
                inviteSection
            }
            membersSection
            signInSection
        }
        .navigationTitle("Household")
        .onAppear { householdName = household.name }
        // Error prevention: removing someone can't be undone, so confirm first.
        .confirmationDialog(
            "Remove \(memberToRemove?.displayName ?? "this member")?",
            isPresented: Binding(get: { memberToRemove != nil }, set: { if !$0 { memberToRemove = nil } }),
            titleVisibility: .visible,
            presenting: memberToRemove
        ) { member in
            Button("Remove", role: .destructive) {
                auth.remove(member)
            }
        } message: { _ in
            Text("They'll lose access to this fridge, and their favorites will be deleted. They can rejoin with the invite code.")
        }
        .confirmationDialog("Sign out?", isPresented: $isConfirmingSignOut, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                auth.signOut()
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var householdSection: some View {
        Section("Household") {
            if account.canManageMembers {
                TextField("Household name", text: $householdName)
                    .submitLabel(.done)
                    .onSubmit { auth.renameHousehold(to: householdName) }
                if let problem = householdNameProblem(householdName) {
                    Text(problem)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } else {
                LabeledContent("Name", value: household.name)
            }
            LabeledContent("Your role", value: account.role.displayName)
        }
    }

    private var inviteSection: some View {
        Section {
            LabeledContent("Invite code") {
                Text(household.inviteCode)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
            }
            Button {
                UIPasteboard.general.string = household.inviteCode
                copiedInviteCode = true
            } label: {
                Label(copiedInviteCode ? "Copied" : "Copy Code", systemImage: copiedInviteCode ? "checkmark" : "doc.on.doc")
            }
            ShareLink(item: "Join \(household.name) on Fridge Scanner with invite code \(household.inviteCode).") {
                Label("Share Invite", systemImage: "square.and.arrow.up")
            }
        } header: {
            Text("Invite")
        } footer: {
            Text("New members choose \"Join with a code\" when they create an account.")
        }
    }

    private var membersSection: some View {
        Section {
            ForEach(household.sortedMembers) { member in
                MemberRow(member: member, isCurrentUser: member === account.user)
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
                Text("Swipe left on a member to remove them.")
            }
        }
    }

    private var signInSection: some View {
        Section("Sign-In") {
            if let biometryName = auth.biometryName {
                Toggle(
                    "Sign in with \(biometryName)",
                    isOn: Binding(
                        get: { auth.isBiometricSignInEnabled(for: account) },
                        set: { auth.setBiometricSignIn($0, for: account) }
                    )
                )
            }
            Button("Sign Out", role: .destructive) {
                isConfirmingSignOut = true
            }
        }
    }
}

private struct MemberRow: View {
    let member: User
    let isCurrentUser: Bool

    var body: some View {
        HStack {
            Image(systemName: member.role == .admin ? "person.crop.circle.badge.checkmark" : "person.crop.circle")
                .font(.title2)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading) {
                Text(isCurrentUser ? "\(member.displayName) (You)" : member.displayName)
                Text("@\(member.username)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(member.role.displayName)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.tint.opacity(0.15), in: Capsule())
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let session = SampleData.makePreviewSession()
    NavigationStack {
        HouseholdView()
    }
    .modelContainer(session.container)
    .environment(AuthModel(context: session.container.mainContext))
    .environment(RecipeSearchModel(account: session.account, household: session.account.household!, context: session.container.mainContext))
}
