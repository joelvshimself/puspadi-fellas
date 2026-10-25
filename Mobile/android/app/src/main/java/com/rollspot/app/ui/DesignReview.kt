package com.rollspot.app.ui

import app.rollspot.shared.reviews.ContributeCatalog
import app.rollspot.shared.reviews.ContributeFlow
import app.rollspot.shared.reviews.ContributeFlowState
import app.rollspot.shared.reviews.ContributeStep
import app.rollspot.shared.reviews.ElevatorQuestion
import app.rollspot.shared.reviews.EntranceLocation
import com.rollspot.app.ui.screens.contribute.ContributeFlowScreen
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.ui.Modifier
import app.rollspot.shared.reviews.CategorySectionStatus
import app.rollspot.shared.reviews.ContributeReviewCategory
import app.rollspot.shared.reviews.LocalReviewPhoto
import com.rollspot.app.ui.screens.contribute.components.ContributeCategoryMenuScreen
import com.rollspot.app.ui.screens.contribute.components.ContributeNotesScreen
import com.rollspot.app.ui.screens.contribute.components.ContributeSubmittedScreen
import com.rollspot.app.ui.screens.contribute.components.PhotoCaptionScreen
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import app.rollspot.shared.auth.AuthStep
import com.rollspot.app.BuildConfig
import com.rollspot.app.ui.screens.auth.AuthFlowScreen
import com.rollspot.app.ui.screens.auth.AuthPreview
import com.rollspot.app.ui.screens.profile.MyAccountScreen
import com.rollspot.app.ui.screens.profile.NotificationsScreen
import com.rollspot.app.ui.screens.profile.ProfileScreen
import com.rollspot.app.ui.screens.profile.ProfileTab
import com.rollspot.app.ui.screens.review.EditResponseScreen
import com.rollspot.app.ui.screens.splash.SplashScreen

/**
 * Debug-only design review: `adb shell am start ... --es designReview <screen>` opens one screen in
 * a fixed state for side-by-side comparison with iOS (`-designReview <screen>`) and the Figma frames.
 * Screen names match iOS App/DesignReview/DesignReview.swift.
 */
object DesignReview {
    const val EXTRA = "designReview"
    /** Signed-in screens: a local test account, passed as extras so it's never committed. */
    const val EMAIL_EXTRA = "designReviewEmail"
    const val PASSWORD_EXTRA = "designReviewPassword"
    private const val EMAIL = "name@gmail.com"

    fun isEnabled(screen: String?) = BuildConfig.DEBUG && !screen.isNullOrBlank()

    fun authPreview(screen: String): AuthPreview? = when (screen) {
        "welcome" -> AuthPreview()
        "emailFound" -> AuthPreview(listOf(AuthStep.Welcome, AuthStep.EmailFound(EMAIL)))
        "emailFoundFilled" -> AuthPreview(listOf(AuthStep.Welcome, AuthStep.EmailFound(EMAIL)), password = "password123")
        "emailFoundError" -> AuthPreview(
            listOf(AuthStep.Welcome, AuthStep.EmailFound(EMAIL)), password = "password123", error = "Incorrect password. Try again.",
        )
        "createPassword" -> AuthPreview(listOf(AuthStep.Welcome, AuthStep.CreatePassword(EMAIL)))
        "name" -> AuthPreview(listOf(AuthStep.Welcome, AuthStep.CreatePassword(EMAIL), AuthStep.Name("")))
        "mobility" -> AuthPreview(listOf(AuthStep.Welcome, AuthStep.CreatePassword(EMAIL), AuthStep.Name(""), AuthStep.Mobility))
        "mobilityFilled" -> AuthPreview(
            listOf(AuthStep.Welcome, AuthStep.CreatePassword(EMAIL), AuthStep.Name(""), AuthStep.Mobility), aids = listOf("Wheelchair"),
        )
        "allSet" -> AuthPreview(listOf(AuthStep.AllSet))
        else -> null
    }
}

