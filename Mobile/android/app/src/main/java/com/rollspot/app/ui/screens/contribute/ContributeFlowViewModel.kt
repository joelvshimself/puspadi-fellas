package com.rollspot.app.ui.screens.contribute

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.rollspot.shared.RollspotSdk
import app.rollspot.shared.api.ApiException
import com.rollspot.app.data.MockPlaces
import app.rollspot.shared.reviews.ContributeFlow
import app.rollspot.shared.reviews.ContributeFlowState
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
)

class ContributeFlowViewModel(
    private val sdk: RollspotSdk,
    placeId: String,
) : ViewModel() {
    private val reviewModel: ReviewModel = sdk.reviews
    private val flow = ContributeFlow(placeId = placeId, placeName = "")

    private val _ui = MutableStateFlow(ContributeUiState(placeId = placeId))
    val ui: StateFlow<ContributeUiState> = _ui.asStateFlow()

    init {
        val mock = MockPlaces.find(placeId)
        if (mock != null) {
            flow.state = flow.state.copy(placeName = mock.name)
            _ui.update { it.copy(placeName = mock.name, loadingPlace = false) }
            publishFlow()
        } else {
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
    }

    private fun publishFlow() {
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

    fun toggleCategory(category: ContributeReviewCategory) {
        mutate { flow.toggleCategory(category) }
    }

    fun setSupplementalNote(category: ContributeReviewCategory, text: String) {
        mutate {
            val next = flow.state.supplementalNotes.toMutableMap()
            val existing = next[category] ?: FacilityNotes()
            next[category] = existing.copy(text = text)
            flow.state = flow.state.copy(supplementalNotes = next)
        }
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
        mutate {
            flow.state = when (location) {
                EntranceLocation.Lobby -> flow.state.copy(lobbyRampAnswer = answer)
                EntranceLocation.Basement -> flow.state.copy(basementRampAnswer = answer)
            }
        }
    }

    fun setHandrailAnswer(location: EntranceLocation, answer: String) {
        mutate {
            flow.state = when (location) {
                EntranceLocation.Lobby -> flow.state.copy(lobbyHandrailAnswer = answer)
                EntranceLocation.Basement -> flow.state.copy(basementHandrailAnswer = answer)
            }
        }
    }

    fun setElevatorAnswer(question: ElevatorQuestion, answer: String) {
        mutate {
            val next = flow.state.elevatorAnswers.toMutableMap()
            next[question] = answer
            flow.state = flow.state.copy(elevatorAnswers = next)
        }
    }

    fun setToiletInitial(answer: String) {
        mutate { flow.state = flow.state.copy(toiletInitialAnswer = answer) }
    }

    fun setToiletAnswer(question: ToiletSurveyQuestion, answer: String) {
        mutate {
            val next = flow.state.toiletAnswers.toMutableMap()
            next[question] = answer
            flow.state = flow.state.copy(toiletAnswers = next)
        }
    }

    fun setToiletLocation(note: String) {
        mutate { flow.state = flow.state.copy(toiletLocationNote = note) }
    }

    fun setFinalNote(text: String) {
        mutate { flow.state = flow.state.copy(toiletNotes = flow.state.toiletNotes.copy(text = text)) }
    }

    fun addPhoto(jpeg: ByteArray, fileId: String) {
        mutate {
            val photo = LocalReviewPhoto(fileId, jpeg)
            val step = flow.currentStep()
            when (step) {
                ContributeStep.EntrancePhotos -> {
                    flow.state = flow.state.copy(entrancePhotos = flow.state.entrancePhotos + photo)
                }
                is ContributeStep.SupplementalNotes -> {
                    val category = step.category
                    val next = flow.state.supplementalNotes.toMutableMap()
                    val existing = next[category] ?: FacilityNotes()
                    next[category] = existing.copy(photos = existing.photos + photo)
                    flow.state = flow.state.copy(supplementalNotes = next)
                }
                ContributeStep.FinalReview -> {
                    val notes = flow.state.toiletNotes.copy(photos = flow.state.toiletNotes.photos + photo)
                    flow.state = flow.state.copy(toiletNotes = notes)
                }
                else -> Unit
            }
        }
    }

    fun removePhoto(fileId: String) {
        mutate {
            fun strip(notes: FacilityNotes) = notes.copy(photos = notes.photos.filter { it.fileId != fileId })
            val supplemental = flow.state.supplementalNotes.mapValues { (_, notes) -> strip(notes) }
            flow.state = flow.state.copy(
                entrancePhotos = flow.state.entrancePhotos.filter { it.fileId != fileId },
                lobbyNotes = strip(flow.state.lobbyNotes),
                basementNotes = strip(flow.state.basementNotes),
                elevatorNotes = strip(flow.state.elevatorNotes),
                toiletNotes = strip(flow.state.toiletNotes),
                supplementalNotes = supplemental,
            )
        }
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

    fun confirmExit(onExit: () -> Unit) {
        onExit()
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

    fun signInAndSubmit(email: String, password: String) {
        viewModelScope.launch {
            try {
                sdk.api.signInWithEmail(email.trim(), password)
                _ui.update { it.copy(needsLogin = false) }
                doSubmit()
            } catch (e: Exception) {
                _ui.update { it.copy(submitError = e.message ?: "Sign in failed") }
            }
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
            reviewModel.submit(flow.toSubmission(), flow.pendingPhotos())
            flow.markSubmitted()
            _ui.update { it.copy(isSubmitting = false, submitted = true) }
            publishFlow()
        } catch (e: Exception) {
            val auth = isAuthFailure(e)
            _ui.update {
                it.copy(
                    isSubmitting = false,
                    submitError = if (auth) {
                        "You need to be signed in to post a review. Sign in and submit again — your answers are saved."
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
