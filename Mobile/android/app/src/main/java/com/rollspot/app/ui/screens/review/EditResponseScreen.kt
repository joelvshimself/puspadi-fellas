package com.rollspot.app.ui.screens.review

import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.UnfoldMore
import androidx.compose.material.icons.outlined.AddPhotoAlternate
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.rollspot.shared.reviews.EditPhoto
import app.rollspot.shared.reviews.EditRow
import app.rollspot.shared.reviews.EditSection
import app.rollspot.shared.reviews.ReviewEditModel
import app.rollspot.shared.reviews.ReviewEditState
import coil3.compose.AsyncImage
import com.rollspot.app.ui.rollspotSdk
import com.rollspot.app.ui.screens.contribute.jpegForUpload
import com.rollspot.app.ui.theme.BackCircleButton
import com.rollspot.app.ui.theme.ConfirmButtons
import com.rollspot.app.ui.theme.GlassSheet
import com.rollspot.app.ui.theme.LocalHazeState
import com.rollspot.app.ui.theme.Rollspot
import com.rollspot.app.ui.theme.SheetHeader
import com.rollspot.app.ui.theme.pressScale
import dev.chrisbanes.haze.HazeState
import dev.chrisbanes.haze.hazeSource
import kotlinx.coroutines.launch

/**
 * Edit Response (Figma "Edit Response Page", iOS EditResponseView): every answer of a submitted
 * review as a row with a menu, section photos and notes. Rules live in the shared ReviewEditModel.
 */
@Composable
fun EditResponseScreen(reviewId: String, onClose: () -> Unit, onSaved: () -> Unit, review: String? = null) {
    val sdk = rollspotSdk()
    val model = remember(reviewId) { sdk.reviewEditModel(reviewId) }
    val state by model.state.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()
    val haze = remember { HazeState() }
    var leaveSheet by remember { mutableStateOf(false) }
    val ready = state as? ReviewEditState.Ready

    LaunchedEffect(model) {
        model.load()
        if (review == "editResponseLeave") {
            model.setNotes("entrance", "Ramp available but there's still a step to the main floor.")
            leaveSheet = true
        }
    }
    LaunchedEffect(state) { if (state is ReviewEditState.Saved) onSaved() }

    fun leave() = if (ready?.isDirty == true) leaveSheet = true else onClose()
    BackHandler(enabled = !leaveSheet) { leave() }

    CompositionLocalProvider(LocalHazeState provides haze) {
        Box(Modifier.fillMaxSize().background(Color.White)) {
            Column(Modifier.fillMaxSize().hazeSource(haze).statusBarsPadding()) {
                TopBar(
                    canSave = ready?.canSave == true,
                    saving = ready?.isSaving == true,
                    onBack = ::leave,
                    onSave = { scope.launch { runCatching { model.save() } } },
                )
                when (val current = state) {
                    is ReviewEditState.Failed -> Column(
                        Modifier.fillMaxSize().padding(32.dp),
                        verticalArrangement = Arrangement.Center,
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Text(current.message, style = Rollspot.Subheadline, color = Rollspot.Secondary, textAlign = TextAlign.Center)
                        TextButton(onClick = { scope.launch { model.load() } }) { Text("Try again", fontWeight = FontWeight.SemiBold) }
                    }
                    is ReviewEditState.Ready -> LazyColumn(
                        Modifier.fillMaxSize().imePadding(),
                        contentPadding = PaddingValues(top = 12.dp, bottom = 40.dp),
                        verticalArrangement = Arrangement.spacedBy(28.dp),
                    ) {
                        (current.error ?: current.problem)?.let { message ->
                            item { Text(message, Modifier.padding(horizontal = 20.dp), style = Rollspot.Caption, color = Rollspot.ErrorRed) }
                        }
                        items(current.sections, key = { it.id }) { section -> SectionBlock(section, model) }
                    }
                    else -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
                }
            }

            GlassSheet(leaveSheet, onDismiss = { leaveSheet = false }) {
                SheetHeader("Leave editing?", "Your progress won't be saved if you leave now.")
                ConfirmButtons("Discard & Leave", onCancel = { leaveSheet = false }, onConfirm = { leaveSheet = false; onClose() })
            }
        }
    }
}

@Composable
private fun TopBar(canSave: Boolean, saving: Boolean, onBack: () -> Unit, onSave: () -> Unit) {
    Box(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp), contentAlignment = Alignment.Center) {
        BackCircleButton(onBack, Modifier.align(Alignment.CenterStart), size = 44.dp)
        Text("Edit Response", fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = Color.Black)
        val interaction = remember { MutableInteractionSource() }
        Box(
            Modifier.align(Alignment.CenterEnd).size(44.dp).pressScale(interaction).clip(CircleShape)
                .background(Color.White.copy(alpha = 0.7f)).border(0.5.dp, Color(0x14000000), CircleShape)
                .clickable(interactionSource = interaction, indication = null, enabled = canSave, onClick = onSave),
            contentAlignment = Alignment.Center,
        ) {
            if (saving) CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
            else Icon(Icons.Default.Check, "Save changes", tint = if (canSave) Rollspot.BrandBlue else Rollspot.Tertiary)
        }
    }
}

