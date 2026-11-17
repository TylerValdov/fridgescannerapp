//
//  Account.swift
//  fridgescannerapp
//
//  The signed-in person and what their role allows. Views ask the account
//  ("can this person edit preferences?") instead of checking role strings.
//

import Foundation

// OOP: base class with the shared behavior. AdminAccount and MemberAccount
// override what differs, and Account.make picks the right one at sign-in, so
// the rest of the app works with `Account` alone (polymorphism).
class Account {
    let user: User

    init(user: User) {
        self.user = user
    }

    var household: Household? { user.household }
    var role: UserRole { user.role }

    var canEditPreferences: Bool { false }
    var canManageMembers: Bool { false }

    /// The line under the greeting on Home.
    var homeGreeting: String {
        "Here's what your household can cook today."
    }

    static func make(for user: User) -> Account {
        switch user.role {
        case .admin: AdminAccount(user: user)
        case .member: MemberAccount(user: user)
        }
    }
}

/// Sets up the household: diet rules, members, and the invite code.
final class AdminAccount: Account {
    override var canEditPreferences: Bool { true }
    override var canManageMembers: Bool { true }

    override var homeGreeting: String {
        "You manage this household's fridge and diet rules."
    }
}

/// Uses the shared fridge. Can view, but not change, the household's rules.
final class MemberAccount: Account {
    override var homeGreeting: String {
        guard let adminName = household?.admin?.displayName else { return super.homeGreeting }
        return "Diet rules for your household are set by \(adminName)."
    }
}
