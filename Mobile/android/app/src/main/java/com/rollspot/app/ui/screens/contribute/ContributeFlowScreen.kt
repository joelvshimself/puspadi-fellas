package com.rollspot.app.ui.screens.contribute

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.material.icons.filled.Info
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.layout.layout
import androidx.compose.ui.unit.sp
import com.rollspot.app.ui.theme.ContributeColors
import app.rollspot.shared.reviews.ContributeCategoryLabels
import com.rollspot.app.ui.screens.contribute.components.ContributeNotesScreen
import com.rollspot.app.ui.screens.contribute.components.ContributeCategoryMenuScreen
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import com.rollspot.app.ui.theme.RollspotBlue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import app.rollspot.shared.reviews.ContributeCodes
import app.rollspot.shared.reviews.ContributeHeroAsset
import app.rollspot.shared.reviews.ContributeStep
import app.rollspot.shared.reviews.ContributeReviewCategory
import app.rollspot.shared.reviews.ContributeStepPresentation
import app.rollspot.shared.reviews.EntranceLocation
import app.rollspot.shared.reviews.ToiletSurveyQuestion
import androidx.compose.runtime.key
import app.rollspot.shared.reviews.newPhotoFileId
import com.rollspot.app.R
import com.rollspot.app.ui.rollspotSdk
import com.rollspot.app.ui.screens.contribute.components.*
import android.widget.Toast
import kotlinx.coroutines.launch