@Composable
private fun SectionBlock(section: EditSection, model: ReviewEditModel) {
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Column(Modifier.padding(horizontal = 20.dp)) {
            Text(section.title, fontSize = 20.sp, fontWeight = FontWeight.Bold, color = Color.Black)
            Text("Tap any answer to change it", style = Rollspot.Caption, color = Rollspot.Secondary)
        }
        Column(Modifier.padding(horizontal = 20.dp).fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(Rollspot.FieldFill)) {
            section.rows.forEachIndexed { index, row ->
                val group = row.group
                if (group != null && (index == 0 || section.rows[index - 1].group != group)) {
                    Text(
                        group, Modifier.padding(start = 14.dp, top = if (index == 0) 10.dp else 14.dp, bottom = 2.dp),
                        style = Rollspot.Caption.copy(fontWeight = FontWeight.SemiBold), color = Rollspot.Secondary,
                    )
                }
                AnswerRow(row, model)
                if (index < section.rows.lastIndex) HorizontalDivider(Modifier.padding(start = 14.dp), color = Color(0x1F3C3C43))
            }
        }
        PhotoStrip(section, model)
        section.notesKey?.let { key ->
            Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("Notes", style = Rollspot.Caption, color = Rollspot.Secondary)
                Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(Rollspot.FieldFill).padding(horizontal = 14.dp, vertical = 12.dp)) {
                    if (section.notes.isEmpty()) Text("None", style = Rollspot.Subheadline, color = Rollspot.Tertiary)
                    BasicTextField(
                        section.notes, { model.setNotes(key, it) },
                        textStyle = Rollspot.Subheadline.copy(color = Rollspot.Secondary), modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
        }
    }
}

@Composable
private fun AnswerRow(row: EditRow, model: ReviewEditModel) {
    var menu by remember { mutableStateOf(false) }
    Row(
        Modifier.fillMaxWidth().heightIn(min = 44.dp)
            .then(if (row.isText) Modifier else Modifier.clickable { menu = true })
            .padding(horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(row.label, style = Rollspot.Subheadline, color = Color.Black)
        Spacer(Modifier.width(8.dp).weight(1f))
        if (row.isText) {
            Box(Modifier.weight(1.3f), contentAlignment = Alignment.CenterEnd) {
                if (row.text.isEmpty()) Text(row.placeholder, style = Rollspot.Caption.copy(fontSize = 13.sp), color = Rollspot.Tertiary, maxLines = 1, overflow = TextOverflow.Ellipsis)
                BasicTextField(
                    row.text, { model.setText(row.id, it) }, singleLine = true,
                    textStyle = Rollspot.Caption.copy(fontSize = 13.sp, color = Rollspot.Secondary, textAlign = TextAlign.End),
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        } else {
            Box {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        row.value, style = Rollspot.Caption.copy(fontSize = 13.sp), maxLines = 1,
                        color = if (row.selected == null) Rollspot.BrandBlue else Rollspot.Secondary,
                    )
                    Icon(Icons.Default.UnfoldMore, null, Modifier.size(16.dp), tint = Rollspot.Secondary)
                }
                // The design's floating menu, with a check on the current answer.
                DropdownMenu(
                    menu, { menu = false },
                    shape = RoundedCornerShape(16.dp),
                    containerColor = Color(0xF2F7F7F8),
                ) {
                    row.options.forEach { option ->
                        DropdownMenuItem(
                            text = { Text(option.label, style = Rollspot.Subheadline) },
                            leadingIcon = {
                                Box(Modifier.size(18.dp)) {
                                    if (option.id == row.selected) Icon(Icons.Default.Check, null, Modifier.size(18.dp), tint = Color.Black)
                                }
                            },
                            onClick = { menu = false; model.choose(row.id, option.id) },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun PhotoStrip(section: EditSection, model: ReviewEditModel) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickMultipleVisualMedia(5)) { uris ->
        scope.launch {
            for (uri in uris) {
                val jpeg = jpegForUpload(context, uri) ?: continue
                if (!model.addPhoto(section.id, jpeg)) break
            }
        }
    }
    LazyRow(contentPadding = PaddingValues(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        if (section.canAddPhoto) item(key = "add") {
            val interaction = remember { MutableInteractionSource() }
            Column(
                Modifier.size(100.dp).pressScale(interaction).clip(RoundedCornerShape(12.dp)).background(Rollspot.FieldFill)
                    .dashedBorder(Color(0x598E8E93))
                    .clickable(interactionSource = interaction, indication = null) {
                        picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                    },
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Icon(Icons.Outlined.AddPhotoAlternate, null, Modifier.size(24.dp), tint = Rollspot.BrandBlue)
                Spacer(Modifier.height(6.dp))
                Text("Add Photos", fontSize = 11.sp, fontWeight = FontWeight.Medium, color = Rollspot.BrandBlue)
            }
        }
        items(section.photos, key = { it.id }) { photo ->
            Box(Modifier.size(100.dp).animateItem().clip(RoundedCornerShape(12.dp)).background(Rollspot.FieldFill)) {
                Thumbnail(photo)
                Box(
                    Modifier.align(Alignment.TopEnd).padding(6.dp).size(20.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.9f))
                        .clickable { model.removePhoto(section.id, photo.id) },
                    contentAlignment = Alignment.Center,
                ) { Icon(Icons.Default.Close, "Remove photo", Modifier.size(12.dp), tint = Color.Black) }
            }
        }
    }
}

@Composable
private fun Thumbnail(photo: EditPhoto) {
    val jpeg = photo.jpeg
    if (jpeg != null) {
        val bitmap = remember(photo.id) { android.graphics.BitmapFactory.decodeByteArray(jpeg, 0, jpeg.size)?.asImageBitmap() }
        bitmap?.let { androidx.compose.foundation.Image(it, null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop) }
    } else {
        AsyncImage(photo.url, photo.caption, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
    }
}

private fun Modifier.dashedBorder(color: Color) = drawBehind {
    drawRoundRect(
        color = color,
        style = Stroke(width = 1.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 3.dp.toPx()))),
        cornerRadius = CornerRadius(12.dp.toPx()),
    )
}
