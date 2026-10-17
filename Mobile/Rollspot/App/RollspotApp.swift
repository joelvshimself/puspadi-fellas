import SwiftUI
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@main
struct RollspotApp: App {
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var authSession = AuthSessionStore()
    @State private var showSplash = true

    init() {
        #if DEBUG
        print("[Rollspot] API base URL: \(CloudflareConfig.apiBaseURL.absoluteString)")
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
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
            .onOpenURL { url in
                #if canImport(GoogleSignIn)
                if GoogleSignInAvailability.isLinked, GIDSignIn.sharedInstance.handle(url) { return }
                #endif
                DeepLinkRouter.shared.handle(url)
                Task { await authSession.handleAuthCallback(url) }
            }
        }
    }
}
