import GoogleSignIn
import SwiftUI

@main
struct RollspotApp: App {
    @UIApplicationDelegateAdaptor(RollspotAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
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
            .onChange(of: scenePhase) { _, phase in
                // Notifications may have been switched on or off in iOS Settings meanwhile.
                if phase == .active { Task { await PushNotificationsService.shared.refreshPermission() } }
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
