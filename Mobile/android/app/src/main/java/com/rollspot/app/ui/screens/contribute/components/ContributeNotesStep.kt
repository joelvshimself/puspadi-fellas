package com.rollspot.app.ui.screens.contribute.components

import android.graphics.BitmapFactory
import androidx.activity.compose.BackHandler
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Chat
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.outlined.AddPhotoAlternate
import androidx.compose.material.icons.outlined.CameraAlt
import androidx.compose.material.icons.outlined.PhotoLibrary
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.rollspot.shared.reviews.LocalReviewPhoto
import com.rollspot.app.ui.theme.ContributeColors
import com.rollspot.app.ui.theme.pressScale

private val TileSize = 142.dp

/**
 * "Anything else you want to share?" (Figma "Question 3 - Filled", iOS ContributePhotosNotesStepView):
 * optional notes, then the section's photos with Add Photos (Choose Existing / Take New Photo),
 * tap a photo to caption it, ✕ to remove it.
 */
@Composable
fun ContributeNotesScreen(
    title: String,
    notes: String,
    onNotesChange: (String) -> Unit,
    photos: List<LocalReviewPhoto>,
    canAddPhoto: Boolean,
    onChooseExisting: () -> Unit,
    onTakePhoto: () -> Unit,
    onRemovePhoto: (String) -> Unit,
    onCaption: (fileId: String, caption: String) -> Unit,
    progressStep: Int,
    progress: Float,
    continueTitle: String,
    submitting: Boolean,
    onBack: () -> Unit,
    onContinue: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var captioning by remember { mutableStateOf<String?>(null) }
    Box(modifier.fillMaxSize().background(Color.White)) {
        Column(Modifier.fillMaxSize()) {
            ContributeStepProgressBar(currentStep = progressStep, subStepProgress = progress)
            ContributeFlowHeader(title = title, onBack = onBack)
            Column(
                Modifier.weight(1f).verticalScroll(rememberScrollState()).imePadding().padding(top = 62.dp, bottom = 8.dp),
            ) {
                Column(Modifier.padding(horizontal = 21.dp)) {
                    SectionTitle("Anything else you want to share?", inline = false)
                    Spacer(Modifier.height(14.dp))
                    NotesField(notes, onNotesChange)
                    Spacer(Modifier.height(34.dp))
                    SectionTitle("Photos", inline = true)
                    Spacer(Modifier.height(14.dp))
                }
                if (photos.isEmpty()) {
                    AddPhotoTile(wide = true, enabled = canAddPhoto, onChooseExisting, onTakePhoto, Modifier.padding(horizontal = 21.dp))
                } else {
                    // The strip runs to the screen edges, as in the design.
                    LazyRow(contentPadding = PaddingValues(horizontal = 21.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        if (canAddPhoto) item(key = "add") { AddPhotoTile(wide = false, enabled = true, onChooseExisting, onTakePhoto) }
                        items(photos, key = { it.fileId }) { photo ->
                            PhotoTile(photo, Modifier.animateItem(), onOpen = { captioning = photo.fileId }, onRemove = { onRemovePhoto(photo.fileId) })
                        }
                    }
                }
            }
            ContributeContinueButton(title = continueTitle, enabled = !submitting, loading = submitting, onClick = onContinue)
        }
        photos.firstOrNull { it.fileId == captioning }?.let { photo ->
            PhotoCaptionScreen(
                photo = photo,
                progressStep = progressStep,
                progress = progress,
                onSave = { onCaption(photo.fileId, it) },
                onDismiss = { captioning = null },
            )
        }
    }
}

@Composable
private fun SectionTitle(text: String, inline: Boolean) {
    val title: @Composable () -> Unit = { Text(text, fontSize = 22.sp, fontWeight = FontWeight.SemiBold, color = ContributeColors.Text) }
    val optional: @Composable () -> Unit = { Text("(Optional)", fontSize = 14.sp, color = ContributeColors.OptionalText) }
    if (inline) {
        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            title()
            Box(Modifier.padding(bottom = 3.dp)) { optional() }
        }
    } else {
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) { title(); optional() }
    }
}

@Composable
private fun NotesField(value: String, onChange: (String) -> Unit) {
    var focused by remember { mutableStateOf(false) }
    val shape = RoundedCornerShape(14.dp)
    val border by animateColorAsState(ContributeColors.Blue.copy(alpha = if (focused) 0.5f else 0f), tween(150), label = "border")
    Box(
        Modifier.fillMaxWidth().heightIn(min = 144.dp).clip(shape).background(ContributeColors.Fill)
            .border(2.dp, border, shape).padding(horizontal = 15.dp, vertical = 16.dp),
    ) {
        if (value.isEmpty()) Text("Tell us more about your experience ...", fontSize = 15.sp, color = ContributeColors.Placeholder)
        BasicTextField(
            value, onChange,
            textStyle = TextStyle(fontSize = 15.sp, color = ContributeColors.Text, lineHeight = 20.sp),
            modifier = Modifier.fillMaxWidth().onFocusChanged { focused = it.isFocused },
        )
    }
}

