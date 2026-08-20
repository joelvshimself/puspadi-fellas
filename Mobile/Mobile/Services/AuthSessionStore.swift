import AuthenticationServices
import CryptoKit
import Foundation
import Supabase
import SwiftUI

/// Real email/password and Sign in with Apple sessions via Supabase Auth.
@MainActor
final class AuthSessionStore: ObservableObject {
    @Published private(set) var session: Session?
    @Published var lastError: String?

    private let client = SupabaseClientProvider.shared
    private var listenTask: Task<Void, Never>?

    var isSignedIn: Bool { session != nil }
    var userId: UUID? { session?.user.id }

    init() {
        let client = self.client
        listenTask = Task { [weak self] in
            for await (_, session) in client.auth.authStateChanges {
                await MainActor.run {
                    self?.session = session
                }
            }
        }
    }

    deinit {
        listenTask?.cancel()
    }

    func emailRegistered(_ email: String) async throws -> Bool {
        struct Params: Encodable {
            let checkEmail: String
            enum CodingKeys: String, CodingKey { case checkEmail = "check_email" }
        }
        let value: Bool = try await client
            .rpc("email_registered", params: Params(checkEmail: email.trimmingCharacters(in: .whitespacesAndNewlines)))
            .execute()
            .value
        return value
    }

    func signInWithEmail(email: String, password: String) async throws {
        lastError = nil
        try await client.auth.signIn(email: email, password: password)
    }

    func signUpWithEmail(email: String, password: String) async throws -> Bool {
        lastError = nil
        let response = try await client.auth.signUp(email: email, password: password)
        if response.session != nil {
            return false
        }
        return true
    }

    func resendConfirmationEmail(email: String) async throws {
        try await client.auth.resend(email: email, type: .signup)
    }

    func signInAfterEmailConfirmed(email: String, password: String) async throws {
        lastError = nil
        try await client.auth.signIn(email: email, password: password)
    }

    func updateOnboardingProfile(displayName: String, mobilityAids: [String]) async throws {
        try await ProfileService.shared.updateOnboarding(
            displayName: displayName,
            mobilityAids: mobilityAids
        )
    }

    func signInWithApple(authorization: ASAuthorization, rawNonce: String) async throws {
        lastError = nil
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthFlowError.appleSignInFailed
        }
        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw AuthFlowError.appleSignInFailed
        }

        try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken,
                nonce: rawNonce
            )
        )

        if let fullName = credential.fullName {
            let formatted = PersonNameComponentsFormatter.localizedString(from: fullName, style: .default)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !formatted.isEmpty {
                try? await ProfileService.shared.updateDisplayName(formatted)
            }
        }
    }

    func signOut() async {
        lastError = nil
        do {
            try await client.auth.signOut()
        } catch {
            lastError = error.localizedDescription
        }
        session = nil
    }
}

enum AuthFlowError: LocalizedError {
    case appleSignInFailed

    var errorDescription: String? {
        switch self {
        case .appleSignInFailed:
            return "Sign in with Apple failed. Try again.".localized
        }
    }
}

enum AppleSignInNonce {
    static func random(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            return UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

enum AuthPasswordRules {
    static func isValid(_ password: String) -> Bool {
        guard password.count >= 8 else { return false }
        let hasNumber = password.contains { $0.isNumber }
        let hasSpecial = password.contains { !$0.isLetter && !$0.isNumber }
        return hasNumber && hasSpecial
    }

    static func looksLikeEmail(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let at = trimmed.firstIndex(of: "@") else { return false }
        let domain = trimmed[trimmed.index(after: at)...]
        return trimmed.count >= 5 && domain.contains(".")
    }
}
