import SwiftUI

@main
struct MobileApp: App {
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var authSession = AuthSessionStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(languageManager)
                .environmentObject(authSession)
                .onOpenURL { url in
                    DeepLinkRouter.shared.handle(url)
                    Task { await authSession.handleAuthCallback(url) }
                }
        }
    }
}
