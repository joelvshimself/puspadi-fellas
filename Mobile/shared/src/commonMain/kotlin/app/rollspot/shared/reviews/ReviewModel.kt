package app.rollspot.shared.reviews

import app.rollspot.shared.api.ApiException
import app.rollspot.shared.api.MyReviews
import app.rollspot.shared.api.ReviewById
import app.rollspot.shared.api.ContributionPhoto
import app.rollspot.shared.api.ContributionSubmission
import app.rollspot.shared.api.ReviewSubmission
import app.rollspot.shared.api.ReviewSubmitted
import app.rollspot.shared.api.RollspotApi
import app.rollspot.shared.util.mapWithLimit
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * Create, read, and delete reviews. Uploads JPEGs before POST so retries stay
 * idempotent when the caller reuses [ReviewSubmission.submissionId] and photo file ids.
 */
class ReviewModel(private val api: RollspotApi) {
    private val _state = MutableStateFlow(ReviewState())
    val state: StateFlow<ReviewState> = _state.asStateFlow()

    private val mutationMutex = Mutex()
    private val activeSubmissionIds = mutableSetOf<String>()

    suspend fun submit(submission: ReviewSubmission, photos: List<PendingReviewPhoto>): ReviewSubmitted {
        val key = submission.submissionId
        if (!beginMutation(key)) {
            fail("This review is already being saved.", retryable = false)
            throw IllegalStateException("This review is already being saved.")
        }
        _state.value = ReviewState(working = true)
        try {
            val bySlot = uploadPhotos(submission.placeId, submission.submissionId, photos)
            val body = submission.withUploadedPhotos(bySlot)
            val result = api.submitReview(body)
            _state.value = ReviewState(
                working = false,
                outcome = ReviewOutcome.Submitted(reviewId = result.reviewId, placeId = result.placeId),
            )
            return result
        } catch (error: Exception) {
            _state.value = ReviewState(
                working = false,
                outcome = ReviewOutcome.Failed(message = error.message ?: "Review could not be saved.", retryable = error.isRetryable()),
            )
            throw error
        } finally {
            endMutation(key)
        }
    }

    suspend fun submitContribution(
        submission: ContributionSubmission,
        photos: List<PendingContributionPhoto>,
    ): ReviewSubmitted {
        val key = submission.submissionId
        if (!beginMutation(key)) {
            fail("This review is already being saved.", retryable = false)
            throw IllegalStateException("This review is already being saved.")
        }
        _state.value = ReviewState(working = true)
        try {
            val urls = uploadContributionPhotos(submission.placeId, submission.submissionId, photos)
            val result = api.submitContribution(submission.withUploadedPhotos(urls))
            _state.value = ReviewState(
                working = false,
                outcome = ReviewOutcome.Submitted(reviewId = result.reviewId, placeId = result.placeId),
            )
            return result
        } catch (error: Exception) {
            _state.value = ReviewState(
                working = false,
                outcome = ReviewOutcome.Failed(message = error.message ?: "Review could not be saved.", retryable = error.isRetryable()),
            )
            throw error
        } finally {
            endMutation(key)
        }
    }

    suspend fun load(reviewId: String): ReviewById {
        _state.value = ReviewState(working = true)
        try {
            val loaded = api.getReview(reviewId)
            _state.value = ReviewState(
                working = false,
                outcome = ReviewOutcome.Loaded(placeId = loaded.placeId, review = loaded.review),
            )
            return loaded
        } catch (error: Exception) {
            _state.value = ReviewState(
                working = false,
                outcome = ReviewOutcome.Failed(message = error.message ?: "Review could not be loaded.", retryable = error.isRetryable()),
            )
            throw error
        }
    }

    suspend fun loadMine(): MyReviews {
        _state.value = ReviewState(working = true)
        try {
            val mine = api.myReviews()
            _state.value = ReviewState(working = false, outcome = ReviewOutcome.MineLoaded(reviews = mine))
            return mine
        } catch (error: Exception) {
            _state.value = ReviewState(
                working = false,
                outcome = ReviewOutcome.Failed(message = error.message ?: "Reviews could not be loaded.", retryable = error.isRetryable()),
            )
            throw error
        }
    }

    suspend fun delete(reviewId: String) {
        _state.value = ReviewState(working = true)
        try {
            api.deleteReview(reviewId)
            _state.value = ReviewState(working = false, outcome = ReviewOutcome.Deleted)
        } catch (error: Exception) {
            _state.value = ReviewState(
                working = false,
                outcome = ReviewOutcome.Failed(message = error.message ?: "Review could not be deleted.", retryable = error.isRetryable()),
            )
            throw error
        }
    }

    fun clearOutcome() {
        _state.value = _state.value.copy(outcome = null)
    }

    private suspend fun uploadContributionPhotos(
        placeId: String,
        submissionId: String,
        photos: List<PendingContributionPhoto>,
    ): Map<String, String> {
        if (photos.isEmpty()) return emptyMap()
        val uploaded = mapWithLimit(photos, UPLOAD_CONCURRENCY) { photo ->
            photo.fileId to api.uploadReviewPhoto(placeId, submissionId, photo.fileId, photo.jpeg)
        }
        return uploaded.toMap()
    }

    private suspend fun uploadPhotos(
        placeId: String,
        submissionId: String,
        photos: List<PendingReviewPhoto>,
    ): Map<ReviewPhotoSlot, SlotPhotoUrls> {
        if (photos.isEmpty()) return emptyMap()
        val uploaded = mapWithLimit(photos, UPLOAD_CONCURRENCY) { photo ->
            val url = api.uploadReviewPhoto(placeId, submissionId, photo.fileId, photo.jpeg)
            Triple(photo.slot, url, photo.caption.trim())
        }
        val bySlot = mutableMapOf<ReviewPhotoSlot, MutableList<Pair<String, String>>>()
        for ((slot, url, caption) in uploaded) {
            bySlot.getOrPut(slot) { mutableListOf() }.add(url to caption)
        }
        return bySlot.mapValues { (_, pairs) ->
            SlotPhotoUrls(
                urls = pairs.map { it.first },
                captions = pairs.map { it.second },
            )
        }
    }

    private suspend fun beginMutation(submissionId: String): Boolean = mutationMutex.withLock {
        if (submissionId in activeSubmissionIds) return false
        activeSubmissionIds.add(submissionId)
        true
    }

    private suspend fun endMutation(submissionId: String) {
        mutationMutex.withLock { activeSubmissionIds.remove(submissionId) }
    }

    private fun fail(message: String, retryable: Boolean) {
        _state.value = ReviewState(working = false, outcome = ReviewOutcome.Failed(message, retryable))
    }

    private fun Exception.isRetryable(): Boolean = when (this) {
        is ApiException -> status >= 500 || isNetwork
        else -> true
    }

    private companion object {
        const val UPLOAD_CONCURRENCY = 3
    }
}
