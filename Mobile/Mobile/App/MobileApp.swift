import SwiftUI

@main
struct MobileApp: App {
    @StateObject private var languageManager = LanguageManager.shared

    init() {
        // The default shared cache is far too small to hold prefetched street
        // and review photos, so they would be evicted before the user opened
        // the place. NetworkRetry downloads via URLSession.shared, so raising
        // this is what makes the prefetch actually pay off.
        URLCache.shared = URLCache(
            memoryCapacity: 32 * 1024 * 1024,
            diskCapacity: 256 * 1024 * 1024
        )
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(languageManager)
        }
    }
}
