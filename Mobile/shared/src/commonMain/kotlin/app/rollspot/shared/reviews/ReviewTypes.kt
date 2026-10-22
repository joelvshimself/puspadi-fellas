package app.rollspot.shared.reviews

import app.rollspot.shared.api.MyReviews
import app.rollspot.shared.api.PlaceReview
import app.rollspot.shared.api.ReviewSubmission

enum class ReviewPhotoSlot {
    Lobby,
    Basement,
    Elevator,
    Toilet,
}

/** JPEG bytes for one contribute photo; [fileId] is stable across upload retries. */
data class PendingContributionPhoto(
    val fileId: String,
    val jpeg: ByteArray,
    val caption: String = "",
)

/** JPEG bytes for one note photo; [fileId] is stable across upload retries. */
data class PendingReviewPhoto(
    val slot: ReviewPhotoSlot,
    val fileId: String,
    val jpeg: ByteArray,
    val caption: String = "",
)

sealed class ReviewOutcome {
    data class Submitted(val reviewId: String, val placeId: String) : ReviewOutcome()
    data class Loaded(val placeId: String, val review: PlaceReview) : ReviewOutcome()
    data class MineLoaded(val reviews: MyReviews) : ReviewOutcome()
    data object Deleted : ReviewOutcome()
    data class Failed(val message: String, val retryable: Boolean) : ReviewOutcome()
}

data class ReviewState(
    val working: Boolean = false,
    val outcome: ReviewOutcome? = null,
)
