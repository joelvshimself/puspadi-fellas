import AuthenticationServices
import CryptoKit
import Foundation
import Supabase
import SwiftUI

/// Apple identity captured on first authorization; Supabase sign-in waits until onboarding finishes.
struct PendingAppleSignIn: Equatable {
    let idToken: String
    let rawNonce: String
    let appleEmail: String?
    let fullName: String
    let givenName: String?
    let familyName: String?
}

/// Real email/password and Sign in with Apple sessions via Supabase Auth.
@MainActor
final class AuthSessionStore: ObservableObject {
    @Published private(set) var session: Session?
    @Published var lastError: String?

    private let client = SupabaseClientProvider.shared
    private var listenTask: Task<Void, Never>?

    var isSignedIn: Bool { session != nil }
    var userId: UUID? { session?.user.id }
    var userEmail: String? {
        session?.user.email?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    /// Email/password identities can change password; Apple-only accounts cannot.
    var canChangePassword: Bool {
        guard let identities = session?.user.identities else { return false }
        return identities.contains { $0.provider == "email" }
    }

    init() {
        let client = self.client
        listenTask = Task { [weak self] in
            for await (event, session) in client.auth.authStateChanges {
                await MainActor.run {
                    AuthDebug.log("authStateChanges event=\(event) session=\(session?.user.id.uuidString ?? "nil")")
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
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            redirectTo: SupabaseConfig.authRedirectURL
        )
        if response.session != nil {
            return false
        }
        return true
    }

    /// Registers the account and saves onboarding when a session is returned immediately.
    /// Returns `.needsEmailConfirmation` when Supabase sends a confirmation link instead.
    func registerEmailAccount(
        email: String,
        password: String,
        displayName: String,
        mobilityAids: [String]
    ) async throws -> EmailSignupResult {
        lastError = nil
        AuthDebug.log("registerEmailAccount email=\(email) passwordLen=\(password.count) name=\(displayName) aids=\(mobilityAids)")
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            redirectTo: SupabaseConfig.authRedirectURL
        )
        AuthDebug.log(
            "signUp response user=\(response.user.id.uuidString) "
            + "session=\(response.session != nil ? "yes" : "no") "
            + "confirmed=\(response.user.emailConfirmedAt != nil)"
        )
        if let newSession = response.session {
            session = newSession
            AuthDebug.log("registerEmailAccount saving profile (immediate session)")
            try await updateOnboardingProfile(displayName: displayName, mobilityAids: mobilityAids)
            AuthDebug.log("registerEmailAccount complete → ready")
            return .ready
        }
        AuthDebug.log("registerEmailAccount complete → needsEmailConfirmation")
        return .needsEmailConfirmation
    }

    func finishEmailOnboardingAfterConfirm(
        displayName: String,
        mobilityAids: [String]
    ) async throws {
        try await updateOnboardingProfile(displayName: displayName, mobilityAids: mobilityAids)
    }

    func resendConfirmationEmail(email: String) async throws {
        try await client.auth.resend(
            email: email,
            type: .signup,
            emailRedirectTo: SupabaseConfig.authRedirectURL
        )
    }

    /// Handles `puspadi://auth/callback` after the user taps the confirmation email link.
    func handleAuthCallback(_ url: URL) async {
        guard url.scheme == SupabaseConfig.authRedirectURL.scheme else { return }
        AuthDebug.log("handleAuthCallback url=\(url.absoluteString)")
        do {
            _ = try await client.auth.session(from: url)
            AuthDebug.log("handleAuthCallback session established")
        } catch {
            // Email may already be confirmed even if tokens aren't in the URL —
            // AuthVerifyEmailView can still sign in with password.
            AuthDebug.log("handleAuthCallback session(from:) failed: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }
    }

    func signInAfterEmailConfirmed(email: String, password: String) async throws {
        lastError = nil
        try await client.auth.signIn(email: email, password: password)
    }

    func updateOnboardingProfile(displayName: String, mobilityAids: [String]) async throws {
        AuthDebug.log("updateOnboardingProfile name=\(displayName) aids=\(mobilityAids) userId=\(userId?.uuidString ?? "nil")")
        try await ProfileService.shared.updateOnboarding(
            displayName: displayName,
            mobilityAids: mobilityAids
        )
        AuthDebug.log("updateOnboardingProfile success")
    }

    func profileNeedsOnboarding() async -> Bool {
        guard isSignedIn else { return true }
        guard let profile = try? await ProfileService.shared.fetchCurrent() else { return true }
        return profile.needsOnboarding
    }

    static func pendingAppleSignIn(
        from authorization: ASAuthorization,
        rawNonce: String
    ) throws -> (PendingAppleSignIn, String?) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthFlowError.appleSignInFailed
        }
        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw AuthFlowError.appleSignInFailed
        }

        let appleEmail = credential.email?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullName = credential.fullName
        let formattedName = fullName.map {
            PersonNameComponentsFormatter.localizedString(from: $0, style: .default)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } ?? ""

        let pending = PendingAppleSignIn(
            idToken: idToken,
            rawNonce: rawNonce,
            appleEmail: appleEmail,
            fullName: formattedName,
            givenName: fullName?.givenName,
            familyName: fullName?.familyName
        )
        let suggestedName = formattedName.isEmpty ? nil : formattedName
        return (pending, suggestedName)
    }

    /// First-time Apple: no Supabase calls until mobility Continue.
    func completeAppleSignup(
        pending: PendingAppleSignIn,
        displayName: String,
        mobilityAids: [String]
    ) async throws {
        lastError = nil
        let newSession = try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: pending.idToken,
                nonce: pending.rawNonce
            )
        )
        session = newSession

