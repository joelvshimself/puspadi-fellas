package com.rollspot.app.ui.screens.place

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Elevator
import androidx.compose.material.icons.filled.MeetingRoom
import androidx.compose.material.icons.filled.Wc
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import app.rollspot.shared.place.FacilityKind
import app.rollspot.shared.place.FacilityReview
import app.rollspot.shared.place.PlaceDetail
import coil3.compose.AsyncImage
import com.rollspot.app.ui.theme.RollspotBlue

private val FacilityKind.chipLabel: String
    get() = when (this) {
        FacilityKind.ENTRANCE -> "Entrance"
        FacilityKind.ELEVATOR -> "Elevators"
        FacilityKind.TOILET -> "Toilet"
    }

private val FacilityKind.chipIcon: ImageVector
    get() = when (this) {
        FacilityKind.ENTRANCE -> Icons.Default.MeetingRoom
        FacilityKind.ELEVATOR -> Icons.Default.Elevator
        FacilityKind.TOILET -> Icons.Default.Wc
    }

/** Review tags arrive upper-cased ("AUTOMATIC DOORS"); the checklist shows "Automatic Doors". */
private fun String.tagLabel(): String =
    lowercase().split(' ').joinToString(" ") { word -> word.replaceFirstChar { it.uppercase() } }

// ---- Overview ----

@Composable
internal fun Overview(
    detail: PlaceDetail,
    facility: FacilityKind,
    onFacility: (FacilityKind) -> Unit,
    onOpenReviews: () -> Unit,
    onContribute: () -> Unit,
) {
    Column(Modifier.padding(top = 18.dp), verticalArrangement = Arrangement.spacedBy(24.dp)) {
        FacilityChips(facility, onFacility)
        Column(Modifier.padding(horizontal = 22.dp), verticalArrangement = Arrangement.spacedBy(24.dp)) {
            WhatProvided(detail, facility)
            NotesFromReviews(detail, facility, onOpenReviews)
            if (detail.hasReviews(facility)) {
                Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    Text("Find something different?", fontSize = 20.sp, fontWeight = FontWeight.Bold)
                    SecondaryTextButton(if (detail.reviewCount > 0) "Edit Accessibility Information" else "Be the first reviewer", onContribute)
                }
            }
        }
    }
}

