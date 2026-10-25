package com.rollspot.app.ui.screens.profile

import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.Image
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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.EditNote
import androidx.compose.material.icons.outlined.PhotoLibrary
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.rollspot.shared.drafts.WaitingContribution
import app.rollspot.shared.profile.MyPhoto
import app.rollspot.shared.profile.MyReviewItem
import app.rollspot.shared.profile.ReviewNotes
import coil3.compose.AsyncImage
import com.rollspot.app.R
import com.rollspot.app.ui.components.ContinueSurveyBanner
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

enum class ProfileTab(val title: String) { Reviews("REVIEWS"), Photos("PHOTOS"), Settings("SETTINGS") }

/**
 * Profile (iOS ProfileView): avatar, name and role over a blue fade, then Reviews / Photos /
 * Settings tabs. State comes from the shared ProfileModel and MyReviewsModel.
 */
@Composable
fun ProfileScreen(
    onBack: () -> Unit,
    onOpenPlace: (String) -> Unit,
    onOpenMyAccount: () -> Unit,
    onOpenAbout: () -> Unit,
    onSignedOut: () -> Unit,
    onEditReview: (String) -> Unit = {},
    onResumeContribution: (String) -> Unit = {},
    onOpenNotifications: () -> Unit = {},
    initialTab: ProfileTab = ProfileTab.Reviews,
    review: String? = null,
    reviewUpdated: Boolean = false,
    onUpdatedShown: () -> Unit = {},
) {
    val sdk = rollspotSdk()
    val profile by sdk.profile.state.collectAsStateWithLifecycle()
    val mine by sdk.myReviews.state.collectAsStateWithLifecycle()
    val waiting by sdk.drafts.waiting.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val haze = remember { HazeState() }
    var tab by rememberSaveable { mutableStateOf(initialTab) }
    var toDelete by remember { mutableStateOf<MyReviewItem?>(null) }
    var deleting by remember { mutableStateOf(false) }
    var deleteError by remember { mutableStateOf<String?>(null) }
    var removedToast by remember { mutableStateOf(false) }
    var updatedToast by remember { mutableStateOf(false) }
    LaunchedEffect(reviewUpdated) {
        if (reviewUpdated) {
            updatedToast = true
            onUpdatedShown()
        }
    }
    var languageSheet by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        launch { runCatching { sdk.profile.load() } }
        launch {
            runCatching { sdk.myReviews.load() }
            if (review == "profileDeleteReview") toDelete = sdk.myReviews.state.value.reviews.firstOrNull()
        }
        if (review == "profileLanguage") languageSheet = true
    }
    val avatarPicker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        uri ?: return@rememberLauncherForActivityResult
        scope.launch {
            val jpeg = jpegForUpload(context, uri)
            val result = if (jpeg == null) Result.failure(Exception("That photo couldn't be read. Try another one."))
            else runCatching { sdk.profile.uploadAvatar(jpeg) }
            result.exceptionOrNull()?.let { Toast.makeText(context, it.message, Toast.LENGTH_SHORT).show() }
        }
    }
    val roleLabel = profile.mobilityRole?.label ?: mine.userRole

    CompositionLocalProvider(LocalHazeState provides haze) {
        Box(Modifier.fillMaxSize().background(Rollspot.SectionBackground)) {
            Column(Modifier.fillMaxSize().hazeSource(haze)) {
                ProfileHeader(
                    name = profile.displayName,
                    role = roleLabel,
                    avatarUrl = profile.avatarUrl ?: mine.avatarUrl,
                    uploading = profile.isUploadingAvatar,
                    tab = tab,
                    onBack = onBack,
                    onAvatar = { avatarPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) },
                    onTab = { tab = it },
                )
                Box(Modifier.weight(1f).fillMaxWidth()) {
                    when (tab) {
                        ProfileTab.Reviews -> ReviewsTab(
                            waiting = waiting,
                            onResume = onResumeContribution,
                            reviews = mine.reviews,
                            loading = mine.isLoading && !mine.hasLoaded,
                            userName = mine.userName.takeIf { it != "You" } ?: profile.displayName,
                            userRole = roleLabel,
                            avatarUrl = profile.avatarUrl ?: mine.avatarUrl,
                            // Structured reviews open Edit Response; older ones open the place to review again.
                            onUpdate = { if (it.editable) onEditReview(it.id) else onOpenPlace(it.placeId) },
                            onDelete = { deleteError = null; toDelete = it },
                        )
                        ProfileTab.Photos -> PhotosTab(mine.photos, mine.isLoading && !mine.hasLoaded) { photo ->
                            mine.reviews.firstOrNull { it.id == photo.reviewId }?.let { onOpenPlace(it.placeId) }
                        }
                        ProfileTab.Settings -> SettingsTab(
                            onOpenMyAccount = onOpenMyAccount,
                            onOpenLanguage = { languageSheet = true },
                            onOpenNotifications = onOpenNotifications,
                            onOpenAbout = onOpenAbout,
                            onSignOut = { scope.launch { runCatching { sdk.auth.signOut() }; onSignedOut() } },
                        )
                    }
                    SuccessToast(removedToast, "Review successfully removed") { removedToast = false }
                    SuccessToast(updatedToast && !removedToast, "Review successfully updated") { updatedToast = false }
                }
            }

            GlassSheet(visible = toDelete != null, onDismiss = { if (!deleting) toDelete = null }) {
                SheetHeader("Delete Review?", "Your review will permanently removed. This action is irreversible.")
                deleteError?.let { Text(it, Modifier.padding(top = 8.dp), style = Rollspot.Caption, color = Rollspot.ErrorRed) }
                ConfirmButtons(
                    confirmTitle = "Delete",
                    busy = deleting,
                    onCancel = { toDelete = null },
                    onConfirm = {
                        val target = toDelete ?: return@ConfirmButtons
                        deleting = true
                        scope.launch {
                            runCatching { sdk.myReviews.delete(target.id) }
                                .onSuccess { toDelete = null; removedToast = true }
                                .onFailure { deleteError = it.message }
                            deleting = false
                        }
                    },
                )
            }
            LanguageSheet(visible = languageSheet, onDismiss = { languageSheet = false })
        }
    }
}

