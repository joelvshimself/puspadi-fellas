package com.rollspot.app.ui.screens.place

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Accessibility
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Call
import androidx.compose.material.icons.filled.Navigation
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import app.rollspot.shared.place.FacilityKind
import app.rollspot.shared.place.PlaceDetail
import app.rollspot.shared.place.PlaceDetailState
import app.rollspot.shared.places.OverallAccessibility
import app.rollspot.shared.places.PlaceRepository
import coil3.compose.AsyncImage
import kotlinx.coroutines.delay
import com.rollspot.app.ui.rollspotSdk
import com.rollspot.app.ui.theme.RollspotBlue
import com.rollspot.app.ui.theme.badgeBackground
import com.rollspot.app.ui.theme.badgeForeground
import com.rollspot.app.ui.theme.icon
import com.rollspot.app.ui.theme.label

internal val SectionBackground = Color(0xFFF2F2F7)
private const val HERO_HEIGHT_DP = 253

private enum class DetailSection(val title: String) { OVERVIEW("Overview"), REVIEWS("Reviews"), PHOTOS("Photos") }

/**
 * The place page (Figma "Place Details"): hero, grade banner, Overview / Reviews / Photos.
 * Everything shown comes from the shared `PlaceDetailModel`; this file only draws it.
 */
@Composable
fun PlaceDetailScreen(placeId: String, onNavigateBack: () -> Unit, onContribute: () -> Unit) {
    val sdk = rollspotSdk()
    val viewModel: PlaceDetailViewModel = viewModel(key = placeId) { PlaceDetailViewModel(sdk, placeId) }
    val state by viewModel.state.collectAsStateWithLifecycle()

    Box(Modifier.fillMaxSize().background(Color.White)) {
        when (val current = state) {
            PlaceDetailState.Loading -> CircularProgressIndicator(Modifier.align(Alignment.Center))
            is PlaceDetailState.Error -> ErrorState(current.message, onRetry = viewModel::retry, modifier = Modifier.align(Alignment.Center))
            is PlaceDetailState.Loaded -> PlaceContent(current.detail, isEmpty = false, onContribute = onContribute)
            is PlaceDetailState.Empty -> PlaceContent(current.detail, isEmpty = true, onContribute = onContribute)
        }

        BackButton(onNavigateBack, Modifier.align(Alignment.TopStart))

        // First-visit "Share what you know" hint (Figma "Intro to contribute"), shown once per
        // install and never over the empty state, which already asks for a contribution.
        val context = LocalContext.current
        val prefs = remember { context.getSharedPreferences("rollspot", Context.MODE_PRIVATE) }
        var showIntro by remember { mutableStateOf(false) }
        LaunchedEffect(state is PlaceDetailState.Loaded) {
            if (state is PlaceDetailState.Loaded && !prefs.getBoolean(INTRO_SEEN_KEY, false)) {
                delay(600)
                showIntro = true
            }
        }
        val dismissIntro = {
            showIntro = false
            prefs.edit().putBoolean(INTRO_SEEN_KEY, true).apply()
        }
        // Under the pill, so the pill stays bright: that's the spotlight.
        if (showIntro) ContributeIntro(onDismiss = dismissIntro, modifier = Modifier.align(Alignment.BottomCenter))

        // One Contribute CTA in every settled state, the empty one included (Figma "Empty").
        if (state is PlaceDetailState.Loaded || state is PlaceDetailState.Empty) {
            ContributePill(
                onClick = {
                    dismissIntro()
                    onContribute()
                },
                modifier = Modifier.align(Alignment.BottomCenter),
            )
        }
    }
}

private const val INTRO_SEEN_KEY = "hasSeenContributeIntro"

@Composable
private fun ContributeIntro(onDismiss: () -> Unit, modifier: Modifier = Modifier) {
    Box(
        modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.45f))
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null, onClick = onDismiss),
        contentAlignment = Alignment.BottomCenter,
    ) {
        Surface(
            shape = RoundedCornerShape(16.dp),
            color = Color.White,
            modifier = Modifier.navigationBarsPadding().padding(bottom = 96.dp, start = 40.dp, end = 40.dp),
        ) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.size(24.dp).clip(CircleShape).background(RollspotBlue), contentAlignment = Alignment.Center) {
                        Icon(Icons.Default.Accessibility, contentDescription = null, tint = Color.White, modifier = Modifier.size(16.dp))
                    }
                    Spacer(Modifier.width(8.dp))
                    Text("Share what you know", fontWeight = FontWeight.SemiBold, fontSize = 17.sp)
                }
                Text("Help others know what to expect by adding accessibility information.", fontSize = 14.sp, color = Color.Gray)
            }
        }
    }
}

