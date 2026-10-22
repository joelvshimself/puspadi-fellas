#if DEBUG
import SwiftUI

/// Debug-only design review: launch with `-designReview <screen>` to open one screen in a
/// fixed state, so iOS and Android can be screenshotted side by side against the Figma frames.
/// The same screen names exist on Android (`--es designReview <screen>`). Compiled out of release.
enum DesignReview: String, CaseIterable {
    case splash
    case welcome
    case emailFound, emailFoundFilled, emailFoundError
    case createPassword
    case name
    case mobility, mobilityFilled
    case allSet
    case home, homeFilter, homeFilterChosen, homeSearch, homeSearchQuery
    // Signed in: pass `-designReviewEmail <email> -designReviewPassword <password>` (a local test account).
    case profile, profileDeleteReview, profilePhotos, profileSettings, profileLanguage
    case myAccount, mobilityProfile, deleteAccount, accountDeleted

    static let current: DesignReview? = {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-designReview"), index + 1 < args.count else { return nil }
        return DesignReview(rawValue: args[index + 1])
    }()

    static let sampleEmail = "name@gmail.com"

    static func argument(_ name: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: name), index + 1 < args.count else { return nil }
        return args[index + 1]
    }

    static func `is`(_ screens: DesignReview...) -> Bool {
        current.map(screens.contains) ?? false
    }
}

struct DesignReviewRoot: View {
    let screen: DesignReview

    var body: some View {
        switch screen {
        case .splash:
            SplashScreenView()
        case .welcome:
            login([])
        case .emailFound, .emailFoundFilled, .emailFoundError:
            login([.emailFound(DesignReview.sampleEmail)])
        case .createPassword:
            login([.createPassword(DesignReview.sampleEmail)])
        case .name:
            login([.createPassword(DesignReview.sampleEmail), .name])
        case .mobility:
            login([.createPassword(DesignReview.sampleEmail), .name, .mobility])
        case .mobilityFilled:
            login([.createPassword(DesignReview.sampleEmail), .name, .mobility], aids: ["Wheelchair"])
        case .allSet:
            login([.allSet])
        case .home, .homeFilter, .homeFilterChosen, .homeSearch, .homeSearchQuery:
            HomeMapView()
        case .profile, .profileDeleteReview:
            signedIn { NavigationStack { ProfileView(initialTab: .reviews) } }
        case .profilePhotos:
            signedIn { NavigationStack { ProfileView(initialTab: .photos) } }
        case .profileSettings, .profileLanguage:
            signedIn { NavigationStack { ProfileView(initialTab: .settings) } }
        case .myAccount, .mobilityProfile, .deleteAccount, .accountDeleted:
            signedIn { NavigationStack { MyAccountView() } }
        }
    }

    private func signedIn(@ViewBuilder _ content: () -> some View) -> some View {
        DesignReviewSignIn(content: content())
    }

    private func login(_ path: [AuthRoute], aids: Set<String> = []) -> some View {
        LoginView(onSuccess: {}, onCancel: {}, onExploreMalls: {}, initialPath: path, initialMobilityAids: aids)
    }
}
/// Signs in with the account from the launch arguments, then shows the screen.
private struct DesignReviewSignIn<Content: View>: View {
    let content: Content
    @EnvironmentObject private var auth: AuthSessionStore
    @State private var ready = false

    var body: some View {
        Group {
            if ready { content } else { ProgressView() }
        }
        .task {
            if !auth.isSignedIn,
               let email = DesignReview.argument("-designReviewEmail"),
               let password = DesignReview.argument("-designReviewPassword") {
                _ = try? await auth.signIn(email: email, password: password)
            }
            ready = true
        }
    }
}
#endif
