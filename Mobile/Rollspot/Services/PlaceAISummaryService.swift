import Foundation

/// Resolves the AI accessibility summary shown on a place page.
///
/// Summaries must come from the server so both apps show the same text. The old
/// hard-coded per-venue paragraphs and the on-device synthesis from grades were
/// removed (issue #34): the first presented unverifiable claims as "verified",
/// and the second duplicated grade rules that live in Mobile/shared.
///
/// TODO(backend): add `GET /v1/places/:key/summary` (generated from reviews and
/// cached in D1), carry it in the shared `PlaceDetail`, and pass it here. Until
/// then no summary is shown.
final class PlaceAISummaryService {
    static let shared = PlaceAISummaryService()

    private init() {}

    func summary(serverSummary: String?) -> String? {
        guard let serverSummary, !serverSummary.isEmpty else { return nil }
        return serverSummary
    }
}
