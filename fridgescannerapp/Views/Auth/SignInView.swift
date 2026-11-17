//
//  SignInView.swift
//  fridgescannerapp
//
//  The first screen when signed out: username and password, Face ID when
//  it's been turned on, a link to create an account, and the demo accounts.
//

import SwiftUI

struct SignInView: View {
    private enum Field { case username, password }

    @Environment(AuthModel.self) private var auth
    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private var hasInput: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

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
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)

                Section {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .username)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit(signIn)
                } footer: {
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    // Re-checked every second so the countdown and button update on their own.
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let secondsLeft = auth.lockoutEndsAt.map { Int($0.timeIntervalSince(context.date).rounded(.up)) } ?? 0

                        VStack(alignment: .leading, spacing: 8) {
                            if secondsLeft > 0 {
                                Label("Too many attempts. Try again in \(secondsLeft) seconds.", systemImage: "lock.fill")
                                    .font(.footnote)
                                    .foregroundStyle(.orange)
                            }
                            Button(action: signIn) {
                                if auth.isWorking {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                } else {
                                    Text("Sign In")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!hasInput || auth.isWorking || secondsLeft > 0)
                        }
                    }

                    if auth.canSignInWithBiometrics, let biometryName = auth.biometryName {
                        Button {
                            Task { await run { try await auth.signInWithBiometrics() } }
                        } label: {
                            Label("Sign in with \(biometryName)", systemImage: biometryName == "Touch ID" ? "touchid" : "faceid")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .listRowBackground(Color.clear)

                Section {
                    NavigationLink("Create an Account") {
                        CreateAccountView()
                    }
                }

                Section {
                    Text(SampleData.demoAccountsDescription)
                        .font(.footnote)
                    Text("Password for every demo account: \(SampleData.demoPassword)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Demo Accounts")
                }
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func signIn() {
        guard hasInput else { return }
        Task { await run { try await auth.signIn(username: username, password: password) } }
    }

    /// Runs an auth action and shows its error, if any.
    private func run(_ action: () async throws -> Void) async {
        errorMessage = nil
        do {
            try await action()
        } catch {
            errorMessage = error.localizedDescription
            password = ""
        }
    }
}