/** Contribute flow. Question titles follow the signed-in mobility profile. */
@Composable
fun ContributeFlowScreen(
    placeId: String,
    onFinished: () -> Unit,
    /** Debug design review: open on this exact state, offline. */
    preview: app.rollspot.shared.reviews.ContributeFlowState? = null,
) {
    val sdk = rollspotSdk()
    val vm: ContributeFlowViewModel = viewModel(key = placeId) { ContributeFlowViewModel(sdk, placeId, preview) }
    val ui by vm.ui.collectAsStateWithLifecycle()
    val context = LocalContext.current

    var showEntranceInfo by remember { mutableStateOf(false) }
    var showPathwayInfo by remember { mutableStateOf(false) }
    var showParkingInfo by remember { mutableStateOf(false) }

    val scope = rememberCoroutineScope()
    // System Photo Picker: no storage permission needed.
    val photoPicker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri: Uri? ->
        uri ?: return@rememberLauncherForActivityResult
        scope.launch {
            val jpeg = jpegForUpload(context, uri)
            if (jpeg != null) vm.addPhoto(jpeg, newPhotoFileId())
            else Toast.makeText(context, "That photo couldn't be read. Try another one.", Toast.LENGTH_SHORT).show()
        }
    }

    // "Take New Photo": the camera app writes into a cache file we then compress like a picked photo.
    var captureUri by remember { mutableStateOf<Uri?>(null) }
    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { saved ->
        val uri = captureUri ?: return@rememberLauncherForActivityResult
        captureUri = null
        if (!saved) return@rememberLauncherForActivityResult
        scope.launch {
            val jpeg = jpegForUpload(context, uri)
            context.contentResolver.delete(uri, null, null)
            if (jpeg != null) vm.addPhoto(jpeg, newPhotoFileId())
        }
    }
    fun takePhoto() {
        val dir = java.io.File(context.cacheDir, "captures").apply { mkdirs() }
        val file = java.io.File(dir, "${newPhotoFileId()}.jpg")
        val uri = androidx.core.content.FileProvider.getUriForFile(context, "${context.packageName}.photos", file)
        captureUri = uri
        runCatching { camera.launch(uri) }.onFailure {
            Toast.makeText(context, "No camera app is available.", Toast.LENGTH_SHORT).show()
        }
    }
    fun chooseExisting() = photoPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))

    if (ui.loadingPlace) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
        return
    }
    ui.placeError?.let {
        AlertDialog(
            onDismissRequest = onFinished,
            title = { Text("Place unavailable") },
            text = { Text(it) },
            confirmButton = { TextButton(onClick = onFinished) { Text("OK") } },
        )
        return
    }

    if (ui.submitted) {
        ContributeSubmittedScreen(
            onDone = onFinished,
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding(),
        )
        return
    }

    fun entranceEvidence(location: EntranceLocation, question: String) = when (location) {
        EntranceLocation.Lobby -> ui.flowSnapshot?.lobbyEvidence
        EntranceLocation.Basement -> ui.flowSnapshot?.basementEvidence
    }?.get(question).orEmpty()

    val step = ui.currentStep
    if (step == null) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
        return
    }

    if (ui.flowSnapshot?.showExitConfirmation == true) {
        AlertDialog(
            onDismissRequest = vm::dismissExitDialog,
            title = { Text("Leave this form?") },
            text = { Text("Your progress won't be saved if you leave now.") },
            confirmButton = {
                TextButton(onClick = { vm.confirmExit(onFinished) }) { Text("Discard & Leave") }
            },
            dismissButton = { TextButton(onClick = vm::dismissExitDialog) { Text("Cancel") } },
        )
    }

    ui.submitError?.let { msg ->
        AlertDialog(
            onDismissRequest = vm::clearSubmitError,
            title = { Text("Couldn't submit review") },
            text = { Text(msg) },
            confirmButton = { TextButton(onClick = vm::clearSubmitError) { Text("OK") } },
        )
    }

    if (ui.needsLogin) {
        var email by remember { mutableStateOf("") }
        var password by remember { mutableStateOf("") }
        AlertDialog(
            onDismissRequest = vm::dismissLogin,
            title = { Text("Sign in to submit") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(email, { email = it }, label = { Text("Email") }, singleLine = true)
                    OutlinedTextField(password, { password = it }, label = { Text("Password") }, singleLine = true)
                }
            },
            confirmButton = {
                TextButton(onClick = { vm.signInAndSubmit(email, password) }) { Text("Sign in & submit") }
            },
            dismissButton = { TextButton(onClick = vm::dismissLogin) { Text("Cancel") } },
        )
    }

    val screenPadding = Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()
    if (step is ContributeStep.CategoryPick) {
        ContributeCategoryMenuScreen(
            status = ui.flowSnapshot?.sectionStatus ?: emptyMap(),
            submitting = ui.isSubmitting,
            onBack = { vm.goBack(onFinished) },
            onOpen = vm::openCategory,
            onSubmit = vm::submit,
            modifier = screenPadding,
        )
        return
    }
    if (step is ContributeStep.SupplementalNotes) {
        ContributeNotesScreen(
            title = ContributeCategoryLabels.menuTitle(step.category),
            notes = ui.flowSnapshot?.supplementalNotes?.get(step.category)?.text.orEmpty(),
            onNotesChange = { vm.setSupplementalNote(step.category, it) },
            photos = vm.notesPhotos(step.category),
            canAddPhoto = vm.canAddPhoto(),
            onChooseExisting = ::chooseExisting,
            onTakePhoto = ::takePhoto,
            onRemovePhoto = vm::removePhoto,
            onCaption = vm::setPhotoCaption,
            progressStep = ui.progressStep,
            progress = ui.subStepProgress,
            continueTitle = "Continue",
            submitting = ui.isSubmitting,
            onBack = { vm.goBack(onFinished) },
            onContinue = vm::goNext,
            modifier = screenPadding,
        )
        return
    }

    val hero = ContributeStepPresentation.heroAsset(step)
    val canContinue = vm.canContinueCurrentStep()
    val snapshot = ui.flowSnapshot
    val isPhotoStep = step == ContributeStep.EntrancePhotos || step == ContributeStep.ElevatorPhotos ||
        step == ContributeStep.ToiletPhotos || step == ContributeStep.PathwayPhotos ||
        step == ContributeStep.SeatingPhotos || step == ContributeStep.ParkingPhotos
    val anotherChoice: ((String) -> Unit)? = when (step) {
        ContributeStep.EntranceAnother -> vm::chooseAnotherEntrance
        ContributeStep.ElevatorAnother -> vm::chooseAnotherElevator
        ContributeStep.ToiletAnother -> vm::chooseAnotherToilet
        else -> null
    }

    val followUpStill = (step as? ContributeStep.Toilet)?.let { toiletStill(it.question) }
    val followUpVideo = when {
        followUpStill != null -> null
        step is ContributeStep.EntranceRamp -> R.raw.entrance_ramp to rampVideoInfo
        step is ContributeStep.EntranceHandrail -> R.raw.entrance_handrail to handrailVideoInfo
        step is ContributeStep.Elevator -> elevatorVideo(step.question)
        step is ContributeStep.Toilet -> toiletVideo(step.question)
        step is ContributeStep.SeatingQuestion -> seatingVideo
        step is ContributeStep.ParkingQuestion -> parkingVideo
        else -> null
    }
    val hasCard = followUpStill != null || followUpVideo != null

    // A photo under the current answer, opened for its caption.
    var captioning by remember { mutableStateOf<app.rollspot.shared.reviews.LocalReviewPhoto?>(null) }
    @Composable
    fun photos(list: List<app.rollspot.shared.reviews.LocalReviewPhoto>, style: PhotoStripStyle = PhotoStripStyle.Reveal) =
        ContributePhotoStrip(
            photos = list,
            canAdd = vm.canAddPhoto(),
            onChooseExisting = ::chooseExisting,
            onTakePhoto = ::takePhoto,
            onRemove = vm::removePhoto,
            onOpen = { captioning = it },
            style = style,
            // The strip runs to the screen edges.
            modifier = Modifier.layout { measurable, constraints ->
                val extra = 40.dp.roundToPx()
                val placeable = measurable.measure(constraints.copy(maxWidth = constraints.maxWidth + extra, minWidth = constraints.minWidth + extra))
                layout(placeable.width - extra, placeable.height) { placeable.place(-extra / 2, 0) }
            },
        )

    Box(Modifier.fillMaxSize()) {
    Column(
        Modifier
            .fillMaxSize()
            .statusBarsPadding()
            .navigationBarsPadding(),
    ) {
        // Design: progress line on top, then the back button row.
        if (ContributeStepPresentation.showsFacilityProgressBar(step)) {
            ContributeStepProgressBar(currentStep = ui.progressStep, subStepProgress = ui.subStepProgress)
        }
        ContributeFlowHeader(title = ui.navTitle, onBack = { vm.goBack(onFinished) })

        Column(
            Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .imePadding()
                .padding(horizontal = 20.dp)
                .padding(bottom = 16.dp),
        ) {
            when {
                followUpStill != null -> FollowUpStillCard(
                    drawableRes = followUpStill.first, infoTitle = followUpStill.second.first, infoSections = followUpStill.second.second,
                    modifier = Modifier.padding(top = 14.dp),
                )
                followUpVideo != null -> key(followUpVideo.first) {
                    RampLoopVideoCard(
                        rawRes = followUpVideo.first,
                        infoTitle = followUpVideo.second.first,
                        infoSections = followUpVideo.second.second,
                        infoRawRes = followUpVideo.first,
                        modifier = Modifier.padding(top = 14.dp),
                    )
                }
                hero != ContributeHeroAsset.None -> ContributeHeroImage(
                    hero,
                    Modifier.padding(top = if (isPhotoStep) 30.dp else 26.dp),
                    height = if (isPhotoStep) 120.dp else 118.dp,
                )
            }

            Spacer(Modifier.height(if (hasCard) 34.dp else if (isPhotoStep) 50.dp else 40.dp))
            ContributeQuestionBlock(
                eyebrow = ContributeStepPresentation.eyebrow(step),
                title = ContributeStepPresentation.questionTitle(step, ui.persona),
                subtitle = ContributeStepPresentation.questionSubtitle(step),
                onInfo = if (step is ContributeStep.EntranceLocationPick) {
                    { showEntranceInfo = true }
                } else {
                    null
                },
            )
            when (step) {
                ContributeStep.ParkingQuestion -> LearnMoreLink("Learn more about accessible parking") { showParkingInfo = true }
                ContributeStep.PathwayNotice -> LearnMoreLink("Learn more about accessible pathways") { showPathwayInfo = true }
                else -> Unit
            }
            Spacer(Modifier.height(if (isPhotoStep) 30.dp else 18.dp))

            @Composable
            fun options(selected: String?, onSelect: (String) -> Unit) =
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    ContributeStepPresentation.optionsFor(step).forEach { opt ->
                        ContributeSingleChoiceRow(label = opt, selected = selected == opt, onClick = { onSelect(opt) })
                    }
                }

            @Composable
            fun evidence(selected: String?, notSure: String, list: List<app.rollspot.shared.reviews.LocalReviewPhoto>) {
                AnimatedVisibility(
                    selected == notSure,
                    enter = fadeIn(tween(250)) + expandVertically(tween(250)),
                    exit = fadeOut(tween(200)) + shrinkVertically(tween(200)),
                ) {
                    Box(Modifier.padding(top = 12.dp)) { photos(list) }
                }
            }

            when (step) {
                ContributeStep.EntrancePhotos -> photos(snapshot?.entrancePhotos.orEmpty(), PhotoStripStyle.Box)
                ContributeStep.ElevatorPhotos -> photos(snapshot?.elevatorPhotos.orEmpty(), PhotoStripStyle.Box)
                ContributeStep.ToiletPhotos -> photos(snapshot?.toiletPhotos.orEmpty(), PhotoStripStyle.Box)
                ContributeStep.PathwayPhotos -> photos(
                    snapshot?.supplementalNotes?.get(ContributeReviewCategory.OutdoorPathways)?.photos.orEmpty(), PhotoStripStyle.Box,
                )
                ContributeStep.SeatingPhotos -> photos(snapshot?.seatingPhotos.orEmpty(), PhotoStripStyle.Box)
                ContributeStep.ParkingPhotos -> photos(snapshot?.parkingPhotos.orEmpty(), PhotoStripStyle.Box)
                ContributeStep.SeatingQuestion -> options(snapshot?.seatingAnswer, vm::setSeatingAnswer)
                ContributeStep.ParkingQuestion -> options(snapshot?.parkingAnswer, vm::setParkingAnswer)
                ContributeStep.PathwayNotice -> Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    ContributeStepPresentation.tagOptions(step).forEach { option ->
                        ContributeNoticeRow(option, option in snapshot?.pathwayNotices.orEmpty()) { vm.togglePathwayNotice(option) }
                    }
                }
                ContributeStep.EntranceLocationPick -> Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    EntranceLocation.entries.forEach { loc ->
                        ContributeEntranceLocationRow(
                            label = loc.name,
                            selected = loc in snapshot?.entranceLocations.orEmpty(),
                            onClick = { vm.toggleEntranceLocation(loc) },
                        )
                    }
                }
                is ContributeStep.EntranceTags -> {
                    // Notes to DEV: Ramp and/or Handrail have a follow-up question.
                    // Every other tag only records whether it is present. Do not add extra screens for those yet.
                    val selected = when (step.location) {
                        EntranceLocation.Lobby -> snapshot?.lobbyTags.orEmpty()
                        EntranceLocation.Basement -> snapshot?.basementTags.orEmpty()
                    }
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        ContributeStepPresentation.tagOptions(step).forEach { tag ->
                            ContributeTagChip(label = tag, selected = tag in selected, onClick = { vm.toggleEntranceTag(step.location, tag) })
                        }
                    }
                }
                is ContributeStep.EntranceRamp -> {
                    val selected = when (step.location) {
                        EntranceLocation.Lobby -> snapshot?.lobbyRampAnswer
                        EntranceLocation.Basement -> snapshot?.basementRampAnswer
                    }
                    options(selected) { vm.setRampAnswer(step.location, it) }
                    evidence(selected, "Not sure", entranceEvidence(step.location, ContributeCodes.RAMP))
                }
                is ContributeStep.EntranceHandrail -> {
                    val selected = when (step.location) {
                        EntranceLocation.Lobby -> snapshot?.lobbyHandrailAnswer
                        EntranceLocation.Basement -> snapshot?.basementHandrailAnswer
                    }
                    options(selected) { vm.setHandrailAnswer(step.location, it) }
                    evidence(selected, "Not sure", entranceEvidence(step.location, ContributeCodes.HANDRAIL))
                }
                is ContributeStep.Elevator -> {
                    val selected = snapshot?.elevatorAnswers?.get(step.question)
                    options(selected) { vm.setElevatorAnswer(step.question, it) }
                    evidence(selected, "Not Sure", snapshot?.elevatorEvidence?.get(ContributeCodes.elevatorQuestion(step.question)).orEmpty())
                }
                is ContributeStep.Toilet -> {
                    val selected = snapshot?.toiletAnswers?.get(step.question)
                    options(selected) { vm.setToiletAnswer(step.question, it) }
                    val question = ContributeCodes.toiletQuestion(step.question)
                    if (question != null) evidence(selected, "Not sure", snapshot?.toiletEvidence?.get(question).orEmpty())
                }
                ContributeStep.ElevatorLocation -> ContributeTextArea(snapshot?.elevatorLocation.orEmpty(), vm::setElevatorLocation)
                ContributeStep.ToiletLocation -> ContributeTextArea(snapshot?.toiletLocationNote.orEmpty(), vm::setToiletLocation)
                else -> Unit
            }
        }

        if (anotherChoice != null) {
            // "Review another …?": the answers sit where Continue usually is; the tapped one fills blue.
            var chosen by remember(step) { mutableStateOf<String?>(null) }
            val scope2 = rememberCoroutineScope()
            Column(Modifier.padding(start = 20.dp, end = 20.dp, top = 12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                ContributeStepPresentation.optionsFor(step).forEach { opt ->
                    ContributeChoiceButton(opt, selected = chosen == opt) {
                        if (chosen != null) return@ContributeChoiceButton
                        chosen = opt
                        scope2.launch {
                            kotlinx.coroutines.delay(280)
                            anotherChoice(opt)
                        }
                    }
                }
            }
        } else {
            ContributeContinueButton(title = "Continue", enabled = canContinue, loading = ui.isSubmitting, onClick = vm::goNext)
        }
    }
    captioning?.let { photo ->
        // Re-read the photo so a caption saved earlier shows when reopened.
        val current = vm.allPhotos().firstOrNull { it.fileId == photo.fileId } ?: photo
        PhotoCaptionScreen(
            photo = current,
            progressStep = ui.progressStep,
            progress = ui.subStepProgress,
            onSave = { vm.setPhotoCaption(photo.fileId, it) },
            onDismiss = { captioning = null },
        )
    }
    }

    if (showEntranceInfo) {
        AccessibleEntranceInfoSheet(onDismiss = { showEntranceInfo = false })
    }
    if (showPathwayInfo) {
        PathwayInfoSheet(onDismiss = { showPathwayInfo = false })
    }
    if (showParkingInfo) {
        ParkingInfoSheet(onDismiss = { showParkingInfo = false })
    }
}

