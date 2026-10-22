package com.rollspot.app.ui.screens.contribute.components

import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.outlined.WarningAmber
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.unit.Dp
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import com.rollspot.app.ui.theme.ContributeColors
import com.rollspot.app.ui.theme.Rollspot
import com.rollspot.app.ui.theme.pressScale
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

/** Back circle and centred title, under the progress bar (Figma contribute frames). */
@Composable
fun ContributeFlowHeader(title: String, onBack: () -> Unit, trailing: @Composable (() -> Unit)? = null) {
    Box(
        Modifier
            .fillMaxWidth()
            .height(54.dp)
            .padding(horizontal = 20.dp),
    ) {
        Text(
            title,
            modifier = Modifier.align(Alignment.Center),
            fontSize = 17.sp,
            fontWeight = FontWeight.SemiBold,
            color = ContributeColors.Text,
        )
        ContributeCircleButton(onClick = onBack, modifier = Modifier.align(Alignment.CenterStart), description = "Back") {
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, null, Modifier.size(26.dp), tint = ContributeColors.BackChevron)
        }
        trailing?.let { Box(Modifier.align(Alignment.CenterEnd)) { it() } }
    }
}

/** 44dp light circle with a soft shadow: back, and the caption screen's check. */
@Composable
fun ContributeCircleButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    description: String,
    fill: Color = ContributeColors.CircleButton,
    content: @Composable () -> Unit,
) {
    val interaction = remember { MutableInteractionSource() }
    Box(
        modifier
            .size(44.dp)
            .pressScale(interaction)
            .shadow(3.dp, CircleShape, ambientColor = Color(0x14000000), spotColor = Color(0x14000000))
            .background(fill, CircleShape)
            .clickable(interactionSource = interaction, indication = null, onClick = onClick)
            .semantics { contentDescription = description },
        contentAlignment = Alignment.Center,
    ) { content() }
}

/** Top progress line: 20dp side insets, above the back button (Figma). */
@Composable
fun ContributeStepProgressBar(currentStep: Int, subStepProgress: Float) {
    val fraction = ((currentStep - 1) + subStepProgress.coerceIn(0f, 1f)) / 4f
    val clamped by animateFloatAsState(fraction.coerceIn(0.05f, 1f), tween(250, easing = Rollspot.EaseOut), label = "progress")
    Box(
        Modifier
            .fillMaxWidth()
            .padding(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 4.dp)
            .height(4.dp)
            .clip(CircleShape)
            .background(ContributeColors.ProgressTrack),
    ) {
        Box(
            Modifier
                .fillMaxWidth(clamped)
                .fillMaxHeight()
                .clip(CircleShape)
                .background(ContributeColors.ProgressFill),
        )
    }
}

/** Plain (card-less) illustration: 134dp on questions, 120dp on "Take or upload a photo" (Figma). */
@Composable
fun ContributeHeroImage(asset: ContributeHeroAsset, modifier: Modifier = Modifier, height: Dp = 134.dp) {
    val painter = rememberHeroPainter(asset) ?: return
    Image(
        painter = painter,
        contentDescription = null,
        modifier = modifier.fillMaxWidth().height(height),
        contentScale = ContentScale.Fit,
    )
}

