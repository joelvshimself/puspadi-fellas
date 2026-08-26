import CoreLocation
import Foundation

/// Deep links: `puspadifellas://place?lat=…&lng=…&name=…&category=…`.
///
/// One type owns both directions so the share button and the URL handler can
/// never drift apart: `url(for:)` builds the link the share sheet sends, and
/// `handle(_:)` parses an incoming one back into a `Place` for navigation.
/// The app's URL scheme is registered in Info.plist (CFBundleURLTypes).
///
/// The link carries the coordinate + name — the same identity every backend
/// call keys on — so an opened link resolves to the same place_id, grade and
/// reviews as the sender's screen. (Universal Links can layer on later by
/// pointing the same handler at an https path.)
@MainActor
final class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()

    static let scheme = "puspadifellas"
    /// Universal Links host (Cloudflare Pages serves the AASA file and the
    /// no-app fallback page). Must match the applinks: entitlement.
    static let webHost = "puspadi-fellas.pages.dev"

    /// Set when a link arrives; HomeMapView watches this and navigates, then
    /// clears it. A value, not a call, so a link that arrives during launch
    /// waits until the map is ready instead of being dropped.
    @Published var pendingPlace: Place?

    private init() {}

    /// The link the share sheet sends: an https Universal Link, because chat
    /// apps only make http(s) tappable — a raw `puspadifellas://` link renders
    /// as dead text in WhatsApp. With the app installed iOS opens it directly
    /// (applinks entitlement + AASA on `webHost`); without it, the page at
    /// /place shows a fallback instead of Safari's "address is invalid".
    static func shareURL(for place: Place) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = webHost
        components.path = "/place"
        components.queryItems = placeQueryItems(for: place)
        return components.url
    }

    /// The direct in-app link — what the redirect page opens, and what the
    /// `.onOpenURL` handler receives.
    static func url(for place: Place) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "place"
        components.queryItems = placeQueryItems(for: place)
        return components.url
    }

    private static func placeQueryItems(for place: Place) -> [URLQueryItem] {
        [
            URLQueryItem(name: "lat", value: String(format: "%.6f", place.coordinate.latitude)),
            URLQueryItem(name: "lng", value: String(format: "%.6f", place.coordinate.longitude)),
            URLQueryItem(name: "name", value: place.name),
            URLQueryItem(name: "category", value: place.category.isEmpty ? nil : place.category),
        ]
    }

    func handle(_ url: URL) {
        // Both link forms carry the same query: the custom scheme
        // (puspadifellas://place?…) and the Universal Link
        // (https://puspadi-fellas.pages.dev/place?…).
        let isSchemeLink = url.scheme == Self.scheme && url.host == "place"
        let isUniversalLink = url.scheme == "https" && url.host == Self.webHost
            && (url.path == "/place" || url.path == "/place/")
        guard isSchemeLink || isUniversalLink,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems,
              let lat = items.first(where: { $0.name == "lat" })?.value.flatMap(Double.init),
              let lng = items.first(where: { $0.name == "lng" })?.value.flatMap(Double.init),
              CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: lat, longitude: lng))
        else { return }

        let name = items.first(where: { $0.name == "name" })?.value ?? "Shared place"
        let category = items.first(where: { $0.name == "category" })?.value ?? "Place"

        pendingPlace = Place.fromSearchResult(
            name: name,
            category: category,
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng)
        )
    }
}