@Composable
private fun PlaceContent(detail: PlaceDetail, isEmpty: Boolean, onContribute: () -> Unit) {
    var section by rememberSaveable { mutableIntStateOf(DetailSection.OVERVIEW.ordinal) }
    var facility by rememberSaveable { mutableStateOf(FacilityKind.ENTRANCE) }
    val heroUrl = detail.photos.firstOrNull()?.url ?: detail.reviewPhotos.firstOrNull()?.url

    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
        Hero(heroUrl)
        // Overlaps the photo by its corner radius so the rounded top corners show against it.
        Column(Modifier.offset(y = (-18).dp)) {
            GradeBanner(detail.overall)
            Column(Modifier.background(Color.White).padding(top = 18.dp)) {
                TitleBlock(detail)
                if (isEmpty) {
                    EmptyState()
                } else {
                    SectionTabs(selected = section, reviewCount = detail.reviewCount) { section = it }
                    when (DetailSection.entries[section]) {
                        DetailSection.OVERVIEW -> Overview(
                            detail, facility,
                            onFacility = { facility = it },
                            onOpenReviews = { section = DetailSection.REVIEWS.ordinal },
                            onContribute = onContribute,
                        )
                        DetailSection.REVIEWS -> ReviewsList(detail)
                        DetailSection.PHOTOS -> PhotosGrid(detail)
                    }
                }
                Text(
                    PlaceRepository.ATTRIBUTION,
                    style = MaterialTheme.typography.labelSmall,
                    color = Color.Gray,
                    modifier = Modifier.padding(horizontal = 22.dp, vertical = 16.dp),
                )
                // Clears the floating CONTRIBUTE pill.
                Spacer(Modifier.height(96.dp))
            }
        }
    }
}

@Composable
private fun Hero(url: String?) {
    Box(Modifier.fillMaxWidth().height(HERO_HEIGHT_DP.dp).background(SectionBackground)) {
        if (url != null) {
            AsyncImage(model = url, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
        } else {
            Column(Modifier.align(Alignment.Center), horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(Icons.Default.PhotoLibrary, contentDescription = null, tint = Color.Gray, modifier = Modifier.size(48.dp))
                Text("No Photos Available", color = Color.Gray, fontSize = 15.sp, modifier = Modifier.padding(top = 8.dp))
            }
        }
    }
}

@Composable
private fun BackButton(onClick: () -> Unit, modifier: Modifier = Modifier) {
    Surface(
        shape = CircleShape,
        color = Color.White,
        shadowElevation = 4.dp,
        modifier = modifier.statusBarsPadding().padding(16.dp).size(44.dp),
    ) {
        IconButton(onClick = onClick) {
            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
        }
    }
}

@Composable
private fun GradeBanner(grade: OverallAccessibility) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(topStart = 18.dp, topEnd = 18.dp))
            .background(grade.badgeBackground)
            .padding(horizontal = 20.dp, vertical = 18.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(grade.icon, contentDescription = null, tint = grade.badgeForeground, modifier = Modifier.size(20.dp))
        Spacer(Modifier.width(10.dp))
        Text(grade.label.uppercase(), color = grade.badgeForeground, fontWeight = FontWeight.Bold, fontSize = 15.sp, letterSpacing = 0.6.sp, modifier = Modifier.weight(1f))
        // The banner's faint decorative mark on the right (Figma).
        Icon(grade.icon, contentDescription = null, tint = grade.badgeForeground.copy(alpha = 0.14f), modifier = Modifier.size(44.dp))
    }
}

