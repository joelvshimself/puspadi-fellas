package com.rollspot.app.ui.screens.contribute

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.rollspot.shared.RollspotSdk
import app.rollspot.shared.reviews.PendingReviewPhoto
import app.rollspot.shared.reviews.ReviewModel
import app.rollspot.shared.reviews.ReviewState
import app.rollspot.shared.api.ReviewSubmission
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

/** Exposes shared review CRUD; [ContributeScreen] is not wired here yet. */
class ReviewViewModel(sdk: RollspotSdk) : ViewModel() {
    private val model: ReviewModel = sdk.reviews
    val state: StateFlow<ReviewState> = model.state

    fun submit(submission: ReviewSubmission, photos: List<PendingReviewPhoto>) {
        viewModelScope.launch { model.submit(submission, photos) }
    }

    fun load(reviewId: String) {
        viewModelScope.launch { model.load(reviewId) }
    }

    fun loadMine() {
        viewModelScope.launch { model.loadMine() }
    }

    fun delete(reviewId: String) {
        viewModelScope.launch { model.delete(reviewId) }
    }

    fun clearOutcome() {
        model.clearOutcome()
    }
}
