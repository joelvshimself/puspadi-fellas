import Shared
import SwiftUI

struct LoginView: View {
    var onSuccess: () -> Void
    var onCancel: () -> Void
    var onExploreMalls: () -> Void

    @State private var path: [AuthRoute]
    @State private var displayName: String = ""
    @State private var mobilityAids: Set<String>

    init(
        onSuccess: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onExploreMalls: @escaping () -> Void,
        initialPath: [AuthRoute] = [],
        initialMobilityAids: Set<String> = []
    ) {
        self.onSuccess = onSuccess
        self.onCancel = onCancel
        self.onExploreMalls = onExploreMalls
        _path = State(initialValue: initialPath)
        _mobilityAids = State(initialValue: initialMobilityAids)
    }

    var body: some View {
        NavigationStack(path: $path) {
            AuthWelcomeView(
                onCancel: onCancel,
                onSuccess: onSuccess,
                path: $path,
                displayName: $displayName
            )
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
            .navigationDestination(for: AuthRoute.self) { route in
                switch route {
                case .name:
                    AuthNameView(displayName: $displayName, path: $path)
                case .mobility:
                    AuthMobilityView(mobilityAids: $mobilityAids, path: $path, onSuccess: onSuccess)
                case .allSet:
                    AuthAllSetView(onExplore: onExploreMalls)
                }
            }
        }
    }
}

#Preview {
    LoginView(onSuccess: {}, onCancel: {}, onExploreMalls: {})
        .environmentObject(AuthSessionStore())
        .environmentObject(LanguageManager.shared)
}

struct AuthWelcomeView: View {
    var onCancel: () -> Void
    var onSuccess: () -> Void
    @Binding var path: [AuthRoute]
    @Binding var displayName: String

    var body: some View {
        ZStack {
            AuthGradientBackground()

            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Spacer()
                    Button("Not now".localized, action: onCancel)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                Text("Welcome to Rollspot".localized)
                    .font(.title.weight(.bold))
                    .foregroundStyle(AuthPalette.heading)

                Text("Sign in or create an account to save places and contribute to the community.".localized)
                    .font(.subheadline)
                    .foregroundStyle(AuthPalette.subtitle)

                AuthSocialButtons(
                    onStep: { advanceAuth(to: $0, path: $path, displayName: $displayName, onDone: onSuccess) },
                    showsOrLabel: false
                )
                .padding(.top, 8)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }
}
