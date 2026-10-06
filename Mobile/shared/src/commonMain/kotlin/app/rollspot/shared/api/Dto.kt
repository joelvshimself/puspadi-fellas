package app.rollspot.shared.api

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// Wire shapes of the Cloudflare API. backend/API.md is the source of truth; keep these in step with it.

// ---- Places ----

@Serializable
data class Place(
    val id: String,
    @SerialName("osm_ref") val osmRef: String,
    val name: String,
    val category: String? = null,
    val lat: Double,
    val lng: Double,
    val address: String? = null,
    val phone: String? = null,
    val website: String? = null,
    @SerialName("opening_hours") val openingHours: String? = null,
    /** OpenStreetMap's own wheelchair=yes|limited|no tag, independent of Rollspot reviews. */
    @SerialName("osm_wheelchair") val osmWheelchair: String? = null,
    val grade: List<FeatureGrade> = emptyList(),
)

@Serializable
data class FeatureGrade(
    /** entrance | elevator | restroom */
    val feature: String,
    /** yes | limited | no */
    @SerialName("best_value") val bestValue: String,
    val confidence: Double,
)

@Serializable
internal data class PlacesResponse(val places: List<Place>, val attribution: String? = null)

@Serializable
internal data class PlaceResponse(val place: Place)

@Serializable
data class PlacePhoto(
    val id: String,
    val url: String,
    val source: String,
    val credit: String? = null,
    @SerialName("sort_order") val sortOrder: Int = 0,
)

@Serializable
data class SavedPlaces(
    @SerialName("place_ids") val placeIds: List<String>,
    val places: List<Place>,
)

// ---- Reviews ----

@Serializable
data class PlaceReviewEntrance(
    val location: String,
    @SerialName("has_dropoff_ramp") val hasDropoffRamp: Boolean? = null,
    @SerialName("has_rails") val hasRails: Boolean? = null,
    @SerialName("door_type") val doorType: String? = null,
    @SerialName("is_wide_enough") val isWideEnough: Boolean? = null,
    @SerialName("review_text") val reviewText: String? = null,
    @SerialName("photo_urls") val photoUrls: List<String> = emptyList(),
    @SerialName("photo_captions") val photoCaptions: List<String> = emptyList(),
)

@Serializable
data class PlaceReview(
    val id: String,
    @SerialName("created_at") val createdAt: String,
    val notes: String? = null,
    @SerialName("elevator_exists") val elevatorExists: Boolean? = null,
    @SerialName("elevator_wheelchair_accessible") val elevatorWheelchairAccessible: Boolean? = null,
    @SerialName("elevator_blockers") val elevatorBlockers: List<String> = emptyList(),
    @SerialName("elevator_review_text") val elevatorReviewText: String? = null,
    @SerialName("elevator_photo_urls") val elevatorPhotoUrls: List<String> = emptyList(),
    @SerialName("elevator_photo_captions") val elevatorPhotoCaptions: List<String> = emptyList(),
    @SerialName("has_disabled_toilet") val hasDisabledToilet: Boolean? = null,
    @SerialName("toilet_review_text") val toiletReviewText: String? = null,
    @SerialName("toilet_photo_urls") val toiletPhotoUrls: List<String> = emptyList(),
    @SerialName("toilet_photo_captions") val toiletPhotoCaptions: List<String> = emptyList(),
    @SerialName("review_entrances") val reviewEntrances: List<PlaceReviewEntrance> = emptyList(),
    @SerialName("reviewer_name") val reviewerName: String? = null,
    @SerialName("reviewer_role") val reviewerRole: String? = null,
    @SerialName("reviewer_avatar_url") val reviewerAvatarUrl: String? = null,
    @SerialName("reviewer_is_pseudonym") val reviewerIsPseudonym: Boolean = false,
)

@Serializable
internal data class PlaceReviewsResponse(val reviews: List<PlaceReview>)

