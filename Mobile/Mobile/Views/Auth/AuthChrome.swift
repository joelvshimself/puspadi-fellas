import AuthenticationServices
import SwiftUI
import UIKit

enum AuthPalette {
    static let brandBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    static let fieldFill = Color(white: 0.94)
    static let heading = Color.primary
    static let subtitle = Color.secondary
    static let errorRed = Color(red: 0.86, green: 0.18, blue: 0.18)
    static let errorFill = Color(red: 1.0, green: 0.94, blue: 0.94)
}

enum AuthRoute: Hashable {
    case emailFound(String)
    case createPassword(String)
    /// Carries signup fields in the route so NavigationStack doesn't drop parent `@State`.
    case verifyEmail(email: String, password: String, displayName: String, mobilityAids: [String])
    case name(email: String, password: String)
    case mobility(email: String, password: String, displayName: String)
    case allSet
}

struct AuthGradientBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.72, green: 0.88, blue: 1.0),
                Color.white,
                Color.white
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

struct AuthBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.white.opacity(0.7)))
        }
        .buttonStyle(.plain)
    }
}

struct AuthContinueButton: View {
    let title: String
    var enabled: Bool = true
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
                Text(title)
                    .font(.body.weight(.bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                Capsule().fill(enabled && !isLoading ? AuthPalette.brandBlue : Color.gray.opacity(0.35))
            )
        }
        .disabled(!enabled || isLoading)
        .buttonStyle(.plain)
    }
}

struct AuthFieldBox<Content: View>: View {
    var isFocused: Bool = false
    var isError: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isError ? AuthPalette.errorFill : AuthPalette.fieldFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isError ? AuthPalette.errorRed : (isFocused ? AuthPalette.brandBlue : Color.clear),
                        lineWidth: isFocused || isError ? 1.5 : 0
                    )
            )
    }
}

struct AuthSocialButtons: View {
    var onSuccess: () -> Void
    var onNeedsOnboarding: (_ suggestedName: String?) -> Void
    var onDeferAppleSignIn: (_ pending: PendingAppleSignIn, _ suggestedName: String?) -> Void
    var showsOrLabel: Bool = true

    @EnvironmentObject private var auth: AuthSessionStore
    @State private var currentNonce = ""
    @State private var errorMessage: String?
    @State private var isBusy = false

    var body: some View {
        VStack(spacing: 12) {
            if showsOrLabel {
                Text("or Sign in with".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            CenteredSignInWithAppleButton(
                isDisabled: isBusy,
                onRequest: { request in
                    let nonce = AppleSignInNonce.random()
                    currentNonce = nonce
                    request.requestedScopes = [.email, .fullName]
                    request.nonce = AppleSignInNonce.sha256(nonce)
                },
                onCompletion: { result in
                    Task { await complete(result) }
                }
            )
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .accessibilityLabel("Continue with Apple".localized)

            if isBusy {
                ProgressView()
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(AuthPalette.errorRed)
            }
        }
    }

    private func complete(_ result: Result<ASAuthorization, Error>) async {
        errorMessage = nil
        switch result {
        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                return
            }
            errorMessage = error.localizedDescription
        case .success(let authorization):
            isBusy = true
            defer { isBusy = false }
            do {
                if AuthSessionStore.isFirstAppleAuthorization(authorization) {
                    let (pending, suggestedName) = try AuthSessionStore.pendingAppleSignIn(
                        from: authorization,
                        rawNonce: currentNonce
                    )
                    AuthDebug.log("Apple first-time defer signup name=\(suggestedName ?? "nil")")
                    onDeferAppleSignIn(pending, suggestedName)
                } else {
                    AuthDebug.log("Apple returning user sign-in")
                    try await auth.signInWithAppleReturningUser(
                        authorization: authorization,
                        rawNonce: currentNonce
                    )
                    let needsOnboarding = await auth.profileNeedsOnboarding()
                    AuthDebug.log("Apple returning user isSignedIn=\(auth.isSignedIn) needsOnboarding=\(needsOnboarding)")
                    if needsOnboarding {
                        onNeedsOnboarding(nil)
                    } else {
                        onSuccess()
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// Official Apple button with centered logo + label at full width.
private struct CenteredSignInWithAppleButton: UIViewRepresentable {
    var isDisabled: Bool
    var onRequest: (ASAuthorizationAppleIDRequest) -> Void
    var onCompletion: (Result<ASAuthorization, Error>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onRequest: onRequest, onCompletion: onCompletion)
    }

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .continue, style: .black)
        button.cornerRadius = 16
        button.addTarget(context.coordinator, action: #selector(Coordinator.handleTap), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {
        uiView.isEnabled = !isDisabled
        uiView.alpha = isDisabled ? 0.6 : 1
    }

    final class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        let onRequest: (ASAuthorizationAppleIDRequest) -> Void
        let onCompletion: (Result<ASAuthorization, Error>) -> Void

        init(
            onRequest: @escaping (ASAuthorizationAppleIDRequest) -> Void,
            onCompletion: @escaping (Result<ASAuthorization, Error>) -> Void
        ) {
            self.onRequest = onRequest
            self.onCompletion = onCompletion
        }

        @objc func handleTap() {
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            onRequest(request)
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }

        func authorizationController(
            controller: ASAuthorizationController,
            didCompleteWithAuthorization authorization: ASAuthorization
        ) {
            onCompletion(.success(authorization))
        }

        func authorizationController(
            controller: ASAuthorizationController,
            didCompleteWithError error: Error
        ) {
            onCompletion(.failure(error))
        }

        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            if let keyWindow = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
                return keyWindow
            }
            return scenes.flatMap(\.windows).first ?? ASPresentationAnchor()
        }
    }
}

struct AuthProgressBar: View {
    let progress: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.gray.opacity(0.15))
                Capsule()
                    .fill(AuthPalette.brandBlue)
                    .frame(width: max(8, proxy.size.width * progress))
            }
        }
        .frame(height: 4)
    }
}