@Composable
private fun AddPhotoTile(
    wide: Boolean,
    enabled: Boolean,
    onChooseExisting: () -> Unit,
    onTakePhoto: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var menu by remember { mutableStateOf(false) }
    val interaction = remember { MutableInteractionSource() }
    val shape = RoundedCornerShape(14.dp)
    Box(modifier) {
        Column(
            Modifier
                .then(if (wide) Modifier.fillMaxWidth() else Modifier.width(TileSize))
                .height(TileSize)
                .pressScale(interaction)
                .clip(shape)
                .background(ContributeColors.Fill)
                .drawBehind {
                    drawRoundRect(
                        ContributeColors.Dash,
                        style = Stroke(1.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 4.dp.toPx()))),
                        cornerRadius = CornerRadius(14.dp.toPx()),
                    )
                }
                .clickable(interactionSource = interaction, indication = null, enabled = enabled) { menu = true },
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Icon(Icons.Outlined.AddPhotoAlternate, null, Modifier.size(26.dp), tint = ContributeColors.Blue)
            Spacer(Modifier.height(6.dp))
            Text("Add Photos", fontSize = 17.sp, fontWeight = FontWeight.Medium, color = ContributeColors.Blue)
        }
        // The design's floating card: Choose Existing / Take New Photo.
        DropdownMenu(menu, { menu = false }, shape = RoundedCornerShape(16.dp), containerColor = Color.White) {
            DropdownMenuItem(
                text = { Text("Choose Existing", fontSize = 15.sp, color = ContributeColors.Text) },
                leadingIcon = { Icon(Icons.Outlined.PhotoLibrary, null, tint = ContributeColors.Text) },
                onClick = { menu = false; onChooseExisting() },
            )
            DropdownMenuItem(
                text = { Text("Take New Photo", fontSize = 15.sp, color = ContributeColors.Text) },
                leadingIcon = { Icon(Icons.Outlined.CameraAlt, null, tint = ContributeColors.Text) },
                onClick = { menu = false; onTakePhoto() },
            )
        }
    }
}

@Composable
private fun PhotoTile(photo: LocalReviewPhoto, modifier: Modifier, onOpen: () -> Unit, onRemove: () -> Unit) {
    val bitmap = remember(photo.fileId) { BitmapFactory.decodeByteArray(photo.jpeg, 0, photo.jpeg.size)?.asImageBitmap() }
    val interaction = remember { MutableInteractionSource() }
    Box(modifier.size(TileSize)) {
        Box(
            Modifier.fillMaxSize().pressScale(interaction).clip(RoundedCornerShape(14.dp)).background(ContributeColors.Fill)
                .clickable(interactionSource = interaction, indication = null, onClick = onOpen)
                .semantics { contentDescription = if (photo.caption.isBlank()) "Photo, add a caption" else "Photo: ${photo.caption}" },
        ) {
            bitmap?.let { Image(it, null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop) }
            if (photo.caption.isNotBlank()) {
                // "Added caption shows caption icon".
                Box(
                    Modifier.align(Alignment.BottomStart).padding(8.dp).size(20.dp)
                        .background(Color.Black.copy(alpha = 0.75f), CircleShape).border(1.5.dp, Color.White, CircleShape),
                    contentAlignment = Alignment.Center,
                ) { Icon(Icons.AutoMirrored.Filled.Chat, null, Modifier.size(10.dp), tint = Color.White) }
            }
        }
        Box(
            Modifier.align(Alignment.TopEnd).size(36.dp).clickable(onClick = onRemove).semantics { contentDescription = "Remove photo" },
            contentAlignment = Alignment.Center,
        ) {
            Box(
                Modifier.size(18.dp).shadow(2.dp, CircleShape).background(Color.White, CircleShape),
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Default.Close, null, Modifier.size(11.dp), tint = Color.Black) }
        }
    }
}

/**
 * Photo viewer with a caption field (Figma "Photo Clicked to view" → "caption field goes up with
 * keyboard" → "Photo caption added, button activated"). The check turns blue once there's a caption.
 */
@Composable
fun PhotoCaptionScreen(
    photo: LocalReviewPhoto,
    progressStep: Int,
    progress: Float,
    onSave: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    var caption by remember(photo.fileId) { mutableStateOf(photo.caption) }
    var focused by remember { mutableStateOf(false) }
    val active = caption.isNotBlank()
    val bitmap = remember(photo.fileId) { BitmapFactory.decodeByteArray(photo.jpeg, 0, photo.jpeg.size)?.asImageBitmap() }
    BackHandler(onBack = onDismiss)
    Column(
        Modifier.fillMaxSize().background(Color.White).clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {}
            .statusBarsPadding().navigationBarsPadding().imePadding(),
    ) {
        ContributeStepProgressBar(currentStep = progressStep, subStepProgress = progress)
        Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 5.dp), horizontalArrangement = Arrangement.SpaceBetween) {
            ContributeCircleButton(onClick = onDismiss, description = "Back") {
                Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, null, Modifier.size(26.dp), tint = ContributeColors.BackChevron)
            }
            val fill by animateColorAsState(if (active) ContributeColors.Blue else ContributeColors.CircleButton, tween(200), label = "check")
            ContributeCircleButton(onClick = { onSave(caption); onDismiss() }, description = "Save caption", fill = fill) {
                Icon(Icons.Default.Check, null, Modifier.size(22.dp), tint = if (active) Color.White else ContributeColors.CheckOff)
            }
        }
        Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
            bitmap?.let { Image(it, null, Modifier.fillMaxWidth(), contentScale = ContentScale.FillWidth) }
        }
        val border by animateColorAsState(ContributeColors.Blue.copy(alpha = if (focused) 0.5f else 0f), tween(150), label = "field")
        Box(
            Modifier.padding(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 12.dp).fillMaxWidth().clip(CircleShape)
                .background(ContributeColors.Fill).border(2.dp, border, CircleShape).padding(horizontal = 16.dp, vertical = 15.dp),
        ) {
            if (caption.isEmpty()) Text("Add a caption ...", fontSize = 15.sp, color = ContributeColors.Placeholder)
            BasicTextField(
                caption, { caption = it.take(500) },
                textStyle = TextStyle(fontSize = 15.sp, color = ContributeColors.Text),
                maxLines = 4,
                modifier = Modifier.fillMaxWidth().onFocusChanged { focused = it.isFocused },
            )
        }
    }
}