@Serializable
data class ReviewPhoto(val url: String, val facility: String, val label: String, val caption: String = "")

@Serializable
data class ReviewPhotos(val placeId: String? = null, val photos: List<ReviewPhoto> = emptyList())

@Serializable
data class ReviewNote(
    val text: String? = null,
    val photoUrls: List<String> = emptyList(),
    val photoCaptions: List<String> = emptyList(),
)

@Serializable
data class EntranceReport(
    val location: String,
    val hasDropoffRamp: Boolean? = null,
    val hasRails: Boolean? = null,
    val doorType: String? = null,
    val isWideEnough: Boolean? = null,
    val review: ReviewNote? = null,
)

@Serializable
data class ElevatorReport(
    val exists: Boolean? = null,
    val wheelchairAccessible: Boolean? = null,
    val blockers: List<String> = emptyList(),
    val review: ReviewNote? = null,
)

@Serializable
data class ToiletReport(val hasDisabledToilet: Boolean? = null, val review: ReviewNote? = null)

/** Body of POST /v1/reviews. Reuse [submissionId] when retrying so the server never stores a duplicate. */
@Serializable
data class ReviewSubmission(
    val submissionId: String,
    val placeId: String,
    val entrances: List<EntranceReport>? = null,
    val elevator: ElevatorReport? = null,
    val toilet: ToiletReport? = null,
)

@Serializable
data class ReviewSubmitted(val reviewId: String, val placeId: String, val grade: List<FeatureGrade> = emptyList())

@Serializable
data class MyReview(
    val id: String,
    val placeId: String,
    val placeName: String,
    val createdAt: String,
    val reviewText: String,
    val providedFeatures: List<String> = emptyList(),
    val photoUrls: List<String> = emptyList(),
    val photoCaptions: List<String> = emptyList(),
)

@Serializable
data class MyReviews(
    val userName: String,
    val userRole: String? = null,
    val profileImageUrl: String? = null,
    val reviews: List<MyReview> = emptyList(),
)

@Serializable
internal data class UploadedMedia(val url: String)

// ---- Profile ----

@Serializable
data class Profile(
    val id: String,
    @SerialName("display_name") val displayName: String? = null,
    @SerialName("avatar_url") val avatarUrl: String? = null,
    @SerialName("mobility_aids") val mobilityAids: List<String> = emptyList(),
    val pseudonym: String,
    @SerialName("show_real_name") val showRealName: Boolean = false,
) {
    /** Onboarding ends with the mobility question, so an empty answer means it was never finished. */
    val needsOnboarding: Boolean get() = mobilityAids.isEmpty()
}

@Serializable
data class ProfileUpdate(
    val displayName: String? = null,
    val mobilityAids: List<String>? = null,
    val showRealName: Boolean? = null,
)

// ---- Auth ----

@Serializable
data class AuthUser(
    val id: String,
    val email: String,
    val name: String? = null,
    val emailVerified: Boolean = false,
)

@Serializable
internal data class AuthUserResponse(val user: AuthUser? = null)

@Serializable
internal data class EmailBody(val email: String)

@Serializable
internal data class EmailRegistered(val registered: Boolean)

@Serializable
internal data class EmailPassword(val email: String, val password: String)

@Serializable
internal data class EmailSignUp(val name: String, val email: String, val password: String, val callbackURL: String)

@Serializable
internal data class VerificationEmail(val email: String, val callbackURL: String)

@Serializable
internal data class SocialSignIn(val provider: String, val idToken: IdToken) {
    @Serializable
    data class IdToken(val token: String, val nonce: String? = null)
}

@Serializable
internal data class ChangePassword(val currentPassword: String, val newPassword: String, val revokeOtherSessions: Boolean)

@Serializable
internal data class Providers(val providers: List<String>)

@Serializable
internal data class ErrorBody(val error: String? = null, val code: String? = null, val message: String? = null)
