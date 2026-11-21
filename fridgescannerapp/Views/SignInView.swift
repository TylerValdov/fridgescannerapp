//
//  SignInView.swift
//  fridgescannerapp
//
//  The screens shown when signed out: sign in with a username and password,
//  or create an account that starts a new household (as its admin) or joins
//  one with an invite code (as a member).
//

import SwiftUI

struct SignInView: View {
    @Environment(AuthModel.self) private var auth
    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "refrigerator.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)
                        Text("Fridge Scanner")
                            .font(.largeTitle.bold())
                        Text("Cook with what your household already has.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.clear)

                Section {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .onSubmit(signIn)
                } footer: {
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button(action: signIn) {
                        Text("Sign In")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(username.isEmpty || password.isEmpty)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section {
                    NavigationLink("Create an Account") {
                        CreateAccountView()
                    }
                }

                Section("Demo Accounts") {
                    Text(SampleData.demoAccountsDescription)
                    Text("Password for every demo account: \(SampleData.demoPassword)")
                        .foregroundStyle(.secondary)
                }
                .font(.footnote)
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func signIn() {
        do {
            try auth.signIn(username: username, password: password)
        } catch {
            errorMessage = error.localizedDescription
            password = ""
        }
    }
}

struct CreateAccountView: View {
    @Environment(AuthModel.self) private var auth
    @State private var displayName = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isJoining = false
    @State private var householdName = ""
    @State private var inviteCode = ""
    @State private var errorMessage: String?

    // Error prevention: each rule is explained as you type, and stays quiet
    // until the field has something in it.
    private var usernameMessage: String? { username.isEmpty ? nil : usernameProblem(normalizedUsername(username)) }
    private var passwordMessage: String? { password.isEmpty ? nil : passwordProblem(password) }

    private var isValid: Bool {
        // Functional: every field must be filled in, and no rule may complain
        let fields = [displayName, username, password, isJoining ? inviteCode : householdName]
        return fields.allSatisfy { !$0.isEmpty } && usernameMessage == nil && passwordMessage == nil
    }

    var body: some View {
        Form {
            Section("About You") {
                TextField("Your name", text: $displayName)
                    .textContentType(.name)
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                fieldMessage(usernameMessage)
                SecureField("Password (8+ characters, a letter and a number)", text: $password)
                    .textContentType(.newPassword)
                fieldMessage(passwordMessage)
            }

            Section {
                Picker("Household", selection: $isJoining) {
                    Text("Create a household").tag(false)
                    Text("Join with a code").tag(true)
                }
                .pickerStyle(.segmented)

                if isJoining {
                    TextField("Invite code", text: $inviteCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                } else {
                    TextField("Household name, e.g. Maple St Apartment", text: $householdName)
                }
            } header: {
                Text("Household")
            } footer: {
                Text(isJoining
                     ? "Ask your household's admin for the code. You'll join as a member."
                     : "You'll be the admin: you set the diet rules and can remove members.")
            }

            Section {
                Button("Create Account", action: createAccount)
                    .frame(maxWidth: .infinity)
                    .disabled(!isValid)
            } footer: {
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
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
        do {
            try auth.createAccount(
                displayName: displayName,
                username: username,
                password: password,
                householdName: householdName,
                inviteCode: isJoining ? inviteCode : nil
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    SignInView()
        .previewEnvironment(SampleData.makePreviewSession())
}
