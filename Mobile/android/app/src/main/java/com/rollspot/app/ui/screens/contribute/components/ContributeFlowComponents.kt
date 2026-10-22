package com.rollspot.app.ui.screens.contribute.components

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.Image
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.DoorFront
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.outlined.Photo
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.viewinterop.AndroidView
import android.net.Uri
import android.widget.VideoView
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import android.graphics.BitmapFactory
import app.rollspot.shared.reviews.LocalReviewPhoto
import androidx.compose.ui.layout.ContentScale
import androidx.annotation.DrawableRes
import androidx.annotation.RawRes
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.rollspot.shared.reviews.ContributeHeroAsset
import app.rollspot.shared.reviews.ParkingInfo
import app.rollspot.shared.reviews.PathwayInfoCatalog
import app.rollspot.shared.reviews.PathwayInfoPage
import kotlinx.coroutines.launch
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
    val fraction = ((currentStep - 1) + subStepProgress.coerceIn(0f, 1f)) / 4f
    val clamped = fraction.coerceIn(0.05f, 1f)
    Box(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp, vertical = 8.dp)
            .height(4.dp)
            .clip(RoundedCornerShape(2.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant),
    ) {
        Box(
            Modifier
                .fillMaxWidth(clamped)
                .fillMaxHeight()
                .background(RollspotBlue),
        )
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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FollowUpStillCard(
    @DrawableRes drawableRes: Int,
    infoTitle: String,
    infoSections: List<Pair<String, String>>,
    modifier: Modifier = Modifier,
) {
    var showInfo by remember { mutableStateOf(false) }
    Box(
        modifier
            .fillMaxWidth()
            .height(220.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(Color.White)
            .clickable { showInfo = true },
        contentAlignment = Alignment.Center,
    ) {
        Image(
            painter = painterResource(drawableRes),
            contentDescription = null,
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            contentScale = ContentScale.Fit,
        )
        OverlayCircleButton(
            onClick = { showInfo = true },
            fill = RollspotBlue,
            modifier = Modifier.align(Alignment.BottomEnd).padding(8.dp),
        ) {
            Icon(Icons.Outlined.Info, contentDescription = infoTitle, tint = Color.White, modifier = Modifier.size(16.dp))
        }
    }
    if (showInfo) {
        FollowUpInfoSheet(infoTitle = infoTitle, infoSections = infoSections, onDismiss = { showInfo = false })
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RampLoopVideoCard(
    @RawRes rawRes: Int,
    infoTitle: String,
    infoSections: List<Pair<String, String>>,
    @RawRes infoRawRes: Int? = null,
    modifier: Modifier = Modifier,
) {
    var showInfo by remember { mutableStateOf(false) }
    LoopingVideoSurface(
        rawRes = rawRes,
        modifier = modifier,
        onSurfaceClick = { showInfo = true },
        infoContentDescription = infoTitle,
        onInfo = { showInfo = true },
    )
    if (showInfo) {
        FollowUpInfoSheet(
            infoTitle = infoTitle,
            infoSections = infoSections,
            infoRawRes = infoRawRes,
            onDismiss = { showInfo = false },
        )
    }
}

@Composable
private fun LoopingVideoSurface(
    @RawRes rawRes: Int,
    modifier: Modifier = Modifier,
    onSurfaceClick: (() -> Unit)? = null,
    infoContentDescription: String? = null,
    onInfo: (() -> Unit)? = null,
) {
    val context = LocalContext.current
    var playing by remember { mutableStateOf(true) }
    val videoView = remember(rawRes) {
        VideoView(context).apply {
            setVideoURI(Uri.parse("android.resource://${context.packageName}/$rawRes"))
            setOnPreparedListener { player ->
                player.isLooping = true
                start()
            }
        }
    }
    DisposableEffect(videoView) {
        onDispose { videoView.stopPlayback() }
    }

    Box(
        modifier
            .fillMaxWidth()
            .height(220.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(Color.White),
    ) {
        AndroidView(factory = { videoView }, modifier = Modifier.fillMaxSize())
        if (onSurfaceClick != null) {
            Box(Modifier.fillMaxSize().clickable { onSurfaceClick() })
        }
        OverlayCircleButton(
            onClick = {
                if (playing) videoView.pause() else videoView.start()
                playing = !playing
            },
            modifier = Modifier.align(Alignment.TopEnd).padding(8.dp),
        ) {
            Icon(
                if (playing) Icons.Filled.Pause else Icons.Filled.PlayArrow,
                contentDescription = if (playing) "Pause" else "Play",
                modifier = Modifier.size(16.dp),
            )
        }
        if (onInfo != null) {
            OverlayCircleButton(
                onClick = onInfo,
                fill = RollspotBlue,
                modifier = Modifier.align(Alignment.BottomEnd).padding(8.dp),
            ) {
                Icon(
                    Icons.Outlined.Info,
                    contentDescription = infoContentDescription,
                    tint = Color.White,
                    modifier = Modifier.size(16.dp),
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FollowUpInfoSheet(
    infoTitle: String,
    infoSections: List<Pair<String, String>>,
    @RawRes infoRawRes: Int? = null,
    onDismiss: () -> Unit,
) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = MaterialTheme.colorScheme.surfaceVariant,
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(bottom = 32.dp)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            if (infoRawRes != null) {
                LoopingVideoSurface(rawRes = infoRawRes)
            }
            Text(infoTitle, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            infoSections.forEach { (title, body) ->
                RampInfoBlock(title = title, body = body, headingMuted = infoRawRes != null)
            }
            if (infoRawRes != null) {
                HorizontalDivider()
            }
        }
    }
}

@Composable
private fun OverlayCircleButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    fill: Color = MaterialTheme.colorScheme.surfaceVariant,
    content: @Composable () -> Unit,
) {
    Box(
        modifier
            .size(32.dp)
            .clip(CircleShape)
            .background(fill)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        content()
    }
}

@Composable
private fun RampInfoBlock(title: String, body: String, headingMuted: Boolean = false) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        if (title.isNotEmpty()) {
            Text(
                title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = if (headingMuted) {
                    MaterialTheme.colorScheme.onSurfaceVariant
                } else {
                    MaterialTheme.colorScheme.onSurface
                },
            )
        }
        Text(body, style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
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
fun ContributeQuestionBlock(
    eyebrow: String?,
    title: String,
    subtitle: String? = null,
    onInfo: (() -> Unit)? = null,
) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        eyebrow?.let {
            Text(it, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Row(verticalAlignment = Alignment.Top) {
            Text(
                title,
                modifier = Modifier.weight(1f),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
            )
            if (onInfo != null) {
                IconButton(onClick = onInfo, modifier = Modifier.size(36.dp)) {
                    Box(
                        Modifier
                            .size(28.dp)
                            .background(MaterialTheme.colorScheme.surfaceVariant, CircleShape),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            Icons.Outlined.Info,
                            contentDescription = "Accessible entrance info",
                            modifier = Modifier.size(16.dp),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
        }
        subtitle?.let {
            Text(it, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AccessibleEntranceInfoSheet(onDismiss: () -> Unit) {
    val points = listOf(
        "Ramps",
        "Handrails",
        "Automatic doors",
        "Security assistance",
        "Wheelchair loans available",
    )
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = MaterialTheme.colorScheme.surfaceVariant,
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(bottom = 32.dp)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Image(
                painter = painterResource(R.drawable.contribute_lobby),
                contentDescription = null,
                modifier = Modifier.fillMaxWidth().height(160.dp),
                contentScale = ContentScale.Fit,
            )
            Text("Accessible Entrance", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            Text(
                "Entrances require non-obstructed pathways for someone to navigate independently to be accessible.",
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            HorizontalDivider()
            points.forEach { point ->
                Text("•  $point", style = MaterialTheme.typography.bodyLarge)
            }
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
fun FollowUpPhotosRow(
    photos: List<LocalReviewPhoto>,
    canAdd: Boolean = true,
    onAddPhoto: () -> Unit,
    onRemovePhoto: (String) -> Unit,
) {
    if (photos.isEmpty()) {
        if (canAdd) FollowUpAddPhotoTile(wide = true, onClick = onAddPhoto)
    } else {
        Row(
            Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            if (canAdd) FollowUpAddPhotoTile(wide = false, onClick = onAddPhoto)
            photos.forEach { photo ->
                val bitmap = remember(photo.fileId) {
                    BitmapFactory.decodeByteArray(photo.jpeg, 0, photo.jpeg.size)?.asImageBitmap()
                }
                Box(Modifier.size(120.dp)) {
                    if (bitmap != null) {
                        Image(
                            bitmap = bitmap,
                            contentDescription = null,
                            modifier = Modifier.fillMaxSize().clip(RoundedCornerShape(16.dp)),
                            contentScale = ContentScale.Crop,
                        )
                    }
                    IconButton(
                        onClick = { onRemovePhoto(photo.fileId) },
                        modifier = Modifier
                            .align(Alignment.TopEnd)
                            .padding(4.dp)
                            .size(24.dp)
                            .background(Color.White.copy(alpha = 0.9f), CircleShape),
                    ) {
                        Icon(Icons.Default.Close, contentDescription = "Remove", modifier = Modifier.size(14.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun FollowUpAddPhotoTile(wide: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(16.dp)
    Column(
        Modifier
            .then(if (wide) Modifier.fillMaxWidth() else Modifier.width(120.dp))
            .height(120.dp)
            .clip(shape)
            .border(BorderStroke(1.5.dp, RollspotBlue.copy(alpha = 0.4f)), shape)
            .clickable(onClick = onClick)
            .padding(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(Icons.Outlined.Photo, contentDescription = null, tint = RollspotBlue, modifier = Modifier.size(28.dp))
        Spacer(Modifier.height(6.dp))
        Text("Add Photos", fontWeight = FontWeight.SemiBold, color = RollspotBlue, fontSize = 14.sp)
        Text("(Optional)", color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 12.sp)
    }
}

@Composable
fun ContributeAddPhotosBox(
    photos: List<LocalReviewPhoto>,
    onAddPhoto: () -> Unit,
    onRemovePhoto: (String) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
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
                Text("Add Photos", fontWeight = FontWeight.SemiBold, color = RollspotBlue)
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
        ContributeAddPhotosBox(photos = photos, onAddPhoto = onAddPhoto, onRemovePhoto = onRemovePhoto)
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
fun ContributeSubmittedScreen(onDone: () -> Unit, modifier: Modifier = Modifier) {
    Box(modifier.fillMaxSize()) {
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

@Composable
fun ContributeNoticeRow(label: String, selected: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(50)
    Text(
        label,
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp)
            .clip(shape)
            .background(MaterialTheme.colorScheme.surfaceVariant, shape)
            .then(if (selected) Modifier.border(BorderStroke(1.5.dp, RollspotBlue), shape) else Modifier)
            .clickable(onClick = onClick)
            .padding(horizontal = 18.dp, vertical = 16.dp),
        fontWeight = FontWeight.Medium,
        color = if (selected) RollspotBlue else MaterialTheme.colorScheme.onSurface,
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PathwayInfoSheet(onDismiss: () -> Unit) {
    val pages = PathwayInfoCatalog.pages
    val pagerState = rememberPagerState { pages.size }
    val scope = rememberCoroutineScope()
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = MaterialTheme.colorScheme.surfaceVariant,
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .padding(bottom = 32.dp)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            HorizontalPager(
                state = pagerState,
                pageSpacing = 12.dp,
                modifier = Modifier.fillMaxWidth().height(210.dp),
            ) { index ->
                PathwayCarouselVideo(
                    rawRes = pathwayVideoRes(pages[index].videoKey),
                    active = pagerState.currentPage == index,
                )
            }
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
            ) {
                pages.forEachIndexed { index, page ->
                    val selected = pagerState.currentPage == index
                    Text(
                        page.chip,
                        modifier = Modifier
                            .clip(RoundedCornerShape(50))
                            .background(if (selected) RollspotBlue else Color.White)
                            .clickable {
                                scope.launch { pagerState.animateScrollToPage(index) }
                            }
                            .padding(horizontal = 14.dp, vertical = 10.dp),
                        color = if (selected) Color.White else Color.Black,
                        fontWeight = FontWeight.Bold,
                        fontSize = 13.sp,
                    )
                }
            }
            AnimatedContent(
                targetState = pagerState.currentPage,
                transitionSpec = {
                    (slideInHorizontally { it / 3 } + fadeIn()) togetherWith
                        (slideOutHorizontally { -it / 3 } + fadeOut())
                },
                label = "pathwayInfo",
            ) { index ->
                PathwayInfoCopy(pages[index])
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ParkingInfoSheet(onDismiss: () -> Unit) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = MaterialTheme.colorScheme.surfaceVariant,
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .padding(bottom = 32.dp)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Box(Modifier.fillMaxWidth().height(210.dp)) {
                PathwayCarouselVideo(rawRes = R.raw.parking_accessible_parking, active = true)
            }
            Text(ParkingInfo.title, style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            ParkingInfo.sections.forEach { section ->
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(section.title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    Text(
                        section.body,
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}

@Composable
private fun PathwayInfoCopy(page: PathwayInfoPage) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(page.title, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
        Text(page.body, style = MaterialTheme.typography.bodyLarge)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Icon(Icons.Filled.Warning, contentDescription = null, tint = Color(0xFFE53935), modifier = Modifier.size(18.dp))
            Text("What to avoid:", fontWeight = FontWeight.SemiBold)
        }
        page.avoid.forEach { point ->
            Text(
                buildAnnotatedString {
                    append("•  ")
                    withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append(point.lead) }
                    append(point.rest)
                },
                style = MaterialTheme.typography.bodyLarge,
            )
        }
    }
}

@Composable
private fun PathwayCarouselVideo(@RawRes rawRes: Int, active: Boolean) {
    val context = LocalContext.current
    var playing by remember(rawRes) { mutableStateOf(false) }
    val shouldPlay = remember(rawRes) { object { var value = false } }
    val videoView = remember(rawRes) {
        VideoView(context).apply {
            setVideoURI(Uri.parse("android.resource://${context.packageName}/$rawRes"))
            setOnPreparedListener { player ->
                player.isLooping = true
                if (shouldPlay.value) start()
            }
        }
    }
    DisposableEffect(videoView) {
        onDispose { videoView.stopPlayback() }
    }
    LaunchedEffect(active) {
        shouldPlay.value = active
        if (active) {
            videoView.start()
            playing = true
        } else {
            videoView.pause()
            videoView.seekTo(0)
            playing = false
        }
    }
    Box(
        Modifier
            .fillMaxSize()
            .clip(RoundedCornerShape(20.dp))
            .background(Color.White),
    ) {
        AndroidView(factory = { videoView }, modifier = Modifier.fillMaxSize())
        OverlayCircleButton(
            onClick = {
                if (playing) {
                    shouldPlay.value = false
                    videoView.pause()
                } else {
                    shouldPlay.value = true
                    videoView.start()
                }
                playing = !playing
            },
            modifier = Modifier.align(Alignment.TopEnd).padding(8.dp),
        ) {
            Icon(
                if (playing) Icons.Filled.Pause else Icons.Filled.PlayArrow,
                contentDescription = if (playing) "Pause" else "Play",
                modifier = Modifier.size(16.dp),
            )
        }
    }
}

@RawRes
private fun pathwayVideoRes(videoKey: String): Int = when (videoKey) {
    "width" -> R.raw.pathways_width
    "obstructions" -> R.raw.pathways_obstructions
    else -> R.raw.pathways_surfaces
}
