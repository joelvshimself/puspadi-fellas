import AuthenticationServices
import CryptoKit
import Foundation
import GoogleSignIn
import Shared
import SwiftUI
import UIKit

struct AppSession: Equatable {
    let userId: String
    let email: String
}

/// SwiftUI's handle on authentication. The flow itself (which step comes next,
/// validation, sessions, error wording) lives in the shared `AuthModel`, the same
/// one Android uses. This class only publishes its state to SwiftUI and runs the
/// native Apple / Google sign-in sheets that produce ID tokens.
@MainActor
final class AuthSessionStore: ObservableObject {
    @Published private(set) var session: AppSession?
    @Published private(set) var providers: Set<String> = []

    private let model = RollspotServices.sdk.auth

    var isSignedIn: Bool { session != nil }
    var userId: UUID? { session.flatMap { UUID(uuidString: $0.userId) } }
    var userEmail: String? { session?.email.trimmingCharacters(in: .whitespacesAndNewlines) }
    var canChangePassword: Bool { providers.contains("credential") }

    init() {
        Task { await observeSession() }
        Task { try? await model.restore() }
    }

    private func observeSession() async {
        for await state in model.session {
            let previous = session
            switch onEnum(of: state) {
            case .signedIn(let signedIn):
                session = AppSession(userId: signedIn.user.id, email: signedIn.user.email)
                providers = signedIn.providers
            case .signedOut, .unknown:
                session = nil
                providers = []
            }
            if previous != session {
                NotificationCenter.default.post(name: .rollspotAuthStateDidChange, object: nil)
            }
        }
    }

    // MARK: Flow steps (each returns the next screen)

    func continueWithEmail(_ email: String) async throws -> AuthStep {
        try await model.continueWithEmail(email: email)
    }

    func signIn(email: String, password: String) async throws -> AuthStep {
        try await model.signIn(email: email, password: password)
    }

    func choosePassword(_ password: String) throws -> AuthStep {
        try model.choosePassword(password: password)
    }

    func chooseName(_ name: String) throws -> AuthStep {
        try model.chooseName(name: name)
    }

    func finishMobility(_ aids: [String]) async throws -> AuthStep {
        try await model.finishMobility(aids: aids)
    }

    func completeVerifiedSignUp() async throws -> AuthStep {
        try await model.completeVerifiedSignUp()
    }

    func resendVerificationEmail() async throws {
        try await model.resendVerificationEmail()
    }

    /// The verification email opens `puspadi://auth/callback`.
    func handleAuthCallback(_ url: URL) async {
        guard url.scheme == CloudflareConfig.authCallbackURL.scheme else { return }
        try? await model.restore()
    }

    // MARK: Apple / Google (native sheets → shared token exchange)

    func signInWithApple(authorization: ASAuthorization, rawNonce: String) async throws -> AuthStep {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw AuthFlowError.appleSignInFailed
        }
        let fullName = credential.fullName.map {
            PersonNameComponentsFormatter.localizedString(from: $0, style: .default)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } ?? ""
        // Apple shares the email and name only on the very first authorization.
        let hasEmail = !(credential.email?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        return try await model.signInWithIdToken(
            provider: "apple",
            idToken: idToken,
            nonce: rawNonce,
            suggestedName: fullName.isEmpty ? nil : fullName,
            isNewAccount: hasEmail || !fullName.isEmpty
        )
    }

    func signInWithGoogle() async throws -> AuthStep {
        guard !CloudflareConfig.googleClientID.isEmpty else { throw AuthFlowError.googleNotConfigured }
        guard let presenter = Self.presentingViewController() else { throw AuthFlowError.googleSignInFailed }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: CloudflareConfig.googleClientID)
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        guard let idToken = result.user.idToken?.tokenString else { throw AuthFlowError.googleSignInFailed }
        return try await model.signInWithIdToken(
            provider: "google",
            idToken: idToken,
            nonce: nil,
            suggestedName: result.user.profile?.name,
            isNewAccount: false
        )
    }

    // MARK: Account

    func updatePassword(currentPassword: String, newPassword: String) async throws {
        try await model.changePassword(currentPassword: currentPassword, newPassword: newPassword)
    }

    func updateMobilityProfile(_ profile: MobilityProfile) async throws {
        try await ProfileService.shared.updateMobilityAids(profile.storageAids)
    }

    func signOut() async {
        try? await model.signOut()
        GIDSignIn.sharedInstance.signOut()
    }

    private static func presentingViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        var controller = scenes.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController
        while let presented = controller?.presentedViewController { controller = presented }
        return controller
    }
}

enum AuthFlowError: LocalizedError {
    case appleSignInFailed
    case googleSignInFailed
    case googleNotConfigured

    var errorDescription: String? {
        switch self {
        case .appleSignInFailed: "Sign in with Apple failed. Try again.".localized
        case .googleSignInFailed: "Sign in with Google failed. Try again.".localized
        case .googleNotConfigured: "Google Sign-In has not been configured yet.".localized
        }
    }
}

/// Apple requires the SHA-256 of a random nonce in the request and the raw nonce at the server.
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

extension AuthRoute {
    /// The screen for a shared `AuthStep`; nil means the flow is finished.
    init?(_ step: AuthStep) {
        switch onEnum(of: step) {
        case .welcome, .done: return nil
        case .emailFound(let found): self = .emailFound(found.email)
        case .createPassword(let create): self = .createPassword(create.email)
        case .name: self = .name
        case .mobility: self = .mobility
        case .verifyEmail(let verify): self = .verifyEmail(verify.email)
        }
    }
}

extension AuthStep {
    /// Name prefill carried by the step (e.g. the name Apple or Google shared).
    var suggestedName: String? {
        if case .name(let name) = onEnum(of: self) { return name.suggestedName }
        return nil
    }
}