/** The white card around a question's illustration or loop (Figma: 262dp, 16dp corners, hairline). */
fun Modifier.contributeIllustrationCard(): Modifier = this
    .fillMaxWidth()
    .height(262.dp)
    .clip(RoundedCornerShape(16.dp))
    .background(Color.White)
    .border(1.dp, Color(0xFFF0F0F0), RoundedCornerShape(16.dp))

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FollowUpStillCard(
    @DrawableRes drawableRes: Int,
    infoTitle: String,
    infoSections: List<Pair<String, String>>,
    modifier: Modifier = Modifier,
) {
    var showInfo by remember { mutableStateOf(false) }
    Box(modifier.contributeIllustrationCard().clickable { showInfo = true }, contentAlignment = Alignment.Center) {
        Image(
            painter = painterResource(drawableRes),
            contentDescription = null,
            modifier = Modifier.fillMaxSize().padding(16.dp),
            contentScale = ContentScale.Fit,
        )
        CardInfoButton(infoTitle, Modifier.align(Alignment.BottomEnd)) { showInfo = true }
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

    Box(modifier.contributeIllustrationCard()) {
        AndroidView(factory = { videoView }, modifier = Modifier.fillMaxSize())
        if (onSurfaceClick != null) {
            Box(Modifier.fillMaxSize().clickable { onSurfaceClick() })
        }
        CardPauseButton(playing, Modifier.align(Alignment.TopEnd)) {
            if (playing) videoView.pause() else videoView.start()
            playing = !playing
        }
        if (onInfo != null) {
            CardInfoButton(infoContentDescription ?: "More information", Modifier.align(Alignment.BottomEnd), onInfo)
        }
    }
}

/** Explanation sheet behind the card's "i": grey sheet, white card with the loop, title, headings, body. */
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
        containerColor = Color(0xFFE8E8E8),
        shape = RoundedCornerShape(topStart = 34.dp, topEnd = 34.dp),
    ) {
        Column(
            Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(bottom = 24.dp).navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            if (infoRawRes != null) {
                LoopingVideoSurface(rawRes = infoRawRes, modifier = Modifier.padding(bottom = 6.dp))
            }
            Text(infoTitle, fontSize = 20.sp, fontWeight = FontWeight.SemiBold, color = ContributeColors.Text)
            infoSections.forEach { (title, body) -> RampInfoBlock(title = title, body = body) }
        }
    }
}

/** Small grey pause/play dot, top-right of the card. The hit area is larger than the dot. */
@Composable
private fun CardPauseButton(playing: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Box(
        modifier.size(40.dp).clickable(onClick = onClick).semantics { contentDescription = if (playing) "Pause" else "Play" },
        contentAlignment = Alignment.Center,
    ) {
        Box(Modifier.size(22.dp).background(ContributeColors.CircleButton, CircleShape), contentAlignment = Alignment.Center) {
            Icon(if (playing) Icons.Filled.Pause else Icons.Filled.PlayArrow, null, Modifier.size(11.dp), tint = Color(0xFF8E8E93))
        }
    }
}

/** Small blue "i", bottom-right of the card: opens the explanation sheet. */
@Composable
private fun CardInfoButton(description: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Box(
        modifier.size(40.dp).clickable(onClick = onClick).semantics { contentDescription = description },
        contentAlignment = Alignment.Center,
    ) {
        Box(Modifier.size(16.dp).background(ContributeColors.Blue, CircleShape), contentAlignment = Alignment.Center) {
            Text("i", fontSize = 10.sp, fontWeight = FontWeight.Black, color = Color.White, lineHeight = 10.sp)
        }
    }
}

@Composable
private fun RampInfoBlock(title: String, body: String) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        if (title.isNotEmpty()) Text(title, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Color(0xFF575757))
        Text(body, fontSize = 13.sp, lineHeight = 18.sp, color = Color(0xFF5D5D5D))
    }
}