private val seatingVideo = R.raw.seating to ("Wheelchair Friendly Seating" to listOf(
    "Height" to "Low enough to comfortably reach the tabletop from a seated position.",
    "Clearance" to "Open space underneath so a wheelchair can roll up close and not blocked by a solid base or crossbar.",
))

private val parkingVideo = R.raw.parking_accessible_parking to ("Accessible Parking" to listOf(
    "Space" to "Wider than a standard spot, with designated access aisle for a wheelchair to unload.",
    "Distance" to "Ideally located on the shortest, most direct route to the entrance, not the far end of the lot.",
))

/** Blue underlined "Learn more …" link under a question. */
@Composable
private fun LearnMoreLink(text: String, onClick: () -> Unit) {
    Row(
        Modifier.padding(top = 8.dp).clickable(onClick = onClick),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(Icons.Filled.Info, null, Modifier.size(13.dp), tint = ContributeColors.Blue)
        Text(text, fontSize = 13.sp, fontWeight = FontWeight.Medium, color = ContributeColors.Blue, textDecoration = TextDecoration.Underline)
    }
}

/** "Describe what's around ..." box for the elevator / toilet location (Figma). */
@Composable
private fun ContributeTextArea(value: String, onChange: (String) -> Unit) {
    var focused by remember { mutableStateOf(false) }
    val shape = androidx.compose.foundation.shape.RoundedCornerShape(14.dp)
    val border by androidx.compose.animation.animateColorAsState(ContributeColors.Blue.copy(alpha = if (focused) 0.5f else 0f), tween(150), label = "area")
    Box(
        Modifier.fillMaxWidth().heightIn(min = 112.dp).clip(shape).background(ContributeColors.Fill)
            .border(2.dp, border, shape).padding(horizontal = 15.dp, vertical = 16.dp),
    ) {
        if (value.isEmpty()) Text("Describe what's around ...", fontSize = 15.sp, color = ContributeColors.Placeholder)
        androidx.compose.foundation.text.BasicTextField(
            value, onChange,
            textStyle = androidx.compose.ui.text.TextStyle(fontSize = 15.sp, color = ContributeColors.Text),
            modifier = Modifier.fillMaxWidth().onFocusChanged { focused = it.isFocused },
        )
    }
}