@Composable
private fun ProfileHeader(
    name: String,
    role: String?,
    avatarUrl: String?,
    uploading: Boolean,
    tab: ProfileTab,
    onBack: () -> Unit,
    onAvatar: () -> Unit,
    onTab: (ProfileTab) -> Unit,
) {
    Column(
        Modifier
            .fillMaxWidth()
            .background(Brush.verticalGradient(listOf(Color(0xFFB3DBFF), Color.White)))
            .statusBarsPadding()
            .padding(bottom = 20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp)) { BackCircleButton(onBack, size = 44.dp) }
        Box(
            Modifier.clickable(interactionSource = remember { MutableInteractionSource() }, indication = null, enabled = !uploading, onClick = onAvatar),
            contentAlignment = Alignment.BottomEnd,
        ) {
            Avatar(avatarUrl, 88, Modifier.border(2.dp, Color.White, CircleShape).shadow(6.dp, CircleShape, ambientColor = Color(0x14000000)))
            if (uploading) {
                Box(Modifier.size(88.dp).clip(CircleShape).background(Color(0x59000000)), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(Modifier.size(24.dp), color = Color.White, strokeWidth = 2.dp)
                }
            } else {
                Box(
                    Modifier.offset(2.dp, 2.dp).size(28.dp).shadow(3.dp, CircleShape).clip(CircleShape).background(Color(0xFFF2F2F7)),
                    contentAlignment = Alignment.Center,
                ) { Icon(Icons.Default.Edit, "Change profile photo", Modifier.size(13.dp), tint = Color(0xFF616161)) }
            }
        }
        Spacer(Modifier.height(12.dp))
        Text(name, fontSize = 22.sp, fontWeight = FontWeight.Bold, color = Color.Black)
        if (role != null) {
            Spacer(Modifier.height(6.dp))
            Text(
                role,
                Modifier.clip(CircleShape).background(Color(0x2E8E8E93)).padding(horizontal = 10.dp, vertical = 4.dp),
                style = Rollspot.Caption.copy(fontWeight = FontWeight.SemiBold),
                color = Color(0xFF8E8E93),
            )
        }
        Spacer(Modifier.height(26.dp))
        SegmentedTabs(tab, onTab)
    }
}

/** Capsule segmented control; the white thumb slides with the iOS spring (0.3s, damping 0.75). */
@Composable
private fun SegmentedTabs(tab: ProfileTab, onTab: (ProfileTab) -> Unit) {
    BoxWithConstraints(
        Modifier.padding(horizontal = 20.dp).fillMaxWidth().clip(CircleShape).background(Color(0x1F8E8E93)).padding(4.dp),
    ) {
        val segment = (maxWidth - 8.dp) / 3
        val thumbX by animateDpAsState((segment + 4.dp) * tab.ordinal, spring(dampingRatio = 0.75f, stiffness = 440f), label = "tab")
        Box(Modifier.offset(x = thumbX).width(segment).height(36.dp).shadow(4.dp, CircleShape, ambientColor = Color(0x14000000)).clip(CircleShape).background(Color.White))
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            ProfileTab.entries.forEach { item ->
                Box(
                    Modifier.weight(1f).height(36.dp).clip(CircleShape)
                        .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { onTab(item) },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(item.title, style = Rollspot.Caption.copy(fontWeight = FontWeight.Bold), color = if (item == tab) Color.Black else Rollspot.Secondary)
                }
            }
        }
    }
}

