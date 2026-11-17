//
//  CreateAccountView.swift
//  fridgescannerapp
//
//  Sign-up: name, username, password, and either a new household (which
//  makes you its admin) or an invite code to join one as a member. Each
//  field explains what's wrong as you type.
//

import SwiftUI

struct CreateAccountView: View {
    private enum HouseholdMode: String, CaseIterable, Identifiable {
        case create = "Create a household"
        case join = "Join with a code"

        var id: Self { self }
    }

    @Environment(AuthModel.self) private var auth
    @State private var displayName = ""
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var mode = HouseholdMode.create
    @State private var householdName = ""
    @State private var inviteCode = ""
    @State private var errorMessage: String?

    // Each check stays quiet until the field has something in it.
    private var displayNameMessage: String? { displayName.isEmpty ? nil : displayNameProblem(displayName) }
    private var usernameMessage: String? { username.isEmpty ? nil : usernameProblem(normalizedUsername(username)) }
    private var passwordMessage: String? { password.isEmpty ? nil : passwordProblem(password) }
    private var confirmMessage: String? {
        confirmPassword.isEmpty || confirmPassword == password ? nil : "Passwords don't match."
    }
    private var householdMessage: String? {
        switch mode {
        case .create: householdName.isEmpty ? nil : householdNameProblem(householdName)
        case .join: inviteCode.isEmpty || normalizedInviteCode(inviteCode).count == 6 ? nil : "Invite codes are 6 characters."
        }
    }

    private var isValid: Bool {
        // Functional: every field must be filled in and pass its rule
        let filled = [displayName, username, password, confirmPassword, mode == .create ? householdName : inviteCode]
            .allSatisfy { !$0.isEmpty }
        let problems = [displayNameMessage, usernameMessage, passwordMessage, confirmMessage, householdMessage]
        return filled && problems.allSatisfy { $0 == nil }
    }

    var body: some View {
        Form {
            Section("About You") {
                TextField("Your name", text: $displayName)
                    .textContentType(.name)
                fieldMessage(displayNameMessage)

                TextField("Username", text: $username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                fieldMessage(usernameMessage)
            }

            Section {
                SecureField("Password", text: $password)
                    .textContentType(.newPassword)
                fieldMessage(passwordMessage)
                SecureField("Confirm password", text: $confirmPassword)
                    .textContentType(.newPassword)
                fieldMessage(confirmMessage)
            } header: {
                Text("Password")
            } footer: {
                Text("At least 8 characters, with a letter and a number.")
            }

            Section {
                Picker("Household", selection: $mode) {
                    ForEach(HouseholdMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                switch mode {
                case .create:
                    TextField("Household name, e.g. Maple St Apartment", text: $householdName)
                case .join:
                    TextField("Invite code", text: $inviteCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                }
                fieldMessage(householdMessage)
            } header: {
                Text("Household")
            } footer: {
                Text(mode == .create
                     ? "You'll be the admin: you set the diet rules and invite members."
                     : "Ask your household's admin for the code. You'll join as a member.")
            }

            Section {
                Button(action: createAccount) {
                    if auth.isWorking {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Create Account")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid || auth.isWorking)
            } footer: {
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            .listRowBackground(Color.clear)
        }
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func fieldMessage(_ message: String?) -> some View {
        if let message {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
        }
    }

    private func createAccount() {
        let choice: HouseholdChoice = mode == .create
            ? .create(name: householdName)
            : .join(inviteCode: inviteCode)

        Task {
            errorMessage = nil
            do {
                try await auth.createAccount(displayName: displayName, username: username, password: password, household: choice)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