        var metadata: [String: AnyJSON] = [:]
        let resolvedName = displayName.isEmpty ? pending.fullName : displayName
        if !resolvedName.isEmpty {
            metadata["full_name"] = .string(resolvedName)
        }
        if let givenName = pending.givenName {
            metadata["given_name"] = .string(givenName)
        }
        if let familyName = pending.familyName {
            metadata["family_name"] = .string(familyName)
        }
        if let appleEmail = pending.appleEmail, !appleEmail.isEmpty {
            metadata["email"] = .string(appleEmail)
        }
        if !metadata.isEmpty {
            _ = try? await client.auth.update(user: UserAttributes(data: metadata))
        }

        try await updateOnboardingProfile(
            displayName: resolvedName.isEmpty ? "You" : resolvedName,
            mobilityAids: mobilityAids
        )
    }

    /// Returning Apple user — sign in only, then route by onboarding state.
    @discardableResult
    func signInWithAppleReturningUser(
        authorization: ASAuthorization,
        rawNonce: String
    ) async throws -> String? {
        lastError = nil
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthFlowError.appleSignInFailed
        }
        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw AuthFlowError.appleSignInFailed
        }

        AuthDebug.log("signInWithAppleReturningUser starting")
        let newSession = try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken,
                nonce: rawNonce
            )
        )
        session = newSession
        AuthDebug.log("signInWithAppleReturningUser session user=\(newSession.user.id.uuidString)")
        return nil
    }

    /// True when Apple returned name or email — only happens on first authorization.
    static func isFirstAppleAuthorization(_ authorization: ASAuthorization) -> Bool {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            return false
        }
        if let email = credential.email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            return true
        }
        if let fullName = credential.fullName {
            let formatted = PersonNameComponentsFormatter.localizedString(from: fullName, style: .default)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !formatted.isEmpty { return true }
        }
        return false
    }

    func updatePassword(newPassword: String) async throws {
        lastError = nil
        guard AuthPasswordRules.isValid(newPassword) else {
            throw AuthFlowError.invalidPassword
        }
        _ = try await client.auth.update(user: UserAttributes(password: newPassword))
    }

    func updateMobilityProfile(_ profile: MobilityProfile) async throws {
        lastError = nil
        try await ProfileService.shared.updateMobilityAids(profile.storageAids)
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

enum AuthDebug {
    static func log(_ message: String, file: String = #file, line: Int = #line) {
        #if DEBUG
        let name = (file as NSString).lastPathComponent
        print("[Auth] \(name):\(line) \(message)")
        #endif
    }
}

enum EmailSignupResult {
    case ready
    case needsEmailConfirmation
}

enum AuthFlowError: LocalizedError {
    case appleSignInFailed
    case invalidPassword

    var errorDescription: String? {
        switch self {
        case .appleSignInFailed:
            return "Sign in with Apple failed. Try again.".localized
        case .invalidPassword:
            return "Use at least 8 characters, including a number and a special character.".localized
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