@Composable
private fun Avatar(url: String?, size: Int, modifier: Modifier = Modifier) {
    val shaped = modifier.size(size.dp).clip(CircleShape)
    if (url != null) {
        AsyncImage(url, null, shaped, contentScale = ContentScale.Crop, placeholder = painterResource(R.drawable.profile_avatar), error = painterResource(R.drawable.profile_avatar))
    } else {
        Image(painterResource(R.drawable.profile_avatar), null, shaped, contentScale = ContentScale.Crop)
    }
}

@Composable
private fun SectionTitle(text: String) {
    Text(text, Modifier.padding(start = 20.dp, end = 20.dp, top = 16.dp), fontSize = 20.sp, fontWeight = FontWeight.Bold, color = Color.Black)
}

@Composable
private fun ReviewsTab(
    waiting: WaitingContribution?,
    onResume: (String) -> Unit,
    reviews: List<MyReviewItem>,
    loading: Boolean,
    userName: String,
    userRole: String?,
    avatarUrl: String?,
    onUpdate: (MyReviewItem) -> Unit,
    onDelete: (MyReviewItem) -> Unit,
) {
    LazyColumn(verticalArrangement = Arrangement.spacedBy(16.dp), contentPadding = PaddingValues(bottom = 40.dp)) {
        item { SectionTitle("All reviews (${reviews.size})") }
        // Design "Ongoing Review": the folded Home banner lives here too.
        waiting?.let { contribution ->
            item(key = "waiting") {
                val shape = RoundedCornerShape(20.dp)
                ContinueSurveyBanner(
                    contribution, onOpen = { onResume(contribution.placeId) },
                    modifier = Modifier.padding(horizontal = 20.dp).fillMaxWidth()
                        .shadow(10.dp, shape, ambientColor = Color(0x0F000000), spotColor = Color(0x0F000000)).clip(shape).background(Color.White),
                )
            }
        }
        when {
            loading -> item { Loading() }
            reviews.isEmpty() -> item { EmptyState(Icons.Outlined.EditNote, "No reviews yet") }
            else -> items(reviews, key = { it.id }) { review ->
                ReviewCard(review, userName, userRole, avatarUrl, Modifier.padding(horizontal = 20.dp), { onUpdate(review) }, { onDelete(review) })
            }
        }
    }
}

@Composable
private fun ReviewCard(
    review: MyReviewItem,
    userName: String,
    userRole: String?,
    avatarUrl: String?,
    modifier: Modifier,
    onUpdate: () -> Unit,
    onDelete: () -> Unit,
) {
    val shape = RoundedCornerShape(20.dp)
    Column(
        modifier.fillMaxWidth().shadow(10.dp, shape, ambientColor = Color(0x0F000000), spotColor = Color(0x0F000000)).clip(shape).background(Color.White).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Avatar(avatarUrl, 40)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(userName, Modifier.weight(1f), fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = Color.Black)
                    Text(review.dateLabel, style = Rollspot.Caption, color = Rollspot.Secondary)
                }
                userRole?.let { Text(it, style = Rollspot.Caption.copy(fontWeight = FontWeight.Medium), color = Rollspot.Secondary) }
            }
        }
        HorizontalDivider(color = Color(0x1F3C3C43))
        Text(notesText(review.text), style = Rollspot.Subheadline, color = Rollspot.Secondary)
        if (review.providedFeatures.isNotEmpty()) {
            Text(
                buildAnnotatedString {
                    withStyle(SpanStyle(fontWeight = FontWeight.SemiBold, color = Rollspot.Secondary)) { append("What Provided: ") }
                    withStyle(SpanStyle(color = Color.Black)) { append(review.providedFeatures.joinToString(", ")) }
                },
                style = Rollspot.Subheadline,
            )
        }
        if (review.photos.isNotEmpty()) {
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(review.photos, key = { it.url }) { photo ->
                    AsyncImage(photo.url, photo.caption, Modifier.size(96.dp).clip(RoundedCornerShape(12.dp)).background(Rollspot.SectionBackground), contentScale = ContentScale.Crop)
                }
            }
        }
        Row(Modifier.padding(top = 4.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            val trash = remember { MutableInteractionSource() }
            Box(
                Modifier.size(44.dp).pressScale(trash).clip(CircleShape).background(Color(0x1FFF3B30))
                    .clickable(interactionSource = trash, indication = null, onClick = onDelete),
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Outlined.Delete, "Delete review", Modifier.size(20.dp), tint = Color(0xCCFF3B30)) }
            val update = remember { MutableInteractionSource() }
            Box(
                Modifier.weight(1f).height(44.dp).pressScale(update).clip(CircleShape).background(Rollspot.FieldFill)
                    .clickable(interactionSource = update, indication = null, onClick = onUpdate),
                contentAlignment = Alignment.Center,
            ) { Text("Update Review", style = Rollspot.Subheadline.copy(fontWeight = FontWeight.SemiBold), color = Rollspot.BrandBlue) }
        }
    }
}

