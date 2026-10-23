import GoogleSignIn
import SwiftUI

@main
struct RollspotApp: App {
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var authSession = AuthSessionStore()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                if let screen = DesignReview.current {
                    DesignReviewRoot(screen: screen)
                        .environmentObject(languageManager)
                        .environmentObject(authSession)
                } else {
                    appContent
                }
                #else
                appContent
                #endif
            }
            .onOpenURL { url in
                if GIDSignIn.sharedInstance.handle(url) { return }
                DeepLinkRouter.shared.handle(url)
                Task { await authSession.handleAuthCallback(url) }
            }
        }
    }

    @ViewBuilder
    private var appContent: some View {
        if showSplash {
            SplashScreenView {
                showSplash = false
            }
        } else {
            ContentView()
                .environmentObject(languageManager)
                .environmentObject(authSession)
        }
    }
}