@Composable
private fun TitleBlock(detail: PlaceDetail) {
    val context = LocalContext.current
    val place = detail.place
    Column(Modifier.padding(horizontal = 22.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(place.name, fontSize = 26.sp, fontWeight = FontWeight.Bold)
            place.openingHours?.let { Text(it, fontSize = 14.sp, color = Color.Gray) }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            ActionPill(Icons.Default.Navigation, "OPEN IN MAPS") {
                val geo = Uri.parse("geo:${place.lat},${place.lng}?q=${place.lat},${place.lng}(${Uri.encode(place.name)})")
                context.startActivity(Intent(Intent.ACTION_VIEW, geo))
            }
            place.phone?.let { phone ->
                ActionPill(Icons.Default.Call, "CALL") { context.startActivity(Intent(Intent.ACTION_DIAL, Uri.parse("tel:$phone"))) }
            }
        }
    }
}

@Composable
private fun ActionPill(icon: ImageVector, title: String, onClick: () -> Unit) {
    Row(
        Modifier.clip(CircleShape).background(SectionBackground).clickable(onClick = onClick).padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, contentDescription = null, modifier = Modifier.size(16.dp))
        Spacer(Modifier.width(6.dp))
        Text(title, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 0.2.sp)
    }
}

@Composable
private fun SectionTabs(selected: Int, reviewCount: Int, onSelect: (Int) -> Unit) {
    TabRow(
        selectedTabIndex = selected,
        containerColor = Color.White,
        contentColor = RollspotBlue,
        modifier = Modifier.padding(top = 18.dp),
    ) {
        DetailSection.entries.forEachIndexed { index, tab ->
            val title = if (tab == DetailSection.REVIEWS) "${tab.title} ($reviewCount)" else tab.title
            Tab(
                selected = selected == index,
                onClick = { onSelect(index) },
                text = { Text(title.uppercase(), fontSize = 13.sp, fontWeight = FontWeight.SemiBold) },
                selectedContentColor = RollspotBlue,
                unselectedContentColor = Color.Gray,
            )
        }
    }
}

@Composable
private fun EmptyState() {
    Column(
        Modifier.fillMaxWidth().padding(horizontal = 22.dp, vertical = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        HorizontalDivider()
        Spacer(Modifier.height(8.dp))
        // TODO(design): swap for the exported "thinking person" illustration, like iOS.
        Box(Modifier.size(138.dp).clip(CircleShape).background(SectionBackground), contentAlignment = Alignment.Center) {
            Icon(Icons.Default.Add, contentDescription = null, tint = RollspotBlue, modifier = Modifier.size(56.dp))
        }
        Text(
            buildAnnotatedString {
                append("Be the ")
                withStyle(SpanStyle(color = RollspotBlue)) { append("first to contribute") }
                append(" and help others know about the place!!")
            },
            fontSize = 16.sp,
            fontWeight = FontWeight.Medium,
            color = Color.Gray,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
private fun ErrorState(message: String, onRetry: () -> Unit, modifier: Modifier = Modifier) {
    Column(modifier.padding(32.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text("Couldn't load this place.", fontWeight = FontWeight.SemiBold)
        Text(message, color = Color.Gray, fontSize = 14.sp)
        Button(onClick = onRetry) { Text("Try again") }
    }
}

@Composable
private fun ContributePill(onClick: () -> Unit, modifier: Modifier = Modifier) {
    Surface(
        onClick = onClick,
        shape = CircleShape,
        color = Color.White,
        shadowElevation = 8.dp,
        modifier = modifier.navigationBarsPadding().padding(bottom = 20.dp),
    ) {
        Row(Modifier.padding(horizontal = 20.dp, vertical = 14.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(28.dp).clip(CircleShape).background(Color.Black), contentAlignment = Alignment.Center) {
                Icon(Icons.Default.Add, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
            }
            Spacer(Modifier.width(10.dp))
            Text("CONTRIBUTE", fontWeight = FontWeight.SemiBold, fontSize = 15.sp, letterSpacing = 0.5.sp)
        }
    }
}

@Composable
internal fun SecondaryTextButton(text: String, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth().height(48.dp),
        shape = CircleShape,
        colors = ButtonDefaults.buttonColors(containerColor = SectionBackground, contentColor = RollspotBlue),
    ) { Text(text, fontWeight = FontWeight.SemiBold, fontSize = 17.sp) }
}