@Composable
fun DesignReviewRoot(screen: String, email: String? = null, password: String? = null) {
    when (screen) {
        "splash" -> SplashScreen()
        "home", "homeFilter", "homeFilterChosen", "homeSearch", "homeSearchQuery" -> RollspotApp(review = screen)
        "homeContinueSurvey", "homeContinueSurveyFolded" -> SignedIn(email, password) { Waiting { RollspotApp(review = screen) } }
        "profileOngoing" -> SignedIn(email, password) { Waiting { ProfileScreen({}, {}, {}, {}, {}, review = screen) } }
        "profile", "profileDeleteReview", "profilePhotos", "profileSettings", "profileLanguage" -> SignedIn(email, password) {
            val tab = when (screen) {
                "profilePhotos" -> ProfileTab.Photos
                "profileSettings", "profileLanguage" -> ProfileTab.Settings
                else -> ProfileTab.Reviews
            }
            ProfileScreen({}, {}, {}, {}, {}, initialTab = tab, review = screen)
        }
        "contributeMenu", "contributeMenuProgress", "contributeMenuComplete" -> ContributeCategoryMenuScreen(
            status = when (screen) {
                "contributeMenuComplete" -> mapOf(ContributeReviewCategory.Entrance to CategorySectionStatus.Complete)
                "contributeMenuProgress" -> mapOf(ContributeReviewCategory.Entrance to CategorySectionStatus.InProgress)
                else -> emptyMap()
            },
            submitting = false, onBack = {}, onOpen = {}, onSubmit = {},
            modifier = Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding(),
        )
        "contributeNotes", "contributeNotesFilled", "contributeCaption" -> ReviewNotes(screen)
        "flowPhotos", "flowQuestion", "flowQuestionYes", "flowQuestionNotSure", "flowParking",
        "flowLocation", "flowTags", "flowAnother", "flowWhere", "flowPathwayPhotos", "flowPathway" -> ContributeFlowScreen(
            placeId = "design-review-$screen", onFinished = {}, preview = flowPreview(screen),
        )
        "flowPathwayInfo" -> {
            ContributeFlowScreen(placeId = "design-review-$screen", onFinished = {}, preview = flowPreview("flowPathway"))
            com.rollspot.app.ui.screens.contribute.components.PathwayInfoSheet(onDismiss = {})
        }
        "contributeSubmitted" -> ContributeSubmittedScreen(onDone = {}, modifier = Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding())
        "editResponse", "editResponseLeave" -> SignedIn(email, password) {
            val mine = rollspotSdk().myReviews
            var reviewId by remember { mutableStateOf<String?>(null) }
            LaunchedEffect(Unit) {
                runCatching { mine.load() }
                reviewId = mine.state.value.reviews.firstOrNull { it.editable }?.id
            }
            reviewId?.let { EditResponseScreen(it, onClose = {}, onSaved = {}, review = screen) }
        }
        "notifications" -> SignedIn(email, password) { NotificationsScreen(onBack = {}) }
        "myAccount", "mobilityProfile", "deleteAccount", "accountDeleted" -> SignedIn(email, password) {
            MyAccountScreen(onBack = {}, onAccountDeleted = {}, review = screen)
        }
        else -> DesignReview.authPreview(screen)?.let { AuthFlowScreen(onDone = {}, onCancel = {}, preview = it) }
    }
}

/** Signs in with the account from the launch extras, then shows the screen. */
@Composable
private fun SignedIn(email: String?, password: String?, content: @Composable () -> Unit) {
    val auth = rollspotSdk().auth
    var ready by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        if (!auth.isSignedIn && email != null && password != null) runCatching { auth.signIn(email, password) }
        ready = true
    }
    if (ready) content()
}

/** Leaves a part-done contribution for "Park 23" so the Continue Survey states have something to show. */
@Composable
private fun Waiting(content: @Composable () -> Unit) {
    val drafts = rollspotSdk().drafts
    var ready by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        // The session collector hands the user to the drafts store just after sign-in.
        kotlinx.coroutines.delay(500)
        drafts.remember("design-review-park23", "Park 23")
        ready = true
    }
    if (ready) content()
}