/** The flow's bottom button: #0099FE pill, grey #E8E8E8 while disabled (Figma). */
@Composable
fun ContributeContinueButton(
    title: String,
    enabled: Boolean,
    loading: Boolean = false,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val active = enabled && !loading
    val interaction = remember { MutableInteractionSource() }
    val fill by animateColorAsState(if (active || loading) ContributeColors.Blue else ContributeColors.DisabledFill, tween(200), label = "cta")
    Box(
        modifier
            .fillMaxWidth()
            .padding(start = 20.dp, end = 20.dp, top = 12.dp)
            .height(54.dp)
            .pressScale(interaction)
            .clip(CircleShape)
            .background(fill)
            .clickable(interactionSource = interaction, indication = null, enabled = active, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        if (loading) {
            CircularProgressIndicator(Modifier.size(22.dp), color = Color.White, strokeWidth = 2.dp)
        } else {
            Text(
                title,
                fontSize = 17.sp,
                fontWeight = FontWeight.SemiBold,
                color = if (active) Color.White else ContributeColors.DisabledText,
            )
        }
    }
}

/** Eyebrow (13sp grey), question (22sp semibold) and an optional hint (Figma question frames). */
@Composable
fun ContributeQuestionBlock(
    eyebrow: String?,
    title: String,
    subtitle: String? = null,
    onInfo: (() -> Unit)? = null,
) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        eyebrow?.takeIf { it.isNotEmpty() }?.let { Text(it, fontSize = 13.sp, color = Color(0xFF5C5C5C)) }
        Row(verticalAlignment = Alignment.Top) {
            Text(title, Modifier.weight(1f), fontSize = 22.sp, lineHeight = 27.sp, fontWeight = FontWeight.SemiBold, color = ContributeColors.Text)
            if (onInfo != null) {
                Box(
                    Modifier.offset(y = (-8).dp).size(36.dp).clickable(onClick = onInfo).semantics { contentDescription = "Accessible entrance info" },
                    contentAlignment = Alignment.Center,
                ) {
                    Box(Modifier.size(18.dp).background(Color(0xFFA8ABB0), CircleShape), contentAlignment = Alignment.Center) {
                        Text("i", fontSize = 10.sp, fontWeight = FontWeight.Black, color = Color.White, lineHeight = 10.sp)
                    }
                }
            }
        }
        subtitle?.takeIf { it.isNotEmpty() }?.let {
            Text(it, fontSize = if (it == "(Optional)") 14.sp else 13.sp, color = if (it == "(Optional)") ContributeColors.OptionalText else ContributeColors.SecondaryText)
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

/** Icon chip: grey; picked turns white with a blue outline and blue label (Figma tag questions). */
@Composable
fun ContributeTagChip(label: String, selected: Boolean, onClick: () -> Unit) {
    val iconId = tagChipDrawable(label)
    val interaction = remember { MutableInteractionSource() }
    val border by animateColorAsState(ContributeColors.Blue.copy(alpha = if (selected) 1f else 0f), tween(150), label = "chip")
    Row(
        Modifier
            .height(38.dp)
            .pressScale(interaction)
            .clip(CircleShape)
            .background(if (selected) Color.White else ContributeColors.Fill)
            .border(1.5.dp, border, CircleShape)
            .clickable(interactionSource = interaction, indication = null, onClick = onClick)
            .semantics { this.selected = selected }
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        if (iconId != null) Image(painterResource(iconId), null, Modifier.size(13.dp))
        Text(
            label.lowercase().split(" ").joinToString(" ") { word -> word.replaceFirstChar { it.titlecase() } },
            fontSize = 15.sp,
            fontWeight = FontWeight.Medium,
            color = if (selected) ContributeColors.Blue else Color(0xFF3E4042),
        )
    }
}

/** One answer: a 46dp grey pill; selected turns white with a blue outline and blue text (Figma). */
@Composable
fun ContributeSingleChoiceRow(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
    leadingIcon: androidx.compose.ui.graphics.vector.ImageVector? = null,
    showsRadio: Boolean = false,
) {
    val interaction = remember { MutableInteractionSource() }
    val border by animateColorAsState(ContributeColors.Blue.copy(alpha = if (selected) 1f else 0f), tween(150), label = "row")
    val content = if (selected) ContributeColors.Blue else Color(0xFF3E4042)
    Row(
        Modifier
            .fillMaxWidth()
            // Location rows are a little taller than answer rows in the design.
            .height(if (showsRadio) 52.dp else 46.dp)
            .pressScale(interaction)
            .clip(CircleShape)
            .background(if (selected) Color.White else ContributeColors.Fill)
            .border(1.5.dp, border, CircleShape)
            .clickable(interactionSource = interaction, indication = null, onClick = onClick)
            .semantics { this.selected = selected }
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        leadingIcon?.let { Icon(it, null, Modifier.size(18.dp), tint = content) }
        Text(label, Modifier.weight(1f), fontSize = if (showsRadio) 16.sp else 15.sp, fontWeight = FontWeight.Medium, color = content)
        if (showsRadio && selected) {
            Icon(Icons.Default.CheckCircle, null, Modifier.size(18.dp), tint = ContributeColors.Blue)
        }
    }
}

/** "Review another …?" answers: light pills with blue text; the tapped one fills blue. */
@Composable
fun ContributeChoiceButton(title: String, selected: Boolean, onClick: () -> Unit) {
    val interaction = remember { MutableInteractionSource() }
    val fill by animateColorAsState(if (selected) ContributeColors.Blue else ContributeColors.Fill, tween(200), label = "choice")
    Box(
        Modifier
            .fillMaxWidth()
            .height(54.dp)
            .pressScale(interaction)
            .clip(CircleShape)
            .background(fill)
            .clickable(interactionSource = interaction, indication = null, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(title, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = if (selected) Color.White else ContributeColors.Blue)
    }
}

@Composable
fun ContributeEntranceLocationRow(label: String, selected: Boolean, onClick: () -> Unit) =
    ContributeSingleChoiceRow(label, selected, onClick, leadingIcon = Icons.Default.DoorFront, showsRadio = true)





/** "Contribution Submitted" (Figma): illustration, "Review Submitted!", "Back to Home", on white. */
@Composable
fun ContributeSubmittedScreen(onDone: () -> Unit, modifier: Modifier = Modifier) {
    val animationsOn = remember { android.animation.ValueAnimator.areAnimatorsEnabled() }
    var appeared by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { appeared = true }
    val enter by animateFloatAsState(if (appeared) 1f else 0f, tween(350, easing = Rollspot.EaseOut), label = "enter")
    val float = if (animationsOn) {
        rememberInfiniteTransition(label = "float").animateFloat(
            initialValue = 4f, targetValue = -6f,
            animationSpec = infiniteRepeatable(tween(2200, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "y",
        ).value
    } else 0f
    Column(
        modifier.fillMaxSize().background(Color.White),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        // Design: the block sits a little above centre (3 : 2 space above vs below).
        Spacer(Modifier.weight(3f))
        Image(
            painter = painterResource(R.drawable.contribute_thank_you),
            contentDescription = null,
            modifier = Modifier
                .fillMaxWidth(0.97f)
                .aspectRatio(680f / 630f)
                .graphicsLayer {
                    translationY = float.dp.toPx()
                    alpha = enter
                    scaleX = 0.94f + 0.06f * enter
                    scaleY = 0.94f + 0.06f * enter
                },
            contentScale = ContentScale.Fit,
        )
        // The illustration's glow has a soft margin; the design's title tucks into it.
        Text("Review Submitted!", Modifier.offset(y = (-10).dp), fontSize = 28.sp, fontWeight = FontWeight.Bold, color = ContributeColors.Text)
        Text("Thank you for helping out!", Modifier.offset(y = (-2).dp), fontSize = 16.sp, color = ContributeColors.SecondaryText, textAlign = TextAlign.Center)
        Spacer(Modifier.weight(2f))
        val interaction = remember { MutableInteractionSource() }
        Box(
            Modifier
                .padding(horizontal = 22.dp)
                .fillMaxWidth()
                .height(50.dp)
                .pressScale(interaction)
                .clip(CircleShape)
                .background(ContributeColors.Blue)
                .clickable(interactionSource = interaction, indication = null, onClick = onDone),
            contentAlignment = Alignment.Center,
        ) { Text("Back to Home", fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = Color.White) }
        Spacer(Modifier.height(8.dp))
    }
}

@Composable
fun ContributeNoticeRow(label: String, selected: Boolean, onClick: () -> Unit) =
    ContributeSingleChoiceRow(label, selected, onClick)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PathwayInfoSheet(onDismiss: () -> Unit) {
    val pages = PathwayInfoCatalog.pages
    val pagerState = rememberPagerState { pages.size }
    val scope = rememberCoroutineScope()
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        // Opens full height, like iOS (.large) and the design.
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = Color(0xFFE8E8E8),
        shape = RoundedCornerShape(topStart = 34.dp, topEnd = 34.dp),
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp)
                .padding(bottom = 32.dp)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            HorizontalPager(
                state = pagerState,
                pageSpacing = 12.dp,
                modifier = Modifier.fillMaxWidth().height(262.dp),
            ) { index ->
                PathwayCarouselVideo(
                    rawRes = pathwayVideoRes(pages[index].videoKey),
                    active = pagerState.currentPage == index,
                )
            }
            // Tabs: white chips, the current one blue (Figma pathway info sheet).
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                pages.forEachIndexed { index, page ->
                    val selected = pagerState.currentPage == index
                    val fill by animateColorAsState(if (selected) ContributeColors.Blue else Color.White, tween(200), label = "tab")
                    Text(
                        page.chip,
                        modifier = Modifier
                            .clip(CircleShape)
                            .background(fill)
                            .clickable { scope.launch { pagerState.animateScrollToPage(index) } }
                            .semantics { this.selected = selected }
                            .padding(horizontal = 11.dp, vertical = 8.dp),
                        color = if (selected) Color.White else Color(0xFF3F3F3F),
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 11.sp,
                        letterSpacing = 0.3.sp,
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
        containerColor = Color(0xFFE8E8E8),
        shape = RoundedCornerShape(topStart = 34.dp, topEnd = 34.dp),
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp)
                .padding(bottom = 32.dp)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Box(Modifier.fillMaxWidth().height(262.dp).padding(bottom = 6.dp)) {
                PathwayCarouselVideo(rawRes = R.raw.parking_accessible_parking, active = true)
            }
            Text(ParkingInfo.title, fontSize = 20.sp, fontWeight = FontWeight.SemiBold, color = ContributeColors.Text)
            ParkingInfo.sections.forEach { section -> RampInfoBlock(section.title, section.body) }
        }
    }
}

@Composable
private fun PathwayInfoCopy(page: PathwayInfoPage) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(page.title, fontSize = 20.sp, fontWeight = FontWeight.SemiBold, color = ContributeColors.Text)
        Text(
            buildAnnotatedString {
                page.bodyRuns.forEach { run ->
                    if (run.bold) withStyle(SpanStyle(fontWeight = FontWeight.SemiBold, color = Color(0xFF4A4A4A))) { append(run.text) }
                    else append(run.text)
                }
            },
            fontSize = 13.sp, lineHeight = 18.sp, color = Color(0xFF666666),
        )
        Row(
            Modifier.padding(top = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(5.dp),
        ) {
            Icon(Icons.Outlined.WarningAmber, contentDescription = null, tint = Color(0xFFD9534F), modifier = Modifier.size(13.dp))
            Text("What to avoid:", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Color(0xFF5E5E5E))
        }
        page.avoid.forEach { point ->
            Row(Modifier.padding(start = 4.dp)) {
                Text("•", fontSize = 12.sp, color = Color(0xFF5D5D5D), modifier = Modifier.width(12.dp))
                Text(
                    buildAnnotatedString {
                        withStyle(SpanStyle(fontWeight = FontWeight.SemiBold, color = Color(0xFF4A4A4A))) { append(point.lead) }
                        append(point.rest)
                    },
                    fontSize = 12.sp, lineHeight = 17.sp, color = Color(0xFF5D5D5D),
                )
            }
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
            .clip(RoundedCornerShape(16.dp))
            .background(Color.White),
    ) {
        AndroidView(factory = { videoView }, modifier = Modifier.fillMaxSize())
        CardPauseButton(playing, Modifier.align(Alignment.TopEnd)) {
            if (playing) {
                shouldPlay.value = false
                videoView.pause()
            } else {
                shouldPlay.value = true
                videoView.start()
            }
            playing = !playing
        }
    }
}

@RawRes
private fun pathwayVideoRes(videoKey: String): Int = when (videoKey) {
    "width" -> R.raw.pathways_width
    "obstructions" -> R.raw.pathways_obstructions
    else -> R.raw.pathways_surfaces
}
