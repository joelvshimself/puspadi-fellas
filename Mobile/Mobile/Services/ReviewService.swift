import Foundation
import Supabase

/// Owner 3's Edge Function — `submit-accessibility-review`
/// (backend/supabase/functions/submit-accessibility-review/index.ts).
/// Accepts the entrances/elevator/toilet contribution payload, writes it to
/// `reviews` + `review_entrances`, fans elevator/toilet/entrance into
/// `accessibility_signals`, and returns the freshly recomputed
/// `accessibility_grade()` for the place — same pattern as
/// AccessibilityService's `place-accessibility` call.
///
/// NOTE: JWT auth is intentionally off on the backend for device testing
/// (`user_id` is written as null via service_role) — see the Edge Function's
/// own TODO to re-enable auth before production.
final class ReviewService {
    static let shared = ReviewService()

    private let client: SupabaseClient

    /// The RPC-derived `grade` rows come back snake_case (best_value, ...),
    /// same as place-accessibility — see AccessibilityService's note.
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private init() {
        client = SupabaseClient(supabaseURL: SupabaseConfig.url, supabaseKey: SupabaseConfig.anonKey)
    }

    struct SubmitResponse: Decodable {
        let status: String
        let reviewId: String
        let placeId: String
        let grade: [AccessibilityFeatureGrade]
    }

    @discardableResult
    func submit(_ draft: ReviewDraft) async throws -> SubmitResponse {
        try await client.functions.invoke(
            "submit-accessibility-review",
            options: FunctionInvokeOptions(body: draft.buildSubmissionPayload()),
            decoder: decoder
        )
    }
}
