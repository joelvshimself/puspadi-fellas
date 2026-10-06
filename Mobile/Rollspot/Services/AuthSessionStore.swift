import AuthenticationServices
import CryptoKit
import Foundation
import GoogleSignIn
import SwiftUI
import UIKit

struct PendingAppleSignIn: Equatable {
    let idToken: String
    let rawNonce: String
    let appleEmail: String?
    let fullName: String
    let givenName: String?
    let familyName: String?
}

struct AppSession: Equatable {
    let userId: String
    let email: String
}

private struct AuthUser: Decodable {
    let id: String
    let email: String
}

private struct AuthResponse: Decodable { let user: AuthUser? }
private struct SessionResponse: Decodable { let user: AuthUser? }
private struct EmailRegisteredResponse: Decodable { let registered: Bool }
private struct ProvidersResponse: Decodable { let providers: [String] }
private struct EmailBody: Encodable { let email: String }
private struct EmailPasswordBody: Encodable { let email: String; let password: String }

private struct EmailSignupBody: Encodable {
    let name: String
    let email: String
    let password: String
    let callbackURL: String
}

private struct VerificationEmailBody: Encodable {
    let email: String
    let callbackURL: String
}

private struct SocialSignInBody: Encodable {
    struct IdentityToken: Encodable {
        let token: String
        let nonce: String?
    }
    let provider: String
    let idToken: IdentityToken
}

private struct ChangePasswordBody: Encodable {
    let currentPassword: String
    let newPassword: String
    let revokeOtherSessions: Bool
}

/// App authentication backed by Better Auth on the Cloudflare Worker.
@MainActor
final class AuthSessionStore: ObservableObject {
    @Published private(set) var session: AppSession?
    @Published var lastError: String?
    @Published private(set) var providers: Set<String> = []

    private let client = CloudflareAPIClient.shared
    private var authActionInFlight = false

    var isSignedIn: Bool { session != nil }
    var userId: UUID? { session.flatMap { UUID(uuidString: $0.userId) } }
    var userEmail: String? { session?.email.trimmingCharacters(in: .whitespacesAndNewlines) }
    var canChangePassword: Bool { providers.contains("credential") }

    init() {
        Task { await restoreSession() }
    }

    func emailRegistered(_ email: String) async throws -> Bool {
        let response: EmailRegisteredResponse = try await client.post(
            ["v1", "auth", "email-registered"],
            body: EmailBody(email: normalizedEmail(email))
        )
        return response.registered
    }

    func signInWithEmail(email: String, password: String) async throws {
        try beginAuthAction()
        defer { authActionInFlight = false }
        lastError = nil
        let response: AuthResponse = try await client.post(
            ["api", "auth", "sign-in", "email"],
            body: EmailPasswordBody(email: normalizedEmail(email), password: password),
            capturesSession: true
        )
        try await accept(response.user)
        providers.insert("credential")
    }

    func signUpWithEmail(email: String, password: String) async throws -> Bool {
        _ = try await signUp(email: email, password: password, displayName: "You")
        return true
    }

    func registerEmailAccount(
        email: String,
        password: String,
        displayName: String,
        mobilityAids: [String]
    ) async throws -> EmailSignupResult {
        try beginAuthAction()
        defer { authActionInFlight = false }
        lastError = nil
        _ = try await signUp(email: email, password: password, displayName: displayName)
        return .needsEmailConfirmation
    }

    private func signUp(email: String, password: String, displayName: String) async throws -> AuthResponse {
        try await client.post(
            ["api", "auth", "sign-up", "email"],
            body: EmailSignupBody(
                name: displayName,
                email: normalizedEmail(email),
                password: password,
                callbackURL: CloudflareConfig.authCallbackURL.absoluteString
            )
        )
    }

    func finishEmailOnboardingAfterConfirm(displayName: String, mobilityAids: [String]) async throws {
        try await updateOnboardingProfile(displayName: displayName, mobilityAids: mobilityAids)
    }

    func resendConfirmationEmail(email: String) async throws {
        let _: AuthResponse = try await client.post(
            ["api", "auth", "send-verification-email"],
            body: VerificationEmailBody(
                email: normalizedEmail(email),
                callbackURL: CloudflareConfig.authCallbackURL.absoluteString
            )
        )
    }

    func handleAuthCallback(_ url: URL) async {
        guard url.scheme == CloudflareConfig.authCallbackURL.scheme else { return }
        await restoreSession()
    }

    func signInAfterEmailConfirmed(email: String, password: String) async throws {
        try await signInWithEmail(email: email, password: password)
    }

