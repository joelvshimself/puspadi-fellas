package com.rollspot.app.ui.screens.contribute

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.rollspot.shared.RollspotSdk
import app.rollspot.shared.api.ApiException
import app.rollspot.shared.reviews.ContributeFlow
import app.rollspot.shared.reviews.ContributeFlowState
import app.rollspot.shared.reviews.ContributePersona
import app.rollspot.shared.reviews.ContributeReviewCategory
import app.rollspot.shared.reviews.ContributeStep
import app.rollspot.shared.reviews.ContributeStepPresentation
import app.rollspot.shared.reviews.EntranceLocation
import app.rollspot.shared.reviews.ElevatorQuestion
import app.rollspot.shared.reviews.FacilityNotes
import app.rollspot.shared.reviews.LocalReviewPhoto
import app.rollspot.shared.reviews.ReviewModel
import app.rollspot.shared.reviews.ToiletSurveyQuestion
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

data class ContributeUiState(
    val placeId: String,
    val placeName: String = "",
    val loadingPlace: Boolean = true,
    val placeError: String? = null,
    val flowSnapshot: ContributeFlowState? = null,
    val currentStep: ContributeStep? = null,
    val navTitle: String = "",
    val progressStep: Int = 1,
    val subStepProgress: Float = 0.35f,
    val stepCount: Int = 0,
    val needsLogin: Boolean = false,
    val submitError: String? = null,
    val submitted: Boolean = false,
    val isSubmitting: Boolean = false,
    val persona: ContributePersona = ContributePersona.Wheelchair,
)

