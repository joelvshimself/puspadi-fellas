import SwiftUI

struct ContentView: View {
    var body: some View {
        HomeMapView()
    }
}

#Preview {
    ContentView()
        .environmentObject(LanguageManager.shared)
        .environmentObject(AuthSessionStore())
}
