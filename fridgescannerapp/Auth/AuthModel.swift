//
//  AuthModel.swift
//  fridgescannerapp
//
//  Signing in and out, creating accounts, Face ID, and the admin's
//  household management (renaming, removing members). Created once at
//  launch and shared through the environment.
//

import Foundation
import LocalAuthentication
import Observation
import OSLog
import SwiftData

enum AuthError: LocalizedError {
    case invalidCredentials
    case lockedOut
    case usernameTaken
    case inviteCodeNotFound
    case accountNotFound
    case biometricsFailed
    case invalidField(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: "That username and password don't match."
        case .lockedOut: "Too many attempts. Wait a moment, then try again."
        case .usernameTaken: "That username is taken. Try another."
        case .inviteCodeNotFound: "No household has that invite code. Check it with your household's admin."
        case .accountNotFound: "That account no longer exists. Sign in with your password."
        case .biometricsFailed: "Couldn't confirm it's you. Sign in with your password instead."
        case .invalidField(let message): message
        }
    }
}

/// How a new account gets its household.
enum HouseholdChoice {
    case create(name: String)
    case join(inviteCode: String)
}

@MainActor
@Observable
final class AuthModel {
    private static let maxFailedAttempts = 5
    private static let lockoutDuration: TimeInterval = 30
    private static let biometricUsernameKey = "biometricUsername"
    /// Sign-in events, shown in Xcode's console (filter by "auth").
    private static let log = Logger(subsystem: "fridgescannerapp", category: "auth")

    private(set) var account: Account?
    private(set) var isWorking = false
    /// While set and in the future, sign-in is blocked.
    private(set) var lockoutEndsAt: Date?
    /// The one account that can sign in with Face ID on this device.
    private(set) var biometricUsername: String?

    private var failedAttempts = 0
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        biometricUsername = UserDefaults.standard.string(forKey: AuthModel.biometricUsernameKey)
    }

    // MARK: - Signing in

    func signIn(username: String, password: String) async throws {
        if let lockoutEndsAt, lockoutEndsAt > .now { throw AuthError.lockedOut }

        isWorking = true
        defer { isWorking = false }

        let user = findUser(username: normalizedUsername(username))
        // Hash even when the username doesn't exist, so the response time
        // doesn't reveal which usernames are real.
        let credential = user?.credential ?? PasswordCredential(salt: randomBytes(count: 16), hash: Data(count: 32))
        let matches = await Task.detached { verifyPassword(password, against: credential) }.value

        guard let user, matches else {
            recordFailedAttempt()
            throw AuthError.invalidCredentials
        }

        failedAttempts = 0
        lockoutEndsAt = nil
        account = Account.make(for: user)
        AuthModel.log.info("Signed in as \(user.username, privacy: .public)")
    }

    func signOut() {
        AuthModel.log.info("Signing out \(self.account?.user.username ?? "nobody", privacy: .public)")
        account = nil
    }

    private func recordFailedAttempt() {
        failedAttempts += 1
        if failedAttempts >= AuthModel.maxFailedAttempts {
            lockoutEndsAt = Date.now.addingTimeInterval(AuthModel.lockoutDuration)
            failedAttempts = 0
        }
    }

    // MARK: - Creating an account

    func createAccount(displayName: String, username: String, password: String, household choice: HouseholdChoice) async throws {
        let username = normalizedUsername(username)
        let displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        // The screen checks these as the user types; this enforces them.
        if let problem = displayNameProblem(displayName) ?? usernameProblem(username) ?? passwordProblem(password) {
            throw AuthError.invalidField(problem)
        }
        guard findUser(username: username) == nil else { throw AuthError.usernameTaken }

        var householdToJoin: Household?
        switch choice {
        case .create(let name):
            if let problem = householdNameProblem(name) { throw AuthError.invalidField(problem) }
        case .join(let code):
            guard let household = findHousehold(inviteCode: normalizedInviteCode(code)) else {
                throw AuthError.inviteCodeNotFound
            }
            householdToJoin = household
        }

        isWorking = true
        defer { isWorking = false }
        let credential = await Task.detached { makeCredential(for: password) }.value

        let household: Household
        let role: UserRole
        if let householdToJoin {
            household = householdToJoin
            role = .member
        } else if case .create(let name) = choice {
            household = Household(name: name.trimmingCharacters(in: .whitespacesAndNewlines), inviteCode: uniqueInviteCode())
            context.insert(household)
            household.attachPreferences(MealPreferences(), in: context)
            role = .admin
        } else {
            return
        }

        let user = User(username: username, displayName: displayName, credential: credential, role: role)
        household.addMember(user, in: context)
        try context.save()
        account = Account.make(for: user)
    }

    // MARK: - Face ID / Touch ID

    /// "Face ID", "Touch ID" or "Optic ID", or nil when the device has none set up.
    var biometryName: String? {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else { return nil }
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return nil
        }
    }

    var canSignInWithBiometrics: Bool {
        biometricUsername != nil && biometryName != nil
    }

    func isBiometricSignInEnabled(for account: Account) -> Bool {
        biometricUsername == account.user.username
    }

    /// Only stores the username. The device's own Face ID check protects it.
    func setBiometricSignIn(_ isEnabled: Bool, for account: Account) {
        biometricUsername = isEnabled ? account.user.username : nil
        UserDefaults.standard.set(biometricUsername, forKey: AuthModel.biometricUsernameKey)
    }

    func signInWithBiometrics() async throws {
        guard let biometricUsername, let user = findUser(username: biometricUsername) else {
            throw AuthError.accountNotFound
        }
        do {
            _ = try await LAContext().evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Sign in to Fridge Scanner as \(user.displayName)."
            )
        } catch {
            throw AuthError.biometricsFailed
        }
        account = Account.make(for: user)
    }

    // MARK: - Household management (admins only)

    func renameHousehold(to name: String) {
        guard account?.canManageMembers == true, householdNameProblem(name) == nil,
              let household = account?.household else { return }
        household.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        try? context.save()
    }

    /// Admins can remove anyone in their household except themselves.
    func canRemove(_ member: User) -> Bool {
        guard let account, account.canManageMembers else { return false }
        return member !== account.user && member.household === account.household
    }

    func remove(_ member: User) {
        guard canRemove(member), let household = member.household else { return }
        if biometricUsername == member.username, let account {
            setBiometricSignIn(false, for: account)
        }
        household.removeMember(member, in: context)
        try? context.save()
    }

    // MARK: - Lookups

    private func findUser(username: String) -> User? {
        // Functional: filter in memory; the data set is small and this avoids
        // #Predicate quirks with optional relationships on iOS 17.
        let users = (try? context.fetch(FetchDescriptor<User>())) ?? []
        return users.first { $0.username == username }
    }

    private func findHousehold(inviteCode: String) -> Household? {
        let households = (try? context.fetch(FetchDescriptor<Household>())) ?? []
        return households.first { $0.inviteCode == inviteCode }
    }

    private func uniqueInviteCode() -> String {
        var code = makeInviteCode()
        while findHousehold(inviteCode: code) != nil {
            code = makeInviteCode()
        }
        return code
    }
}
