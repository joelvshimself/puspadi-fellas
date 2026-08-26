import SwiftUI

/// What `CachedRemoteImage` has for a URL right now. Mirrors `AsyncImage`'s
/// phases so call sites read the same way.
enum CachedImagePhase {
    case loading
    case success(UIImage)
    case failure
}

/// A remote image that loads ONCE.
///
/// `AsyncImage` keeps no decoded cache: every time its view is rebuilt — a
/// carousel page swiped back to, a facility tab reselected, the detail page
/// re-entered — it drops back to its placeholder and fetches again. That is
/// what made photos on the place detail page reload every time.
///
/// This resolves from `ImageStore` synchronously while the view is being laid
/// out, so a cached photo is already on screen in the FIRST frame and never
/// flashes a placeholder.
struct CachedRemoteImage<Content: View>: View {
    let url: URL?
    @ViewBuilder let content: (CachedImagePhase) -> Content

    @State private var phase: CachedImagePhase = .loading

    var body: some View {
        content(displayPhase)
            .task(id: url) { await load() }
    }

    /// A memory hit outranks the state, so the first render already has the
    /// image rather than waiting a frame for `.task` to run.
    private var displayPhase: CachedImagePhase {
        if case .loading = phase,
           let url,
           let cached = ImageStore.shared.image(for: ImageStore.key(for: url)) {
            return .success(cached)
        }
        return phase
    }

    private func load() async {
        guard let url else {
            phase = .failure
            return
        }
        let key = ImageStore.key(for: url)
        if let cached = ImageStore.shared.image(for: key) {
            phase = .success(cached)
            return
        }
        // Deliberately NOT resetting to `.loading` first: on a reappearance
        // that would blank an image already on screen.
        if let downloaded = await ImageStore.shared.remoteImage(for: url) {
            phase = .success(downloaded)
        } else {
            phase = .failure
        }
    }
}
