package app.rollspot.shared.profile

import app.rollspot.shared.api.ApiException
import app.rollspot.shared.api.MyReview
import app.rollspot.shared.api.RollspotApi
import app.rollspot.shared.place.dateLabelOf
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

data class MyPhoto(val url: String, val caption: String, val reviewId: String, val placeName: String)

data class MyReviewItem(
    val id: String,
    val placeId: String,
    val placeName: String,
    /** Offer "Update Review" only when true. */
    val editable: Boolean,
    val createdAt: String,
    /** Same date format as the place page's review list. */
    val dateLabel: String,
    val text: String,
    val providedFeatures: List<String>,
    val photos: List<MyPhoto>,
)

data class MyReviewsState(
    val userName: String = "You",
    val userRole: String? = null,
    val avatarUrl: String? = null,
    /** Newest first. */
    val reviews: List<MyReviewItem> = emptyList(),
    val isLoading: Boolean = false,
    val hasLoaded: Boolean = false,
    /** The review being deleted, so its row can show progress. */
    val deletingId: String? = null,
    val error: String? = null,
) {
    /** My Photos: every photo from my reviews, newest review first. */
    val photos: List<MyPhoto> get() = reviews.flatMap { it.photos }
}

/** My Reviews and My Photos on the profile. */
class MyReviewsModel(private val api: RollspotApi) {
    private val _state = MutableStateFlow(MyReviewsState())
    val state: StateFlow<MyReviewsState> = _state.asStateFlow()

    @Throws(Exception::class)
    suspend fun load() {
        _state.update { it.copy(isLoading = true, error = null) }
        try {
            val mine = api.myReviews()
            _state.update {
                it.copy(
                    userName = mine.userName.ifBlank { "You" },
                    userRole = mine.userRole,
                    avatarUrl = mine.profileImageUrl,
                    reviews = mine.reviews.map(::item).sortedByDescending { review -> review.createdAt },
                    isLoading = false,
                    hasLoaded = true,
                )
            }
        } catch (error: ApiException) {
            _state.update { it.copy(isLoading = false, hasLoaded = true, error = error.message) }
            throw error
        }
    }

    /**
     * Removes the review straight away; if the server refuses, it comes back where it was
     * and the error is thrown.
     */
    @Throws(Exception::class)
    suspend fun delete(reviewId: String) {
        val before = _state.value.reviews
        if (before.none { it.id == reviewId } || _state.value.deletingId != null) return
        _state.update { it.copy(deletingId = reviewId, error = null, reviews = before.filterNot { review -> review.id == reviewId }) }
        try {
            api.deleteReview(reviewId)
            _state.update { it.copy(deletingId = null) }
        } catch (error: ApiException) {
            _state.update { it.copy(deletingId = null, reviews = before, error = error.message) }
            throw error
        }
    }

    fun clear() {
        _state.value = MyReviewsState()
    }

    private fun item(review: MyReview) = MyReviewItem(
        id = review.id,
        placeId = review.placeId,
        placeName = review.placeName,
        editable = review.editable,
        createdAt = review.createdAt,
        dateLabel = dateLabelOf(review.createdAt),
        text = review.reviewText,
        providedFeatures = review.providedFeatures,
        photos = review.photoUrls.mapIndexed { index, url ->
            MyPhoto(url, review.photoCaptions.getOrNull(index)?.trim().orEmpty(), review.id, review.placeName)
        },
    )
}
