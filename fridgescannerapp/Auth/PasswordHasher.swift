//
//  PasswordHasher.swift
//  fridgescannerapp
//
//  Turns passwords into salted PBKDF2-SHA256 hashes and checks them.
//  The password itself is never stored.
//

import CommonCrypto
import Foundation
import Security

/// What gets stored for a password: a random salt and the derived hash.
struct PasswordCredential: Sendable {
    let salt: Data
    let hash: Data
}

// 100,000 rounds makes each guess slow for an attacker, at the cost of a
// short delay at sign-in, so these run off the main thread.
nonisolated private let pbkdf2Rounds: UInt32 = 100_000
nonisolated private let saltLength = 16
nonisolated private let hashLength = 32

// Procedural: plain functions. `nonisolated` lets AuthModel and SampleData
// run them in a background task.

nonisolated func makeCredential(for password: String) -> PasswordCredential {
    let salt = randomBytes(count: saltLength)
    return PasswordCredential(salt: salt, hash: deriveKey(from: password, salt: salt))
}

nonisolated func verifyPassword(_ password: String, against credential: PasswordCredential) -> Bool {
    constantTimeEquals(deriveKey(from: password, salt: credential.salt), credential.hash)
}

nonisolated func randomBytes(count: Int) -> Data {
    var bytes = [UInt8](repeating: 0, count: count)
    let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
    precondition(status == errSecSuccess, "Couldn't generate random bytes")
    return Data(bytes)
}

nonisolated private func deriveKey(from password: String, salt: Data) -> Data {
    var derived = [UInt8](repeating: 0, count: hashLength)
    let passwordLength = password.utf8.count

    let status = derived.withUnsafeMutableBufferPointer { derivedBuffer in
        salt.withUnsafeBytes { saltBuffer in
            password.withCString { passwordPointer in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordPointer, passwordLength,
                    saltBuffer.bindMemory(to: UInt8.self).baseAddress, salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    pbkdf2Rounds,
                    derivedBuffer.baseAddress, hashLength
                )
            }
        }
    }
    precondition(status == Int32(kCCSuccess), "PBKDF2 failed")
    return Data(derived)
}

/// Compares every byte, even after a mismatch, so the time taken doesn't
/// reveal how much of a guess was right.
nonisolated private func constantTimeEquals(_ first: Data, _ second: Data) -> Bool {
    guard first.count == second.count else { return false }
    // Functional: zip pairs the bytes and reduce folds the differences together
    return zip(first, second).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) } == 0
}