    func updateOnboardingProfile(displayName: String, mobilityAids: [String]) async throws {
        try await ProfileService.shared.updateOnboarding(displayName: displayName, mobilityAids: mobilityAids)
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
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw AuthFlowError.appleSignInFailed
        }
        let fullName = credential.fullName.map {
            PersonNameComponentsFormatter.localizedString(from: $0, style: .default)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } ?? ""
        let pending = PendingAppleSignIn(
            idToken: idToken,
            rawNonce: rawNonce,
            appleEmail: credential.email?.trimmingCharacters(in: .whitespacesAndNewlines),
            fullName: fullName,
            givenName: credential.fullName?.givenName,
            familyName: credential.fullName?.familyName
        )
        return (pending, fullName.isEmpty ? nil : fullName)
    }

    func completeAppleSignup(
        pending: PendingAppleSignIn,
        displayName: String,
        mobilityAids: [String]
    ) async throws {
        try beginAuthAction()
        defer { authActionInFlight = false }
        let user = try await socialSignIn(provider: "apple", token: pending.idToken, nonce: pending.rawNonce)
        try await accept(user)
        providers.insert("apple")
        let name = displayName.isEmpty ? (pending.fullName.isEmpty ? "You" : pending.fullName) : displayName
        try await updateOnboardingProfile(displayName: name, mobilityAids: mobilityAids)
    }

    @discardableResult
    func signInWithAppleReturningUser(
        authorization: ASAuthorization,
        rawNonce: String
    ) async throws -> String? {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw AuthFlowError.appleSignInFailed
        }
        try beginAuthAction()
        defer { authActionInFlight = false }
        let user = try await socialSignIn(provider: "apple", token: idToken, nonce: rawNonce)
        try await accept(user)
        providers.insert("apple")
        return nil
    }

    /// Returns Google's display name so a new account can prefill onboarding.
    func signInWithGoogle() async throws -> String? {
        try beginAuthAction()
        defer { authActionInFlight = false }
        guard !CloudflareConfig.googleClientID.isEmpty else { throw AuthFlowError.googleNotConfigured }
        guard let presenter = Self.presentingViewController() else { throw AuthFlowError.googleSignInFailed }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: CloudflareConfig.googleClientID)
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        guard let idToken = result.user.idToken?.tokenString else { throw AuthFlowError.googleSignInFailed }
        let user = try await socialSignIn(provider: "google", token: idToken, nonce: nil)
        try await accept(user)
        providers.insert("google")
        return result.user.profile?.name
    }

    private func socialSignIn(provider: String, token: String, nonce: String?) async throws -> AuthUser? {
        let response: AuthResponse = try await client.post(
            ["api", "auth", "sign-in", "social"],
            body: SocialSignInBody(provider: provider, idToken: .init(token: token, nonce: nonce)),
            capturesSession: true
        )
        return response.user
    }

    static func isFirstAppleAuthorization(_ authorization: ASAuthorization) -> Bool {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return false }
        let hasEmail = !(credential.email?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let name = credential.fullName.map {
            PersonNameComponentsFormatter.localizedString(from: $0, style: .default)
        } ?? ""
        return hasEmail || !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func updatePassword(currentPassword: String, newPassword: String) async throws {
        guard AuthPasswordRules.isValid(newPassword) else { throw AuthFlowError.invalidPassword }
        let _: AuthResponse = try await client.post(
            ["api", "auth", "change-password"],
            body: ChangePasswordBody(
                currentPassword: currentPassword,
                newPassword: newPassword,
                revokeOtherSessions: true
            ),
            authenticated: true
        )
    }

    func updateMobilityProfile(_ profile: MobilityProfile) async throws {
        try await ProfileService.shared.updateMobilityAids(profile.storageAids)
    }

    func signOut() async {
        lastError = nil
        try? await client.send(["api", "auth", "sign-out"], method: "POST", authenticated: true)
        AuthTokenStore.clear()
        GIDSignIn.sharedInstance.signOut()
        session = nil
        providers = []
        NotificationCenter.default.post(name: .rollspotAuthStateDidChange, object: nil)
    }

    private func restoreSession() async {
        guard AuthTokenStore.load() != nil else { return }
        do {
            let response: SessionResponse = try await client.get(
                ["api", "auth", "get-session"],
                authenticated: true
            )
            try await accept(response.user)
        } catch {
            AuthTokenStore.clear()
            session = nil
        }
    }

    private func accept(_ user: AuthUser?) async throws {
        guard let user else { throw APIClientError.missingSessionToken }
        session = AppSession(userId: user.id, email: user.email)
        if let response: ProvidersResponse = try? await client.get(
            ["v1", "auth", "providers"],
            authenticated: true
        ) {
            providers = Set(response.providers)
        }
        NotificationCenter.default.post(name: .rollspotAuthStateDidChange, object: nil)
    }

    private func beginAuthAction() throws {
        if authActionInFlight { throw AuthFlowError.actionInProgress }
        authActionInFlight = true
    }

    private func normalizedEmail(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func presentingViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        var controller = scenes.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController
        while let presented = controller?.presentedViewController { controller = presented }
        return controller
    }
}

enum AuthDebug {
    static func log(_ message: String, file: String = #file, line: Int = #line) {
        #if DEBUG
        print("[Auth] \((file as NSString).lastPathComponent):\(line) \(message)")
        #endif
    }
}

enum EmailSignupResult { case ready, needsEmailConfirmation }

enum AuthFlowError: LocalizedError {
    case appleSignInFailed
    case googleSignInFailed
    case googleNotConfigured
    case invalidPassword
    case actionInProgress

    var errorDescription: String? {
        switch self {
        case .appleSignInFailed: "Sign in with Apple failed. Try again.".localized
        case .googleSignInFailed: "Sign in with Google failed. Try again.".localized
        case .googleNotConfigured: "Google Sign-In has not been configured yet.".localized
        case .invalidPassword: "Use at least 8 characters, including a number and a special character.".localized
        case .actionInProgress: "Please wait for the current sign-in to finish.".localized
        }
    }
}

enum AppleSignInNonce {
    static func random(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
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
        password.count >= 8
            && password.contains(where: \.isNumber)
            && password.contains { !$0.isLetter && !$0.isNumber }
    }

    static func looksLikeEmail(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let at = trimmed.firstIndex(of: "@") else { return false }
        return trimmed.count >= 5 && trimmed[trimmed.index(after: at)...].contains(".")
    }
}