@Composable
private fun FacilityChips(selected: FacilityKind, onSelect: (FacilityKind) -> Unit) {
    Row(
        Modifier.horizontalScroll(rememberScrollState()).padding(horizontal = 22.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        FacilityKind.entries.forEach { kind ->
            val isSelected = kind == selected
            Row(
                Modifier
                    .height(48.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(if (isSelected) Color.White else SectionBackground)
                    .border(1.5.dp, if (isSelected) RollspotBlue else Color.Transparent, RoundedCornerShape(12.dp))
                    .clickable { onSelect(kind) }
                    .padding(horizontal = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(kind.chipIcon, contentDescription = null, tint = if (isSelected) RollspotBlue else Color.DarkGray, modifier = Modifier.size(22.dp))
                Spacer(Modifier.width(6.dp))
                Text(
                    kind.chipLabel.uppercase(), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 0.2.sp,
                    color = if (isSelected) RollspotBlue else Color.Black,
                )
            }
        }
    }
}

@Composable
private fun WhatProvided(detail: PlaceDetail, facility: FacilityKind) {
    val tags = detail.providedTagsFor(facility)
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text("What provided", fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
        Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(SectionBackground).padding(16.dp)) {
            when {
                detail.isUnavailable(facility) -> Text("Not available at this place", fontSize = 14.sp, color = Color.Gray)
                tags.isEmpty() -> Text("No one review this place yet", fontSize = 14.sp, color = Color.Gray)
                else -> Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    tags.chunked(2).forEach { pair ->
                        Row(Modifier.fillMaxWidth()) {
                            pair.forEach { tag ->
                                Row(Modifier.weight(1f), verticalAlignment = Alignment.CenterVertically) {
                                    Icon(Icons.Default.Check, contentDescription = null, tint = Color.Gray, modifier = Modifier.size(14.dp))
                                    Spacer(Modifier.width(10.dp))
                                    Text(tag.tagLabel(), fontSize = 14.sp)
                                }
                            }
                            if (pair.size == 1) Spacer(Modifier.weight(1f))
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun NotesFromReviews(detail: PlaceDetail, facility: FacilityKind, onOpenReviews: () -> Unit) {
    val notes = detail.noteSnippets(facility, 3)
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text("Notes from reviews", fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
        if (notes.isEmpty()) {
            Text(
                if (detail.hasReviews(facility)) "No written notes yet — the details above come from reviewers' answers."
                else "No notes for this facility yet",
                fontSize = 15.sp, color = Color.Gray,
                modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(SectionBackground).padding(16.dp),
            )
        } else {
            Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(SectionBackground)) {
                notes.forEachIndexed { index, note ->
                    if (index > 0) HorizontalDivider(Modifier.padding(start = 16.dp))
                    Row(
                        Modifier.fillMaxWidth().clickable(onClick = onOpenReviews).padding(horizontal = 16.dp, vertical = 14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(note, fontSize = 15.sp, modifier = Modifier.weight(1f))
                        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = Color.Gray)
                    }
                }
            }
        }
    }
}

// ---- Reviews ----

@Composable
internal fun ReviewsList(detail: PlaceDetail) {
    Column(Modifier.padding(horizontal = 22.dp, vertical = 22.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        if (detail.reviews.isEmpty()) {
            Text("No one review this place yet", fontSize = 14.sp, color = Color.Gray)
        }
        detail.reviews.forEach { ReviewCard(it) }
    }
}

@Composable
private fun ReviewCard(review: FacilityReview) {
    var lightbox by remember { mutableStateOf<Int?>(null) }
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(SectionBackground).padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(36.dp).clip(CircleShape).background(Color.White), contentAlignment = Alignment.Center) {
                Text((review.reviewerName ?: "C").take(1).uppercase(), fontWeight = FontWeight.SemiBold, color = RollspotBlue)
            }
            Spacer(Modifier.width(10.dp))
            Column(Modifier.weight(1f)) {
                Text(review.reviewerName ?: "Community", fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
                review.reviewerRole?.let { Text(it, fontSize = 12.sp, color = Color.Gray) }
            }
            Column(horizontalAlignment = Alignment.End) {
                Text(review.kind.chipLabel, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = RollspotBlue)
                Text(review.dateLabel, fontSize = 12.sp, color = Color.Gray)
            }
        }
        if (review.providedTags.isNotEmpty()) {
            Text(review.providedTags.joinToString(" · ") { it.tagLabel() }, fontSize = 13.sp, color = Color.DarkGray)
        }
        if (review.hasBodyText) Text(review.bodyText, fontSize = 15.sp)
        if (review.photoUrls.isNotEmpty()) {
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                review.photoUrls.forEachIndexed { index, url ->
                    AsyncImage(
                        model = url, contentDescription = review.photoCaptions.getOrNull(index),
                        contentScale = ContentScale.Crop,
                        modifier = Modifier.size(88.dp).clip(RoundedCornerShape(8.dp)).clickable { lightbox = index },
                    )
                }
            }
        }
    }
    lightbox?.let { PhotoViewer(review.photoUrls, it) { lightbox = null } }
}

// ---- Photos ----

@Composable
internal fun PhotosGrid(detail: PlaceDetail) {
    // Venue photos first, then the community's; the same image can arrive twice.
    val urls = (detail.photos.map { it.url } + detail.reviewPhotos.map { it.url }).distinct()
    var lightbox by remember { mutableStateOf<Int?>(null) }
    Column(Modifier.padding(horizontal = 22.dp, vertical = 22.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        when {
            urls.isEmpty() && detail.reviewPhotosLoadFailed -> Text("Couldn't load photos right now.", fontSize = 14.sp, color = Color.Gray)
            urls.isEmpty() -> Text("No photos yet", fontSize = 14.sp, color = Color.Gray)
        }
        urls.withIndex().chunked(3).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                row.forEach { (index, url) ->
                    AsyncImage(
                        model = url, contentDescription = null, contentScale = ContentScale.Crop,
                        modifier = Modifier.weight(1f).aspectRatio(1f).clip(RoundedCornerShape(8.dp)).clickable { lightbox = index },
                    )
                }
                repeat(3 - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
    lightbox?.let { PhotoViewer(urls, it) { lightbox = null } }
}

/** Full-screen swipeable viewer. */
@Composable
private fun PhotoViewer(urls: List<String>, initialPage: Int, onDismiss: () -> Unit) {
    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        val pager = rememberPagerState(initialPage = initialPage.coerceIn(0, urls.lastIndex)) { urls.size }
        Box(Modifier.fillMaxSize().background(Color.Black)) {
            HorizontalPager(pager, Modifier.fillMaxSize()) { page ->
                AsyncImage(model = urls[page], contentDescription = null, contentScale = ContentScale.Fit, modifier = Modifier.fillMaxSize())
            }
            IconButton(onClick = onDismiss, Modifier.align(Alignment.TopEnd).padding(16.dp)) {
                Icon(Icons.Default.Close, contentDescription = "Close", tint = Color.White)
            }
            Text(
                "${pager.currentPage + 1} / ${urls.size}", color = Color.White, fontSize = 14.sp,
                modifier = Modifier.align(Alignment.BottomCenter).padding(24.dp),
            )
        }
    }
}
