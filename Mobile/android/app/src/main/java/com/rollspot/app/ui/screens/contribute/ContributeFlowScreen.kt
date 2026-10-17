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
import app.rollspot.shared.reviews.newPhotoFileId
import com.rollspot.app.ui.rollspotSdk
import com.rollspot.app.ui.screens.contribute.components.*
import java.io.ByteArrayOutputStream

@Composable
fun ContributeFlowScreen(placeId: String, onFinished: () -> Unit) {
    val sdk = rollspotSdk()
    val vm: ContributeFlowViewModel = viewModel(key = placeId) { ContributeFlowViewModel(sdk, placeId) }
    val ui by vm.ui.collectAsStateWithLifecycle()
    val context = LocalContext.current

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
            if (!isCategoryPick && hero != ContributeHeroAsset.None) {
                ContributeHeroImage(hero)
            }

            ContributeQuestionBlock(
                eyebrow = if (isCategoryPick) null else ContributeStepPresentation.eyebrow(step),
                title = ContributeStepPresentation.questionTitle(step),
                subtitle = ContributeStepPresentation.questionSubtitle(step),
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
                    val selected = when (step.location) {
                        EntranceLocation.Lobby -> ui.flowSnapshot?.lobbyTags ?: emptySet()
                        EntranceLocation.Basement -> ui.flowSnapshot?.basementTags ?: emptySet()
                    }
                    ContributeStepPresentation.tagOptions(step).forEach { tag ->
                        ContributeTagChip(
                            label = tag,
                            selected = tag in selected,
                            onClick = { vm.toggleEntranceTag(step.location, tag) },
                        )
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
                ContributeStep.ToiletInitial -> {
                    val selected = ui.flowSnapshot?.toiletInitialAnswer
                    ContributeStepPresentation.optionsFor(step).forEach { opt ->
                        ContributeSingleChoiceRow(
                            label = opt,
                            selected = selected == opt,
                            onClick = { vm.setToiletInitial(opt) },
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
                }
                ContributeStep.ToiletLocation -> {
                    OutlinedTextField(
                        value = ui.flowSnapshot?.toiletLocationNote ?: "",
                        onValueChange = vm::setToiletLocation,
                        modifier = Modifier.fillMaxWidth(),
                        placeholder = { Text("e.g. Level 2, near food court") },
                    )
                }
                ContributeStep.FinalReview -> {
                    val snap = ui.flowSnapshot
                    val photos = snap?.let {
                        it.entrancePhotos + it.lobbyNotes.photos + it.basementNotes.photos +
                            it.elevatorNotes.photos + it.toiletNotes.photos
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
