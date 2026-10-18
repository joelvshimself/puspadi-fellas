package com.rollspot.app.ui.screens.contribute

import android.graphics.BitmapFactory
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import app.rollspot.shared.reviews.ContributeHeroAsset
import app.rollspot.shared.reviews.ContributeStep
import app.rollspot.shared.reviews.ContributeStepPresentation
import app.rollspot.shared.reviews.EntranceLocation
import app.rollspot.shared.reviews.ToiletSurveyQuestion
import androidx.compose.runtime.key
import app.rollspot.shared.reviews.newPhotoFileId
import com.rollspot.app.R
import com.rollspot.app.ui.rollspotSdk
import com.rollspot.app.ui.screens.contribute.components.*
import java.io.ByteArrayOutputStream

/** Primary-user (wheelchair) contribute flow. The secondary-user flow is not built yet. */
@Composable
fun ContributeFlowScreen(placeId: String, onFinished: () -> Unit) {
    val sdk = rollspotSdk()
    val vm: ContributeFlowViewModel = viewModel(key = placeId) { ContributeFlowViewModel(sdk, placeId) }
    val ui by vm.ui.collectAsStateWithLifecycle()
    val context = LocalContext.current

    var showEntranceInfo by remember { mutableStateOf(false) }

    val photoPicker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        uri ?: return@rememberLauncherForActivityResult
        context.contentResolver.openInputStream(uri)?.use { stream ->
            val bitmap = BitmapFactory.decodeStream(stream)
            val out = ByteArrayOutputStream()
            bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 70, out)
            vm.addPhoto(out.toByteArray(), newPhotoFileId())
        }
    }

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

    fun locationPhotos(location: EntranceLocation) = when (location) {
        EntranceLocation.Lobby -> ui.flowSnapshot?.lobbyNotes?.photos
        EntranceLocation.Basement -> ui.flowSnapshot?.basementNotes?.photos
    }.orEmpty()

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

    val hero = ContributeStepPresentation.heroAsset(step)
    val canContinue = vm.canContinueCurrentStep()
    val isFinal = step is ContributeStep.FinalReview
    val ctaTitle = if (isFinal) "Submit review" else "Continue"

    val isCategoryPick = step is ContributeStep.CategoryPick

    Column(
        Modifier
            .fillMaxSize()
            .statusBarsPadding()
            .navigationBarsPadding(),
    ) {
        ContributeFlowHeader(
            title = if (isCategoryPick) "" else ui.navTitle,
            onBack = { vm.goBack(onFinished) },
        )
        when {
            isCategoryPick -> ContributeCategoryPickProgress()
            step !is ContributeStep.Submitted &&
                ContributeStepPresentation.showsFacilityProgressBar(step) -> {
                ContributeStepProgressBar(currentStep = ui.progressStep, subStepProgress = ui.subStepProgress)
            }
        }

        Column(
            Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            val followUpStill = when (step) {
                is ContributeStep.Toilet -> toiletStill(step.question)
                else -> null
            }
            val followUpVideo = when {
                followUpStill != null -> null
                step is ContributeStep.EntranceRamp -> R.raw.entrance_ramp to rampVideoInfo
                step is ContributeStep.EntranceHandrail -> R.raw.entrance_handrail to handrailVideoInfo
                step is ContributeStep.Elevator -> elevatorVideo(step.question)
                step is ContributeStep.Toilet -> toiletVideo(step.question)
                else -> null
            }
            if (!isCategoryPick && hero != ContributeHeroAsset.None && followUpVideo == null && followUpStill == null) {
                ContributeHeroImage(hero)
            }
            followUpStill?.let { (drawableRes, info) ->
                FollowUpStillCard(drawableRes = drawableRes, infoTitle = info.first, infoSections = info.second)
            }
            followUpVideo?.let { (rawRes, info) ->
                key(rawRes) {
                    RampLoopVideoCard(rawRes = rawRes, infoTitle = info.first, infoSections = info.second)
                }
            }

            ContributeQuestionBlock(
                eyebrow = if (isCategoryPick) null else ContributeStepPresentation.eyebrow(step),
                title = ContributeStepPresentation.questionTitle(step),
                subtitle = ContributeStepPresentation.questionSubtitle(step),
                onInfo = if (step is ContributeStep.EntranceLocationPick) {
                    { showEntranceInfo = true }
                } else {
                    null
                },
            )

            when (step) {
                ContributeStep.CategoryPick -> {
                    ContributeCategoryMenusGrid(
                        selected = ui.flowSnapshot?.selectedCategories ?: emptySet(),
                        onToggle = vm::toggleCategory,
                    )
                }
                is ContributeStep.SupplementalNotes -> {
                    val notes = ui.flowSnapshot?.supplementalNotes?.get(step.category)
                    ContributePhotosSection(
                        note = notes?.text ?: "",
                        photos = notes?.photos ?: emptyList(),
                        onNoteChange = { vm.setSupplementalNote(step.category, it) },
                        onAddPhoto = { photoPicker.launch("image/*") },
                        onRemovePhoto = vm::removePhoto,
                    )
                }
                ContributeStep.EntrancePhotos -> {
                    ContributeAddPhotosBox(
                        photos = ui.flowSnapshot?.entrancePhotos ?: emptyList(),
                        onAddPhoto = { photoPicker.launch("image/*") },
                        onRemovePhoto = vm::removePhoto,
                    )
                }
                ContributeStep.ElevatorPhotos -> {
                    ContributeAddPhotosBox(
                        photos = ui.flowSnapshot?.elevatorNotes?.photos ?: emptyList(),
                        onAddPhoto = { photoPicker.launch("image/*") },
                        onRemovePhoto = vm::removePhoto,
                    )
                }
                ContributeStep.ToiletPhotos -> {
                    ContributeAddPhotosBox(
                        photos = ui.flowSnapshot?.toiletPhotos ?: emptyList(),
                        onAddPhoto = { photoPicker.launch("image/*") },
                        onRemovePhoto = vm::removePhoto,
                    )
                }
                ContributeStep.EntranceLocationPick -> {
                    EntranceLocation.entries.forEach { loc ->
                        ContributeEntranceLocationRow(
                            label = loc.name,
                            selected = loc in (ui.flowSnapshot?.entranceLocations ?: emptySet()),
                            onClick = { vm.toggleEntranceLocation(loc) },
                        )
                    }
                }
                is ContributeStep.EntranceTags -> {
                    // Notes to DEV: Ramp and/or Handrail have a follow-up question.
                    // Every other tag only records whether it is present. Do not add extra screens for those yet.
                    val selected = when (step.location) {
                        EntranceLocation.Lobby -> ui.flowSnapshot?.lobbyTags ?: emptySet()
                        EntranceLocation.Basement -> ui.flowSnapshot?.basementTags ?: emptySet()
                    }
                    FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        ContributeStepPresentation.tagOptions(step).forEach { tag ->
                            ContributeTagChip(
                                label = tag,
                                selected = tag in selected,
                                onClick = { vm.toggleEntranceTag(step.location, tag) },
                            )
                        }
                    }
                }
                is ContributeStep.EntranceRamp -> {
                    val selected = when (step.location) {
                        EntranceLocation.Lobby -> ui.flowSnapshot?.lobbyRampAnswer
                        EntranceLocation.Basement -> ui.flowSnapshot?.basementRampAnswer
                    }
                    ContributeStepPresentation.optionsFor(step).forEach { opt ->
                        ContributeSingleChoiceRow(
                            label = opt,
                            selected = selected == opt,
                            onClick = { vm.setRampAnswer(step.location, opt) },
                        )
                    }
                    if (selected == "Not sure") {
                        FollowUpPhotosRow(
                            photos = locationPhotos(step.location),
                            onAddPhoto = { photoPicker.launch("image/*") },
                            onRemovePhoto = vm::removePhoto,
                        )
                    }
                }
                is ContributeStep.EntranceHandrail -> {
                    val selected = when (step.location) {
                        EntranceLocation.Lobby -> ui.flowSnapshot?.lobbyHandrailAnswer
                        EntranceLocation.Basement -> ui.flowSnapshot?.basementHandrailAnswer
                    }
                    ContributeStepPresentation.optionsFor(step).forEach { opt ->
                        ContributeSingleChoiceRow(
                            label = opt,
                            selected = selected == opt,
                            onClick = { vm.setHandrailAnswer(step.location, opt) },
                        )
                    }
                    if (selected == "Not sure") {
                        FollowUpPhotosRow(
                            photos = locationPhotos(step.location),
                            onAddPhoto = { photoPicker.launch("image/*") },
                            onRemovePhoto = vm::removePhoto,
                        )
                    }
                }
                is ContributeStep.Elevator -> {
                    val selected = ui.flowSnapshot?.elevatorAnswers?.get(step.question)
                    ContributeStepPresentation.optionsFor(step).forEach { opt ->
                        ContributeSingleChoiceRow(
                            label = opt,
                            selected = selected == opt,
                            onClick = { vm.setElevatorAnswer(step.question, opt) },
                        )
                    }
                }
                ContributeStep.ElevatorLocation -> {
                    OutlinedTextField(
                        value = ui.flowSnapshot?.elevatorNotes?.text ?: "",
                        onValueChange = vm::setElevatorLocation,
                        modifier = Modifier.fillMaxWidth(),
                        placeholder = { Text("Describe what's around ...") },
                        minLines = 4,
                    )
                }
                ContributeStep.ElevatorAnother -> {
                    ContributeStepPresentation.optionsFor(step).forEach { opt ->
                        ContributeSingleChoiceRow(
                            label = opt,
                            selected = false,
                            onClick = { vm.chooseAnotherElevator(opt) },
                        )
                    }
                }
                ContributeStep.EntranceAnother -> {
                    ContributeStepPresentation.optionsFor(step).forEach { opt ->
                        ContributeSingleChoiceRow(
                            label = opt,
                            selected = false,
                            onClick = { vm.chooseAnotherEntrance(opt) },
                        )
                    }
                }
                is ContributeStep.Toilet -> {
                    val selected = ui.flowSnapshot?.toiletAnswers?.get(step.question)
                    ContributeStepPresentation.optionsFor(step).forEach { opt ->
                        ContributeSingleChoiceRow(
                            label = opt,
                            selected = selected == opt,
                            onClick = { vm.setToiletAnswer(step.question, opt) },
                        )
                    }
                    if (selected == "Not sure") {
                        FollowUpPhotosRow(
                            photos = ui.flowSnapshot?.toiletPhotos ?: emptyList(),
                            onAddPhoto = { photoPicker.launch("image/*") },
                            onRemovePhoto = vm::removePhoto,
                        )
                    }
                }
                ContributeStep.ToiletLocation -> {
                    OutlinedTextField(
                        value = ui.flowSnapshot?.toiletLocationNote ?: "",
                        onValueChange = vm::setToiletLocation,
                        modifier = Modifier.fillMaxWidth(),
                        placeholder = { Text("Describe what's around ...") },
                        minLines = 4,
                    )
                }
                ContributeStep.ToiletAnother -> {
                    ContributeStepPresentation.optionsFor(step).forEach { opt ->
                        ContributeSingleChoiceRow(
                            label = opt,
                            selected = false,
                            onClick = { vm.chooseAnotherToilet(opt) },
                        )
                    }
                }
                ContributeStep.FinalReview -> {
                    val snap = ui.flowSnapshot
                    val photos = snap?.let {
                        it.completedEntrancePasses.flatMap { pass ->
                            pass.photos + pass.lobbyNotes.photos + pass.basementNotes.photos
                        } +
                        it.entrancePhotos + it.lobbyNotes.photos + it.basementNotes.photos +
                            it.completedElevatorPasses.flatMap { pass -> pass.notes.photos } +
                            it.elevatorNotes.photos +
                            it.completedToiletPasses.flatMap { pass -> pass.photos } +
                            it.toiletPhotos + it.toiletNotes.photos
                    } ?: emptyList()
                    ContributePhotosSection(
                        note = snap?.toiletNotes?.text ?: "",
                        photos = photos,
                        onNoteChange = vm::setFinalNote,
                        onAddPhoto = { photoPicker.launch("image/*") },
                        onRemovePhoto = vm::removePhoto,
                    )
                }
                ContributeStep.Submitted -> Unit
            }
            Spacer(Modifier.height(8.dp))
        }

        if (step !is ContributeStep.ElevatorAnother &&
            step !is ContributeStep.EntranceAnother &&
            step !is ContributeStep.ToiletAnother
        ) {
            ContributeContinueButton(
                title = ctaTitle,
                enabled = canContinue,
                loading = ui.isSubmitting,
                onClick = {
                    if (isFinal) vm.submit() else vm.goNext()
                },
            )
        }
    }

    if (showEntranceInfo) {
        AccessibleEntranceInfoSheet(onDismiss = { showEntranceInfo = false })
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
