import Foundation

/// On-device cache of enrich() responses so re-opening a place (or coming back
/// to one) is instant instead of round-tripping the Edge Function every time.
/// This is the thin per-device layer described in docs/specs.md §3 — the
/// server's place_cache is still the shared source of truth; this only avoids
/// redundant network calls within normal usage.
///
/// In-memory for the session + a small on-disk JSON mirror (caches directory)
/// so it also survives app relaunches, bounded by a TTL.
actor PlaceCacheStore {
    static let shared = PlaceCacheStore()

    private struct Entry: Codable {
        let response: PlaceAccessibilityResponse
        let storedAt: Date
    }

    /// Short relative to the backend's 90-day TTL — the device cache only needs
    /// to smooth normal browsing, not be authoritative.
    private let ttl: TimeInterval = 60 * 60 * 24 // 24h
    private var memory: [String: Entry] = [:]
    private let directory: URL

    private init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent("place-cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Coordinate-derived key, matching the backend's canonical place id so the
    /// same physical place maps to the same cache entry.
    static func key(lat: Double, lng: Double) -> String {
        String(format: "loc_%.5f_%.5f", lat, lng)
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

    func set(_ key: String, _ response: PlaceAccessibilityResponse) {
        let entry = Entry(response: response, storedAt: Date())
        memory[key] = entry
        if let data = try? JSONEncoder().encode(entry) {
            try? data.write(to: fileURL(key), options: .atomic)
        }
    }

    private func isFresh(_ entry: Entry) -> Bool {
        Date().timeIntervalSince(entry.storedAt) < ttl
    }

    private func fileURL(_ key: String) -> URL {
        // Key is already filesystem-safe (loc_<lat>_<lng>).
        directory.appendingPathComponent("\(key).json")
    }
}
