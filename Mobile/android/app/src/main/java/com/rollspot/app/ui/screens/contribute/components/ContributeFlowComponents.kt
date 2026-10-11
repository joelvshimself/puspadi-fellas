package com.rollspot.app.ui.screens.contribute.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.DoorFront
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material.icons.outlined.Photo
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import android.graphics.BitmapFactory
import app.rollspot.shared.reviews.LocalReviewPhoto
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.rollspot.shared.reviews.ContributeHeroAsset
import app.rollspot.shared.reviews.ContributeStepPresentation
import com.rollspot.app.R
import com.rollspot.app.ui.screens.contribute.rememberHeroPainter
import com.rollspot.app.ui.screens.contribute.tagChipDrawable
import com.rollspot.app.ui.theme.RollspotBlue

@Composable
fun ContributeFlowHeader(title: String, onBack: () -> Unit) {
    Box(
        Modifier
            .fillMaxWidth()
            .height(52.dp)
            .padding(horizontal = 12.dp),
    ) {
        Text(
            title,
            modifier = Modifier.align(Alignment.Center),
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
        )
        IconButton(
            onClick = onBack,
            modifier = Modifier
                .align(Alignment.CenterStart)
                .size(44.dp)
                .background(MaterialTheme.colorScheme.surfaceVariant, CircleShape),
        ) {
            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
        }
    }
}

@Composable
fun ContributeStepProgressBar(currentStep: Int, subStepProgress: Float) {
    val titles = ContributeStepPresentation.progressStepTitles
    Column(Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 8.dp)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            titles.forEachIndexed { index, label ->
                val stepNum = index + 1
                Text(
                    label,
                    fontSize = 11.sp,
                    fontWeight = if (stepNum == currentStep) FontWeight.SemiBold else FontWeight.Normal,
                    color = if (stepNum <= currentStep) RollspotBlue else MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        Spacer(Modifier.height(8.dp))
        Box(Modifier.fillMaxWidth().height(4.dp)) {
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(2.dp)
                    .align(Alignment.Center)
                    .background(MaterialTheme.colorScheme.surfaceVariant),
            )
            val fraction = ((currentStep - 1) + subStepProgress.coerceIn(0f, 1f)) / 4f
            Box(
                Modifier
                    .fillMaxWidth(fraction.coerceIn(0.05f, 1f))
                    .height(2.dp)
                    .align(Alignment.CenterStart)
                    .background(RollspotBlue),
            )
        }
    }
}

@Composable
fun ContributeHeroImage(asset: ContributeHeroAsset, modifier: Modifier = Modifier) {
    val painter = rememberHeroPainter(asset) ?: return
    Image(
        painter = painter,
        contentDescription = null,
        modifier = modifier
            .fillMaxWidth()
            .height(180.dp),
        contentScale = ContentScale.Fit,
    )
}

