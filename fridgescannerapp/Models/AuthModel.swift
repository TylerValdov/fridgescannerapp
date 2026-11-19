//
//  AuthModel.swift
//  fridgescannerapp
//
//  Signing in and out, creating accounts, and removing household members
//  (admins only). Created once at launch and shared through the
//  environment. Also holds the password hashing and the sign-up rules.
//

import CryptoKit
import Foundation
import Observation
import SwiftData

enum AuthError: LocalizedError {
    case invalidCredentials
    case usernameTaken
    case inviteCodeNotFound
    case invalidField(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: "That username and password don't match."
        case .usernameTaken: "That username is taken. Try another."
        case .inviteCodeNotFound: "No household has that invite code. Check it with your household's admin."
        case .invalidField(let message): message
        }
    }
}

@MainActor
@Observable
final class AuthModel {
    /// The signed-in account, or nil on the sign-in screen.
    private(set) var account: Account?

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func signIn(username: String, password: String) throws {
        guard let user = findUser(username: normalizedUsername(username)),
              verifyPassword(password, against: user.credential) else {
            throw AuthError.invalidCredentials
        }
        account = Account.make(for: user)
    }

    func signOut() {
        account = nil
    }

    /// Creates the user, plus a new household when `inviteCode` is nil.
    /// Joining makes you a member; creating makes you the admin.
    func createAccount(displayName: String, username: String, password: String, householdName: String, inviteCode: String?) throws {
        let username = normalizedUsername(username)
        let displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        // The screen checks these as the user types; this enforces them.
        if let problem = displayNameProblem(displayName) ?? usernameProblem(username) ?? passwordProblem(password) {
            throw AuthError.invalidField(problem)
        }
        guard findUser(username: username) == nil else { throw AuthError.usernameTaken }

        let household: Household
        let role: UserRole
        if let inviteCode {
            guard let existing = findHousehold(inviteCode: normalizedInviteCode(inviteCode)) else {
                throw AuthError.inviteCodeNotFound
            }
            household = existing
            role = .member
        } else {
            if let problem = householdNameProblem(householdName) { throw AuthError.invalidField(problem) }
            household = Household(name: householdName.trimmingCharacters(in: .whitespacesAndNewlines), inviteCode: uniqueInviteCode())
            context.insert(household)
            household.attachPreferences(MealPreferences(), in: context)
            role = .admin
        }

        let user = User(username: username, displayName: displayName, credential: makeCredential(for: password), role: role)
        household.addMember(user, in: context)
        try context.save()
        account = Account.make(for: user)
    }

    /// Admins can remove anyone in their household except themselves.
    func canRemove(_ member: User) -> Bool {
        guard let account, account.canManageMembers else { return false }
        return member !== account.user
    }

    func remove(_ member: User) {
        guard canRemove(member), let household = member.household else { return }
        household.removeMember(member, in: context)
        try? context.save()
    }

    // Functional: fetch everything, then search in memory. The data set is
    // small, and this avoids #Predicate quirks with optional relationships.
    private func findUser(username: String) -> User? {
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

// MARK: - Passwords

// Procedural: plain functions with no shared state.

/// What gets stored for a password: a random salt and the hash. The
/// password itself is never stored.
struct PasswordCredential {
    let salt: Data
    let hash: Data
}

func makeCredential(for password: String) -> PasswordCredential {
    // A random salt per user, so two people with the same password get different hashes.
    let salt = Data((0..<16).map { _ in UInt8.random(in: .min ... .max) })
    return PasswordCredential(salt: salt, hash: hashPassword(password, salt: salt))
}

func verifyPassword(_ password: String, against credential: PasswordCredential) -> Bool {
    hashPassword(password, salt: credential.salt) == credential.hash
}

private func hashPassword(_ password: String, salt: Data) -> Data {
    Data(SHA256.hash(data: salt + Data(password.utf8)))
}

// MARK: - Sign-up rules

// Procedural: each returns a message to show, or nil when the value is fine.
// Shared by the sign-up screen (as the user types) and AuthModel (to enforce them).

func displayNameProblem(_ name: String) -> String? {
    name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Enter your name." : nil
}

func usernameProblem(_ username: String) -> String? {
    if username.count < 3 || username.count > 20 { return "Use 3 to 20 characters." }
    if !username.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) { return "Use only letters and numbers." }
    return nil
}

func passwordProblem(_ password: String) -> String? {
    if password.count < 8 { return "Use at least 8 characters." }
    if !password.contains(where: \.isLetter) || !password.contains(where: \.isNumber) {
        return "Include at least one letter and one number."
    }
    return nil
}

func householdNameProblem(_ name: String) -> String? {
    name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Enter a household name." : nil
}

func normalizedUsername(_ username: String) -> String {
    username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
}

func normalizedInviteCode(_ code: String) -> String {
    code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
}

/// A random 6-character code without look-alike characters (no 0/O or 1/I).
func makeInviteCode() -> String {
    let characters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    return String((0..<6).map { _ in characters.randomElement()! })
}
