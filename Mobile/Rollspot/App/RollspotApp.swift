import SwiftUI

@main
struct RollspotApp: App {
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var authSession = AuthSessionStore()
    @State private var showSplash = true

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
                DeepLinkRouter.shared.handle(url)
                Task { await authSession.handleAuthCallback(url) }
            }
        }
    }
}