@Composable
fun ContributeContinueButton(
    title: String,
    enabled: Boolean,
    loading: Boolean = false,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Button(
        onClick = onClick,
        enabled = enabled && !loading,
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 12.dp)
            .height(52.dp),
        shape = RoundedCornerShape(26.dp),
        colors = ButtonDefaults.buttonColors(
            disabledContainerColor = MaterialTheme.colorScheme.surfaceVariant,
            disabledContentColor = MaterialTheme.colorScheme.onSurfaceVariant,
        ),
    ) {
        if (loading) {
            CircularProgressIndicator(Modifier.size(22.dp), color = Color.White, strokeWidth = 2.dp)
        } else {
            Text(title, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
fun ContributeQuestionBlock(eyebrow: String?, title: String, subtitle: String? = null) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        eyebrow?.let {
            Text(it, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Text(title, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
        subtitle?.let {
            Text(it, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
fun ContributeTagChip(label: String, selected: Boolean, onClick: () -> Unit) {
    val iconId = tagChipDrawable(label)
    val shape = RoundedCornerShape(50)
    val bg = if (selected) RollspotBlue.copy(alpha = 0.08f) else MaterialTheme.colorScheme.surfaceVariant
    val border = if (selected) BorderStroke(1.5.dp, RollspotBlue) else null
    Row(
        modifier = Modifier
            .padding(vertical = 4.dp)
            .clip(shape)
            .background(bg, shape)
            .then(if (border != null) Modifier.border(border, shape) else Modifier)
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        if (iconId != null) {
            Image(
                painter = painterResource(iconId),
                contentDescription = null,
                modifier = Modifier.size(14.dp),
            )
        }
        Text(
            label.lowercase().replaceFirstChar { it.titlecase() },
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium,
            color = if (selected) RollspotBlue else MaterialTheme.colorScheme.onSurface,
        )
    }
}

@Composable
fun ContributeSingleChoiceRow(label: String, selected: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(50)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp)
            .clip(shape)
            .background(MaterialTheme.colorScheme.surfaceVariant, shape)
            .then(
                if (selected) Modifier.border(BorderStroke(1.5.dp, RollspotBlue), shape) else Modifier,
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 18.dp, vertical = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            label,
            modifier = Modifier.weight(1f),
            fontWeight = FontWeight.Medium,
            color = if (selected) RollspotBlue else MaterialTheme.colorScheme.onSurface,
        )
        if (selected) {
            Icon(Icons.Default.Check, contentDescription = null, tint = RollspotBlue, modifier = Modifier.size(20.dp))
        }
    }
}

@Composable
fun ContributeEntranceLocationRow(label: String, selected: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(50)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp)
            .clip(shape)
            .background(MaterialTheme.colorScheme.surfaceVariant, shape)
            .then(
                if (selected) Modifier.border(BorderStroke(1.5.dp, RollspotBlue), shape) else Modifier,
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 18.dp, vertical = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Icon(
            Icons.Default.DoorFront,
            contentDescription = null,
            tint = if (selected) RollspotBlue else MaterialTheme.colorScheme.onSurface,
        )
        Text(
            label,
            modifier = Modifier.weight(1f),
            fontWeight = FontWeight.Medium,
            color = if (selected) RollspotBlue else MaterialTheme.colorScheme.onSurface,
        )
        if (selected) {
            Icon(Icons.Default.Check, contentDescription = null, tint = RollspotBlue, modifier = Modifier.size(20.dp))
        } else {
            Icon(Icons.Outlined.Circle, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(20.dp))
        }
    }
}

@Composable
fun ContributePhotosSection(
    note: String,
    photos: List<LocalReviewPhoto>,
    onNoteChange: (String) -> Unit,
    onAddPhoto: () -> Unit,
    onRemovePhoto: (String) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        OutlinedCard(
            onClick = onAddPhoto,
            modifier = Modifier.fillMaxWidth(),
            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
        ) {
            Column(
                Modifier.fillMaxWidth().padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Icon(Icons.Outlined.Photo, contentDescription = null, tint = RollspotBlue, modifier = Modifier.size(32.dp))
                Spacer(Modifier.height(8.dp))
                Text("Add Photos", fontWeight = FontWeight.SemiBold)
            }
        }
        if (photos.isNotEmpty()) {
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(photos, key = { it.fileId }) { photo ->
                    val bitmap = remember(photo.fileId) {
                        BitmapFactory.decodeByteArray(photo.jpeg, 0, photo.jpeg.size)?.asImageBitmap()
                    }
                    Box {
                        if (bitmap != null) {
                            Image(
                                bitmap = bitmap,
                                contentDescription = null,
                                modifier = Modifier
                                    .size(72.dp)
                                    .clip(RoundedCornerShape(12.dp)),
                                contentScale = ContentScale.Crop,
                            )
                        }
                        IconButton(
                            onClick = { onRemovePhoto(photo.fileId) },
                            modifier = Modifier
                                .align(Alignment.TopEnd)
                                .size(28.dp)
                                .background(MaterialTheme.colorScheme.surface.copy(alpha = 0.9f), CircleShape),
                        ) {
                            Icon(Icons.Default.Close, contentDescription = "Remove", modifier = Modifier.size(16.dp))
                        }
                    }
                }
            }
        }
        Text("Notes", fontWeight = FontWeight.SemiBold)
        OutlinedTextField(
            value = note,
            onValueChange = onNoteChange,
            modifier = Modifier.fillMaxWidth().heightIn(min = 120.dp),
            placeholder = { Text("Your experience…") },
            shape = RoundedCornerShape(16.dp),
        )
    }
}

@Composable
fun ContributeSubmittedScreen(onDone: () -> Unit) {
    Box(Modifier.fillMaxSize()) {
        Box(
            Modifier
                .fillMaxWidth()
                .height(260.dp)
                .background(
                    Brush.verticalGradient(
                        colors = listOf(Color(0xFF94CAF7), MaterialTheme.colorScheme.background),
                    ),
                ),
        )
        Column(
            Modifier.fillMaxSize().padding(horizontal = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.height(48.dp))
            Image(
                painter = painterResource(R.drawable.contribute_thank_you),
                contentDescription = null,
                modifier = Modifier.fillMaxWidth().height(220.dp),
                contentScale = ContentScale.Fit,
            )
            Text("Review Submitted!", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
            Text(
                "Thank you for helping out!",
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.weight(1f))
            ContributeContinueButton(title = "Okey", enabled = true, onClick = onDone)
            Spacer(Modifier.height(24.dp))
        }
    }
}
