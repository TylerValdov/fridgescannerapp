//
//  Validation.swift
//  fridgescannerapp
//
//  The rules for account and household fields. Each function returns a
//  message to show the user, or nil when the value is fine.
//

import Foundation

// Procedural: one plain function per rule, shared by the sign-up screen
// (to explain problems as the user types) and AuthModel (to enforce them).

func displayNameProblem(_ name: String) -> String? {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return "Enter your name." }
    if trimmed.count > 30 { return "Use 30 characters or fewer." }
    return nil
}

func usernameProblem(_ username: String) -> String? {
    if username.count < 3 || username.count > 20 { return "Use 3 to 20 characters." }
    if !username.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) {
        return "Use only letters and numbers."
    }
    return nil
}

func passwordProblem(_ password: String) -> String? {
    if password.count < 8 { return "Use at least 8 characters." }
    if !password.contains(where: \.isLetter) { return "Include at least one letter." }
    if !password.contains(where: \.isNumber) { return "Include at least one number." }
    return nil
}

func householdNameProblem(_ name: String) -> String? {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return "Enter a household name." }
    if trimmed.count > 40 { return "Use 40 characters or fewer." }
    return nil
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