/** `[Elevator] Lift by the food court` → **Elevator** Lift by the food court (shared ReviewNotes). */
private fun notesText(notes: String) = buildAnnotatedString {
    ReviewNotes.lines(notes).forEachIndexed { index, line ->
        if (index > 0) append("\n")
        line.label?.let {
            withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append(it) }
            if (line.body.isNotEmpty()) append(" ")
        }
        append(line.body)
    }
}

@Composable
private fun PhotosTab(photos: List<MyPhoto>, loading: Boolean, onOpen: (MyPhoto) -> Unit) {
    LazyColumn(verticalArrangement = Arrangement.spacedBy(12.dp), contentPadding = PaddingValues(bottom = 40.dp)) {
        item { Box(Modifier.padding(bottom = 4.dp)) { SectionTitle("All Photos (${photos.size})") } }
        when {
            loading -> item { Loading() }
            photos.isEmpty() -> item { EmptyState(Icons.Outlined.PhotoLibrary, "No Photos Yet", "Photos you add to reviews will show up here.") }
            else -> items(photos, key = { it.url }) { photo ->
                Box(
                    Modifier.padding(horizontal = 20.dp).fillMaxWidth().height(220.dp).clip(RoundedCornerShape(16.dp))
                        .background(Color(0xFFE5E5EA)).clickable { onOpen(photo) },
                    contentAlignment = Alignment.BottomStart,
                ) {
                    AsyncImage(photo.url, photo.caption.ifEmpty { photo.placeName }, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
                    if (photo.caption.isNotBlank()) {
                        Text(
                            photo.caption,
                            Modifier.fillMaxWidth()
                                .background(Brush.verticalGradient(listOf(Color.Transparent, Color(0x99000000))))
                                .padding(horizontal = 12.dp, vertical = 10.dp),
                            fontSize = 13.sp, color = Color.White, maxLines = 3,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun Loading() {
    Box(Modifier.fillMaxWidth().padding(40.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
}

@Composable
private fun EmptyState(icon: androidx.compose.ui.graphics.vector.ImageVector, title: String, message: String? = null) {
    Column(Modifier.fillMaxWidth().padding(vertical = 40.dp, horizontal = 24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Icon(icon, null, Modifier.size(40.dp), tint = Rollspot.Secondary)
        Spacer(Modifier.height(12.dp))
        Text(title, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = Rollspot.Secondary)
        message?.let {
            Spacer(Modifier.height(6.dp))
            Text(it, style = Rollspot.Subheadline, color = Rollspot.Secondary, textAlign = TextAlign.Center)
        }
    }
}

/** Green "done" banner at the top of the content (iOS success toast). */
@Composable
internal fun BoxScope.SuccessToast(visible: Boolean, text: String, onClose: () -> Unit) {
    AnimatedVisibility(
        visible,
        Modifier.align(Alignment.TopCenter),
        enter = slideInVertically(tween(250)) { -it } + fadeIn(tween(250)),
        exit = slideOutVertically(tween(200)) { -it } + fadeOut(tween(200)),
    ) {
        val shape = RoundedCornerShape(16.dp)
        Row(
            Modifier.padding(horizontal = 20.dp, vertical = 8.dp).fillMaxWidth().clip(shape)
                .background(Color(0xFFE6F6EA)).border(1.dp, Color(0x4D34C759), shape)
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Default.CheckCircle, null, Modifier.size(18.dp), tint = Color(0xFF34C759))
            Spacer(Modifier.width(10.dp))
            Text(text, Modifier.weight(1f), style = Rollspot.Subheadline.copy(fontWeight = FontWeight.Medium), color = Color.Black)
            Icon(Icons.Default.Close, "Dismiss", Modifier.size(16.dp).clickable(onClick = onClose), tint = Rollspot.Secondary)
        }
    }
}
