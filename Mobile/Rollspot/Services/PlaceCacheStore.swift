import Foundation

/// Thrown by `AccessibilityService.enrich` while a place is in failure
/// backoff, so a place whose Edge Function call just failed (429, 5xx, …)
/// is not re-requested on every pan.
///
/// Without this the map was self-reinforcing under rate limiting: a failed
/// enrich left nothing in the cache, `resolveGrade` swallowed the error into
/// `.noData`, and `.noData` is exactly what `resolveGrades`/`refreshStaleGrades`
/// retry — so every camera change fired the same failing requests again.
struct EnrichBackoffError: LocalizedError {
    let retryAfter: Date

    var errorDescription: String? {
        "Accessibility lookup is backing off after a failure; retrying after \(retryAfter)."
    }
}

/// On-device cache of enrich() responses so re-opening a place (or coming back
/// to one) is instant instead of round-tripping the Edge Function every time.
/// This is the thin per-device layer described in docs/specs.md §3 — the
/// server's place_cache is still the shared source of truth; this only avoids
/// redundant network calls within normal usage.
///
/// In-memory for the session + a small on-disk JSON mirror (caches directory)
/// so it also survives app relaunches, bounded by a TTL. Failures are tracked
/// too, but only in memory — a relaunch is a fair moment to try again.
actor PlaceCacheStore {
    static let shared = PlaceCacheStore()

    private struct Entry: Codable {
        let response: PlaceAccessibilityResponse
        let storedAt: Date
    }

    private struct Failure {
        var count: Int
        var lastAt: Date
    }

    /// One known place, for the name+proximity lookup. Kept in its own small
    /// file rather than derived by reading every cached response back.
    private struct IndexEntry: Codable {
        let key: String
        let name: String
        let lat: Double
        let lng: Double
    }

    /// Short relative to the backend's 90-day TTL — the device cache only needs
    /// to smooth normal browsing, not be authoritative.
    private let ttl: TimeInterval = 60 * 60 * 24 // 24h
    /// TTL for a response the server was still enriching when it answered.
    /// The Mapillary download and the OSM query run in a background task AFTER
    /// the response goes out, so that answer never carries an `imageUrl` —
    /// caching it for the full day is why a place could show no photo until
    /// the next day even though the image landed on the server seconds later.
    /// Matches REFRESH_CLAIM_TTL_MS in place-accessibility/index.ts.
    private let provisionalTTL: TimeInterval = 120
    /// First failure holds a place back 30s, then 60s, 120s, … up to 10 min.
    private let baseBackoff: TimeInterval = 30
    private let maxBackoff: TimeInterval = 600
    /// Must match `resolve_place_id`'s default radius on the server, or the two
    /// disagree about which places are the same and the cache misses anyway.
    private static let matchRadius: Double = 250
    private var memory: [String: Entry] = [:]
    private var failures: [String: Failure] = [:]
    /// Normalized name -> known places with that name.
    private var index: [String: [IndexEntry]] = [:]
    private let directory: URL
    private let indexURL: URL

    /// Bump whenever `key(lat:lng:)` or the stored shape changes. Entries
    /// written under an older scheme are addressed by strings the app no
    /// longer computes — they are unreachable dead weight at best, and at
    /// worst (the 5-decimal → 4-decimal change) they make a place look
    /// review-less because the id it is filed under is not the id we now ask
    /// for. Wiping on upgrade saves everyone a reinstall.
    private static let formatVersion = 2

    private init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent("place-cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        Self.migrateIfNeeded(directory: directory)
        indexURL = directory.appendingPathComponent("index.json")
        index = Self.loadIndex(at: indexURL)
    }

    /// `nonisolated static` for the same reason as `loadIndex` — this runs
    /// from `init`, outside the actor's isolation.
    private nonisolated static func migrateIfNeeded(directory: URL) {
        let versionURL = directory.appendingPathComponent("format.json")
        let stored = (try? Data(contentsOf: versionURL))
            .flatMap { try? JSONDecoder().decode(Int.self, from: $0) }
        guard stored != formatVersion else { return }

        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        for file in contents {
            try? FileManager.default.removeItem(at: file)
        }
        if let data = try? JSONEncoder().encode(formatVersion) {
            try? data.write(to: versionURL, options: .atomic)
        }
    }

    /// Coordinate-derived key. The FALLBACK identity, used when we have never
    /// seen this place before — see `resolve(name:lat:lng:)` for the one that
    /// actually matches a known venue.
    ///
    /// Four decimals (~11m), not five (~1m), so an identical coordinate read
    /// twice cannot produce two entries. This does NOT solve the real drift:
    /// MapKit's reading of one mall moves by up to several hundred metres
    /// between searches, which no coordinate grid can absorb.
    ///
    /// Keep in step with `canonicalPlaceId` in
    /// backend/supabase/functions/place-accessibility/index.ts and with
    /// `Place.canonicalPlaceId`.
    static func key(lat: Double, lng: Double) -> String {
        String(format: "loc_%.4f_%.4f", lat, lng)
    }

    func get(_ key: String) -> PlaceAccessibilityResponse? {
        if let entry = memory[key] {
            return isFresh(entry) ? entry.response : nil
        }
        // Fall back to disk (survives relaunch).
        guard let data = try? Data(contentsOf: fileURL(key)),
              let entry = try? JSONDecoder().decode(Entry.self, from: data),
              isFresh(entry) else { return nil }
        memory[key] = entry
        return entry.response
    }

    /// Cached response for this place under ANY key we hold for it.
    ///
    /// Tries the coordinate key first, then the same (name + proximity) rule
    /// the server applies in `resolve_place_id`. Without this second step the
    /// device cache almost never hit for map pins: each pan re-searched and
    /// MapKit returned the same malls at slightly different coordinates, so
    /// every pin looked like a place we had never seen and cost a round trip
    /// to be told a grade we already had on disk.
    func get(lat: Double, lng: Double, name: String?) -> PlaceAccessibilityResponse? {
        if let hit = get(Self.key(lat: lat, lng: lng)) { return hit }
        guard let resolved = resolve(name: name, lat: lat, lng: lng) else { return nil }
        return get(resolved)
    }

    func set(_ key: String, _ response: PlaceAccessibilityResponse) {
        failures[key] = nil
        let entry = Entry(response: response, storedAt: Date())
        memory[key] = entry
        if let data = try? JSONEncoder().encode(entry) {
            try? data.write(to: fileURL(key), options: .atomic)
        }
        indexEntry(key: key, response: response)
    }

    // MARK: - Identity

    /// Key of a cached place with the same name within `matchRadius`, mirroring
    /// the server's `resolve_place_id`. Exact name match after stripping case
    /// and punctuation — a radius alone would fold a food court into the mall
    /// around it, and fuzzy names would fold "Level 21 Mall" into "Level 21".
    private func resolve(name: String?, lat: Double, lng: Double) -> String? {
        guard let normalized = Self.normalize(name), !normalized.isEmpty else { return nil }
        guard let candidates = index[normalized] else { return nil }

        return candidates
            .map { ($0.key, Self.metres(lat, lng, $0.lat, $0.lng)) }
            .filter { $0.1 <= Self.matchRadius }
            .min { $0.1 < $1.1 }?
            .0
    }

    private func indexEntry(key: String, response: PlaceAccessibilityResponse) {
        // Index against the server's stored anchor where it gave us one — that
        // is the coordinate `resolve_place_id` matches against, so using the
        // same point keeps client and server agreeing on identity.
        guard let place = response.place,
              let normalized = Self.normalize(place.name),
              !normalized.isEmpty,
              let lat = place.lat, let lng = place.lng else { return }

        let entry = IndexEntry(key: place.placeId, name: normalized, lat: lat, lng: lng)
        var bucket = index[normalized] ?? []
        if let existing = bucket.firstIndex(where: { $0.key == entry.key }) {
            bucket[existing] = entry
        } else {
            bucket.append(entry)
        }
        index[normalized] = bucket

        // The response is filed under the requested key, but the server may
        // have resolved it to a different canonical id. Mirror it there too so
        // a later lookup that resolves to the canonical id finds it.
        if place.placeId != key, memory[place.placeId] == nil {
            memory[place.placeId] = memory[key]
            if let data = try? JSONEncoder().encode(memory[key]) {
                try? data.write(to: fileURL(place.placeId), options: .atomic)
            }
        }
        persistIndex()
    }

    private static func normalize(_ name: String?) -> String? {
        guard let name else { return nil }
        return name.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func metres(_ lat1: Double, _ lng1: Double, _ lat2: Double, _ lng2: Double) -> Double {
        let r = 6_371_000.0
        let p1 = lat1 * .pi / 180, p2 = lat2 * .pi / 180
        let dp = (lat2 - lat1) * .pi / 180, dl = (lng2 - lng1) * .pi / 180
        let a = sin(dp / 2) * sin(dp / 2) + cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2)
        return 2 * r * asin(min(1, sqrt(a)))
    }

    /// `nonisolated static` so `init` can call it: an actor's initialiser runs
    /// outside the actor's isolation, and touching an isolated method there is
    /// an error under Swift 6.
    private nonisolated static func loadIndex(at url: URL) -> [String: [IndexEntry]] {
        guard let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([IndexEntry].self, from: data) else { return [:] }
        return Dictionary(grouping: entries, by: \.name)
    }

    private func persistIndex() {
        let flat = index.values.flatMap { $0 }
        guard let data = try? JSONEncoder().encode(flat) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    /// Non-nil while `key` is still inside its post-failure backoff window.
    /// Callers should throw it rather than issuing the request.
    func activeBackoff(for key: String) -> EnrichBackoffError? {
        guard let failure = failures[key] else { return nil }
        let retryAfter = failure.lastAt.addingTimeInterval(backoffInterval(for: failure.count))
        guard retryAfter > Date() else {
            // Window elapsed — let the next attempt through, but keep the
            // count so a repeat failure backs off further rather than
            // restarting at 30s.
            return nil
        }
        return EnrichBackoffError(retryAfter: retryAfter)
    }

    func recordFailure(_ key: String) {
        let previous = failures[key]?.count ?? 0
        failures[key] = Failure(count: previous + 1, lastAt: Date())
    }

    /// Drop a place so the next enrich() hits the Edge Function (e.g. after a
    /// review submit that may have changed accessibility_grade). Also clears
    /// any backoff: an explicit invalidation is a deliberate request to refetch.
    func remove(_ key: String) {
        memory.removeValue(forKey: key)
        failures.removeValue(forKey: key)
        try? FileManager.default.removeItem(at: fileURL(key))
    }

    private func backoffInterval(for failureCount: Int) -> TimeInterval {
        let exponent = max(0, failureCount - 1)
        let scaled = baseBackoff * pow(2, Double(min(exponent, 16)))
        return min(scaled, maxBackoff)
    }

    private func isFresh(_ entry: Entry) -> Bool {
        let age = Date().timeIntervalSince(entry.storedAt)
        return age < (Self.isProvisional(entry.response) ? provisionalTTL : ttl)
    }

    /// True when the server was mid-refresh as it answered — either it had
    /// just claimed the refresh for itself or another request held the claim.
    /// Either way the enrichment (image included) is still landing, so this
    /// copy is worth only a couple of minutes.
    private static func isProvisional(_ response: PlaceAccessibilityResponse) -> Bool {
        guard let place = response.place else { return true }
        return place.refreshClaimedAt != nil
    }

    private func fileURL(_ key: String) -> URL {
        // Key is already filesystem-safe (loc_<lat>_<lng>).
        directory.appendingPathComponent("\(key).json")
    }
}