private val rampVideoInfo = "Ramps" to listOf(
    "Slope" to "Steep slopes require wheelchair users to push hard. The taller the step up, the longer the ramp needs to be to stay gentle.",
    "Landing" to "Long ramps require a flat landing space partway up that allows wheelchair users to stop and reset.",
)

private val handrailVideoInfo = "Handrail" to listOf(
    "Height" to "Low enough to reach and grip while seated, not just at standing height.",
    "Grip" to "A rounded rail you can wrap your hand around, not a flat edge or wide cap.",
)

private fun toiletStill(question: ToiletSurveyQuestion) = when (question) {
    ToiletSurveyQuestion.Emergency ->
        R.drawable.contribute_toilet_emergency to ("Emergency Aid" to listOf(
            "Reach" to "Emergency aids can be in the form of buttons or pulleys and should be accessible from a seated or fallen position.",
        ))
    else -> null
}

private fun toiletVideo(question: ToiletSurveyQuestion) = when (question) {
    ToiletSurveyQuestion.DoorKind ->
        R.raw.toilet_doors to ("Doors" to listOf(
            "Manual" to "Manual doors require users to reach out the handles and push/pull. Heavier doors make it harder to navigate to spaces.",
            "Sliding/Automatic" to "Sliding doors are much easier to use as they don't obstruct wheelchairs like pulling a door or require someone seated to lean forward to push. Automatic doors remove that effort entirely.",
        ))
    ToiletSurveyQuestion.Seat ->
        R.raw.toilet_seat to ("Toilet Seat" to listOf(
            "Height" to "Toilet seats at wheelchair height make it easier to transfer to. Seats that are too low or too high may affect balance.",
        ))
    ToiletSurveyQuestion.GrabBars ->
        R.raw.toilet_grab_bars to ("Grab Bars" to listOf(
            "Height" to "Mounted around waist height when seated, not up near shoulder height.",
            "Placement" to "Beside the toilet within arm's reach while seated, not across the room.",
        ))
    ToiletSurveyQuestion.Space ->
        R.raw.toilet_space_to_maneuver to ("Space to Maneuver" to listOf(
            "Space" to "Enough room to enter, close the door, and turn a full circle without hitting the door, toilet, or sink.",
        ))
    ToiletSurveyQuestion.Sink ->
        R.raw.toilet_sink to ("Sink" to listOf(
            "Reach" to "Faucet and soap dispenser is operable without a strong grip or twisting motion.",
            "Clearance" to "Open space underneath so a wheelchair can roll up close and not be blocked by a cabinet.",
        ))
    ToiletSurveyQuestion.Emergency -> null
}

private fun elevatorVideo(question: app.rollspot.shared.reviews.ElevatorQuestion) = when (question) {
    app.rollspot.shared.reviews.ElevatorQuestion.WideEntrance ->
        R.raw.elevator_wide_entrance to ("Elevator Entrance" to listOf(
            "Width" to "Wide enough for a wheelchair to roll straight in without angling at the threshold.",
            "Level Threshold" to "The elevator floor should be level with the floor outside it, no step up or wide gap where a wheel could get stuck.",
        ))
    app.rollspot.shared.reviews.ElevatorQuestion.SpaceToManeuver ->
        R.raw.toilet_space_to_maneuver to ("Space to Maneuver" to listOf(
            "" to "Enough room to enter and turn a full circle without hitting the walls.",
        ))
    app.rollspot.shared.reviews.ElevatorQuestion.ReachableButtons ->
        R.raw.elevators_reachable_buttons to ("Control Buttons" to listOf(
            "Height" to "Elevator buttons should be low enough to press from a seated position.",
            "Emergency" to "The help button must work without needing to stand or lift a handset.",
        ))
}
