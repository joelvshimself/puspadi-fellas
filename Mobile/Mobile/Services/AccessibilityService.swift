import Foundation
import Supabase

/// Collapses concurrent enrich() calls for the same place onto a single
/// in-flight request.
///
/// PlaceCacheStore only helps once a response has come back. Nothing sat
/// between the cache miss and the network call, so the three code paths that
/// ask about a place at roughly the same moment — the map's grade sweep,
/// SearchSheet's result prefetch, and PlaceReviewStore when the detail page
/// opens — all missed, and all three invoked the Edge Function. On a cold
/// place that meant the paid Google lookup ran two or three times over.
private actor EnrichCoalescer {
    private var inFlight: [String: Task<PlaceAccessibilityResponse, Error>] = [:]

    func run(
        _ key: String,
        operation: @escaping @Sendable () async throws -> PlaceAccessibilityResponse
    ) async throws -> PlaceAccessibilityResponse {
        // Already being fetched — wait on that request instead of starting
        // a second one.
        if let existing = inFlight[key] {
            return try await existing.value
        }

        // Unstructured on purpose: one caller giving up (a cancelled map sweep,
        // a dismissed sheet) must not cancel the request the other waiters are
        // still attached to, and the response should still reach the cache.
        let task = Task { try await operation() }
        inFlight[key] = task
        defer { inFlight[key] = nil }
        return try await task.value
    }
}

/// Owner 1 — talks to the `place-accessibility` Edge Function, the only
/// thing allowed to call Google Places. The client only ever sends an
/// already-resolved coordinate (MapKit did the search) — see
/// docs/specs.md §3/§4.1.
final class AccessibilityService {
    static let shared = AccessibilityService()

    private let client: SupabaseClient
    private let coalescer = EnrichCoalescer()

    private init() {
        client = SupabaseClientProvider.shared
    }

    private struct EnrichRequestBody: Encodable {
        let lat: Double
        let lng: Double
        let name: String?
    }

    /// The Edge Function returns snake_case keys (best_value, place_id,
    /// osm_accessibility, …) but our models are camelCase. functions.invoke's
    /// default decoder does NOT convert between them, so without this the
    /// response fails to decode and the detail view shows "couldn't load".
    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    /// Whatever we already hold for this place, without touching the network.
    ///
    /// Lets the map light up every pin it already knows about instead of
    /// spending its (deliberately small) request budget rediscovering them.
    func cached(lat: Double, lng: Double, name: String?) async -> PlaceAccessibilityResponse? {
        await PlaceCacheStore.shared.get(lat: lat, lng: lng, name: name)
    }

    /// - Parameter userInitiated: true when someone is sitting there waiting on
    ///   this specific answer — they opened the place's detail page. Such a
    ///   request ignores the failure backoff, because it happens at human
    ///   tap-rate and is the one call worth making; a failure it hits is still
    ///   recorded, so the automated map sweeps stay backed off. Background
    ///   work (the map's grade sweep, the search prefetch) leaves this false:
    ///   those are what turn a rate-limited backend into a request storm.
    func enrich(
        lat: Double,
        lng: Double,
        name: String?,
        userInitiated: Bool = false
    ) async throws -> PlaceAccessibilityResponse {
        // On-device cache first — avoids re-hitting the Edge Function when the
        // user re-opens a place they viewed recently (see PlaceCacheStore).
        // Matches on name+proximity as well as the exact coordinate, because
        // MapKit's coordinate for one venue moves between searches.
        let key = PlaceCacheStore.key(lat: lat, lng: lng)
        if let cached = await PlaceCacheStore.shared.get(lat: lat, lng: lng, name: name) {
            return cached
        }
        // Then the negative cache: a place that just failed stays failed for a
        // short, growing window rather than being retried on every pan.
        if !userInitiated, let backoff = await PlaceCacheStore.shared.activeBackoff(for: key) {
            throw backoff
        }

        let client = self.client
        let body = EnrichRequestBody(lat: lat, lng: lng, name: name)

        return try await coalescer.run(key) {
            do {
                let response: PlaceAccessibilityResponse = try await client.functions.invoke(
                    "place-accessibility",
                    options: FunctionInvokeOptions(body: body),
                    decoder: Self.makeDecoder()
                )
                await PlaceCacheStore.shared.set(key, response)
                return response
            } catch {
                // Cancellation is not a server problem — backing off for it
                // would punish a place the user simply scrolled past.
                if !(error is CancellationError) {
                    await PlaceCacheStore.shared.recordFailure(key)
                }
                throw error
            }
        }
    }
}