/** The notes step empty, filled (text + two photos, one captioned), or a photo open for its caption. */
@Composable
private fun ReviewNotes(screen: String) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val sample = remember { context.resources.openRawResource(com.rollspot.app.R.drawable.all_set_mall).use { it.readBytes() } }
    val filled = screen != "contributeNotes"
    var notes by remember { mutableStateOf(if (filled) "The ramp is too steep for wheelchair user" else "") }
    var photos by remember {
        mutableStateOf(if (filled) listOf(LocalReviewPhoto("a", sample, "Main entrance"), LocalReviewPhoto("b", sample)) else emptyList())
    }
    ContributeNotesScreen(
        title = "Entrance", notes = notes, onNotesChange = { notes = it },
        photos = photos, canAddPhoto = photos.size < 5, onChooseExisting = {}, onTakePhoto = {},
        onRemovePhoto = { id -> photos = photos.filterNot { it.fileId == id } },
        onCaption = { id, caption -> photos = photos.map { if (it.fileId == id) it.copy(caption = caption) else it } },
        progressStep = 4, progress = 0.35f, continueTitle = "Continue", submitting = false, onBack = {}, onContinue = {},
        modifier = Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding(),
    )
    if (screen == "contributeCaption") {
        PhotoCaptionScreen(LocalReviewPhoto("c", sample), progressStep = 4, progress = 0.35f, onSave = {}, onDismiss = {})
    }
}

/** A contribute flow parked on one question, in the same state as the iOS review screen. */
@Composable
private fun flowPreview(screen: String): ContributeFlowState {
    val context = androidx.compose.ui.platform.LocalContext.current
    val sample = remember { context.resources.openRawResource(com.rollspot.app.R.drawable.all_set_mall).use { it.readBytes() } }
    val flow = ContributeFlow("design-review", "Park 23")
    fun at(category: ContributeReviewCategory, step: ContributeStep, configure: ContributeFlowState.() -> ContributeFlowState = { this }) {
        flow.openCategory(category)
        flow.state = flow.state.configure()
        flow.state = flow.state.copy(stepIndex = flow.steps().indexOf(step).coerceAtLeast(0))
    }
    when (screen) {
        "flowPhotos" -> at(ContributeReviewCategory.Seating, ContributeStep.SeatingPhotos)
        "flowQuestion" -> at(ContributeReviewCategory.Seating, ContributeStep.SeatingQuestion)
        "flowQuestionYes" -> at(ContributeReviewCategory.Seating, ContributeStep.SeatingQuestion) { copy(seatingAnswer = "Yes") }
        "flowQuestionNotSure" -> at(ContributeReviewCategory.Elevator, ContributeStep.Elevator(ElevatorQuestion.WideEntrance)) {
            copy(
                elevatorAnswers = mapOf(ElevatorQuestion.WideEntrance to "Not Sure"),
                elevatorEvidence = mapOf("wideEntrance" to listOf(LocalReviewPhoto("e1", sample), LocalReviewPhoto("e2", sample))),
            )
        }
        "flowPathwayPhotos" -> at(ContributeReviewCategory.OutdoorPathways, ContributeStep.PathwayPhotos)
        "flowPathway" -> at(ContributeReviewCategory.OutdoorPathways, ContributeStep.PathwayNotice) {
            copy(pathwayNotices = setOf("Loose gravel or sand", "Rough or uneven surface"))
        }
        "flowParking" -> at(ContributeReviewCategory.Parking, ContributeStep.ParkingQuestion) { copy(parkingAnswer = "Not sure") }
        "flowLocation" -> at(ContributeReviewCategory.Entrance, ContributeStep.EntranceLocationPick) { copy(entranceLocations = setOf(EntranceLocation.Lobby)) }
        "flowTags" -> at(ContributeReviewCategory.Entrance, ContributeStep.EntranceTags(EntranceLocation.Lobby)) {
            copy(entranceLocations = setOf(EntranceLocation.Lobby), lobbyTags = setOf(ContributeCatalog.TAG_RAMP, ContributeCatalog.TAG_HANDRAIL))
        }
        "flowAnother" -> at(ContributeReviewCategory.Entrance, ContributeStep.EntranceAnother) {
            copy(entranceLocations = setOf(EntranceLocation.Lobby), lobbyTags = setOf(ContributeCatalog.TAG_AUTO_DOORS))
        }
        else -> at(ContributeReviewCategory.Elevator, ContributeStep.ElevatorLocation) {
            copy(elevatorAnswers = mapOf(ElevatorQuestion.WideEntrance to "Yes", ElevatorQuestion.SpaceToManeuver to "Yes", ElevatorQuestion.ReachableButtons to "Yes"))
        }
    }
    return flow.state
}