class ContributeFlowViewModel(
    private val sdk: RollspotSdk,
    private val placeId: String,
    private val preview: ContributeFlowState? = null,
) : ViewModel() {
    private val reviewModel: ReviewModel = sdk.reviews
    // Picks up where the user left off on this device (shared ContributeDrafts).
    private val flow = ContributeFlow(placeId = placeId, placeName = "", initial = preview ?: sdk.drafts.restoreFlow(placeId))
    /** Draft saves run one at a time, off the main thread. */
    private val draftWriter = Dispatchers.IO.limitedParallelism(1)

    private val _ui = MutableStateFlow(ContributeUiState(placeId = placeId))
    val ui: StateFlow<ContributeUiState> = _ui.asStateFlow()

    init {
        if (preview != null) {
            _ui.update { it.copy(placeName = preview.placeName, loadingPlace = false) }
            publishFlow()
        } else {
            load()
        }
    }

    private fun load() {
        viewModelScope.launch {
            try {
                val aids = sdk.api.profile().mobilityAids
                val persona = if (aids.any { it == "Wheelchair" }) {
                    ContributePersona.Wheelchair
                } else {
                    ContributePersona.Secondary
                }
                flow.state = flow.state.copy(persona = persona)
                _ui.update { it.copy(persona = persona) }
            } catch (_: Exception) {
                // Keep the wheelchair wording if the profile cannot be read.
            }
        }
        viewModelScope.launch {
            try {
                val place = sdk.places.place(placeId)
                flow.state = flow.state.copy(placeName = place.name)
                _ui.update { it.copy(placeName = place.name, loadingPlace = false) }
                publishFlow()
            } catch (e: Exception) {
                _ui.update { it.copy(loadingPlace = false, placeError = e.message ?: "Place not found") }
            }
        }
    }

    private fun publishFlow() {
        if (!_ui.value.submitted && preview == null) {
            val snapshot = flow.state
            val hasProgress = flow.hasProgress()
            viewModelScope.launch(draftWriter) { sdk.drafts.saveFlow(snapshot, hasProgress) }
        }
        val step = flow.currentStep()
        _ui.update {
            it.copy(
                flowSnapshot = flow.state,
                currentStep = step,
                navTitle = step?.let(ContributeStepPresentation::navTitle) ?: "",
                progressStep = step?.let(ContributeStepPresentation::progressStep) ?: 1,
                subStepProgress = if (step != null) {
                    ContributeStepPresentation.subStepProgress(flow, step)
                } else {
                    0.35f
                },
                stepCount = flow.steps().size,
            )
        }
    }

    private fun mutate(block: () -> Unit) {
        block()
        val max = maxOf(flow.steps().size - 1, 0)
        if (flow.state.stepIndex > max) {
            flow.state = flow.state.copy(stepIndex = max)
        }
        publishFlow()
    }

    fun openCategory(category: ContributeReviewCategory) {
        mutate { flow.openCategory(category) }
    }

    fun togglePathwayNotice(option: String) {
        mutate { flow.togglePathwayNotice(option) }
    }

    fun setSupplementalNote(category: ContributeReviewCategory, text: String) {
        mutate { flow.setCategoryNote(category, text) }
    }

    fun toggleEntranceLocation(location: EntranceLocation) {
        mutate {
            val next = flow.state.entranceLocations.toMutableSet()
            if (location in next) next.remove(location) else next.add(location)
            flow.state = flow.state.copy(entranceLocations = next)
        }
    }

    fun toggleEntranceTag(location: EntranceLocation, tag: String) {
        mutate {
            when (location) {
                EntranceLocation.Lobby -> {
                    val t = flow.state.lobbyTags.toMutableSet()
                    if (tag in t) t.remove(tag) else t.add(tag)
                    flow.state = flow.state.copy(lobbyTags = t)
                }
                EntranceLocation.Basement -> {
                    val t = flow.state.basementTags.toMutableSet()
                    if (tag in t) t.remove(tag) else t.add(tag)
                    flow.state = flow.state.copy(basementTags = t)
                }
            }
        }
    }

    fun setRampAnswer(location: EntranceLocation, answer: String) {
        mutate { flow.setRampAnswer(location, answer) }
    }

    fun setHandrailAnswer(location: EntranceLocation, answer: String) {
        mutate { flow.setHandrailAnswer(location, answer) }
    }

    fun setElevatorAnswer(question: ElevatorQuestion, answer: String) {
        mutate { flow.setElevatorAnswer(question, answer) }
    }

    fun setElevatorLocation(text: String) {
        mutate { flow.state = flow.state.copy(elevatorLocation = text) }
    }

    fun chooseAnotherEntrance(answer: String) {
        flow.chooseAnotherEntrance(answer)
        publishFlow()
    }

    fun chooseAnotherElevator(answer: String) {
        flow.chooseAnotherElevator(answer)
        publishFlow()
    }

    fun chooseAnotherToilet(answer: String) {
        flow.chooseAnotherToilet(answer)
        publishFlow()
    }

    fun setToiletAnswer(question: ToiletSurveyQuestion, answer: String) {
        mutate { flow.setToiletAnswer(question, answer) }
    }

    fun setSeatingAnswer(answer: String) {
        mutate { flow.state = flow.state.copy(seatingAnswer = answer) }
    }

    fun setParkingAnswer(answer: String) {
        mutate { flow.state = flow.state.copy(parkingAnswer = answer) }
    }

    fun setToiletLocation(note: String) {
        mutate { flow.state = flow.state.copy(toiletLocationNote = note) }
    }

    fun addPhoto(jpeg: ByteArray, fileId: String) {
        mutate { flow.addPhoto(LocalReviewPhoto(fileId, jpeg)) }
    }

    fun removePhoto(fileId: String) {
        mutate { flow.removePhoto(fileId) }
    }

    fun canAddPhoto(): Boolean = flow.canAddPhoto()

    /** The section photos the notes step shows (shared ContributeFlow.notesPhotos). */
    fun notesPhotos(category: ContributeReviewCategory): List<LocalReviewPhoto> = flow.notesPhotos(category)

    /** Every photo in the flow (for reopening one to caption it). */
    fun allPhotos(): List<LocalReviewPhoto> = buildList {
        app.rollspot.shared.reviews.mapPhotosIn(flow.state) { add(it); it }
    }

    fun setPhotoCaption(fileId: String, caption: String) {
        mutate { flow.setPhotoCaption(fileId, caption) }
    }

    fun canContinueCurrentStep(): Boolean {
        val step = flow.currentStep() ?: return false
        return flow.canContinue(step)
    }

    fun goNext() {
        val step = flow.currentStep() ?: return
        if (!flow.canContinue(step)) return
        flow.goNext()
        publishFlow()
    }

    fun goBack(onExit: () -> Unit) {
        if (flow.state.stepIndex == 0 && flow.hasProgress()) {
            flow.state = flow.state.copy(showExitConfirmation = true)
            publishFlow()
        } else if (flow.state.stepIndex == 0) {
            onExit()
        } else {
            flow.goBack()
            publishFlow()
        }
    }

    fun dismissExitDialog() {
        flow.dismissExitConfirmation()
        publishFlow()
    }

    /** "Discard & Leave": the draft goes too. */
    fun confirmExit(onExit: () -> Unit) {
        forgetDraft()
        onExit()
    }

    private fun forgetDraft() {
        val placeId = flow.state.placeId
        viewModelScope.launch(draftWriter) { sdk.drafts.forget(placeId) }
    }

    fun submit() {
        viewModelScope.launch {
            if (sdk.tokenStore.load() == null) {
                _ui.update { it.copy(needsLogin = true) }
                return@launch
            }
            doSubmit()
        }
    }

    fun dismissLogin() {
        _ui.update { it.copy(needsLogin = false) }
    }

    fun clearSubmitError() {
        _ui.update { it.copy(submitError = null) }
    }

    private suspend fun doSubmit() {
        _ui.update { it.copy(isSubmitting = true, submitError = null) }
        try {
            reviewModel.submitContribution(flow.toSubmission(), flow.pendingPhotos())
            flow.markSubmitted()
            forgetDraft()
            _ui.update { it.copy(isSubmitting = false, submitted = true) }
            publishFlow()
        } catch (e: Exception) {
            val auth = isAuthFailure(e)
            _ui.update {
                it.copy(
                    isSubmitting = false,
                    submitError = if (auth) {
                        "Your session ended. Sign in and tap Submit again: your answers are saved."
                    } else {
                        "Check your connection and try again."
                    },
                    needsLogin = auth,
                )
            }
        }
    }

    private fun isAuthFailure(e: Exception): Boolean {
        if (e is ApiException && (e.isUnauthorized || e.status == 403)) return true
        val text = (e.message ?: "").lowercase()
        return text.contains("sign in") || text.contains("unauthorized") || text.contains("401") || text.contains("403")
    }
}
