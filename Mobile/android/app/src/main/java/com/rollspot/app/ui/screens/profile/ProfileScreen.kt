package com.rollspot.app.ui.screens.profile

import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.rollspot.shared.profile.MyReviewItem
import coil3.compose.AsyncImage
import com.rollspot.app.ui.rollspotSdk
import com.rollspot.app.ui.screens.contribute.jpegForUpload
import kotlinx.coroutines.launch

/**
 * Profile: avatar, name and role, with My Reviews and My Photos tabs (same as iOS
 * ProfileView). State comes from the shared ProfileModel and MyReviewsModel.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileScreen(onBack: () -> Unit, onOpenSettings: () -> Unit, onOpenPlace: (String) -> Unit) {
    val sdk = rollspotSdk()
    val profile by sdk.profile.state.collectAsStateWithLifecycle()
    val mine by sdk.myReviews.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var tab by rememberSaveable { mutableIntStateOf(0) }
    var toDelete by remember { mutableStateOf<MyReviewItem?>(null) }

    LaunchedEffect(Unit) {
        launch { runCatching { sdk.profile.load() } }
        launch { runCatching { sdk.myReviews.load() } }
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

    Scaffold(
        topBar = {
            TopAppBar(
                title = {},
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back") } },
                actions = { IconButton(onClick = onOpenSettings) { Icon(Icons.Default.Settings, "Settings") } },
            )
        },
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding)) {
            Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                Box(
                    Modifier.size(88.dp).clip(CircleShape).background(Color(0xFFE7E7E7))
                        .clickable(enabled = !profile.isUploadingAvatar) {
                            avatarPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    val avatar = profile.avatarUrl ?: mine.avatarUrl
                    if (avatar != null) {
                        AsyncImage(avatar, "Change profile photo", Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
                    } else {
                        Icon(Icons.Default.Person, "Change profile photo", Modifier.size(44.dp), tint = Color.Gray)
                    }
                    if (profile.isUploadingAvatar) CircularProgressIndicator(Modifier.size(32.dp))
                }
                Spacer(Modifier.height(12.dp))
                Text(profile.displayName, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
                profile.roleLabel?.let { Text(it, color = Color.Gray) }
            }
            Spacer(Modifier.height(16.dp))
            TabRow(selectedTabIndex = tab) {
                Tab(selected = tab == 0, onClick = { tab = 0 }, text = { Text("Reviews (${mine.reviews.size})") })
                Tab(selected = tab == 1, onClick = { tab = 1 }, text = { Text("Photos (${mine.photos.size})") })
            }
            when {
                mine.isLoading && !mine.hasLoaded -> Box(Modifier.fillMaxWidth().padding(32.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
                mine.error != null && mine.reviews.isEmpty() -> Message(mine.error!!)
                tab == 0 && mine.reviews.isEmpty() -> Message("You haven't reviewed any places yet.")
                tab == 0 -> LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    items(mine.reviews, key = { it.id }) { review ->
                        ReviewCard(review, onOpen = { onOpenPlace(review.placeId) }, onDelete = { toDelete = review })
                    }
                }
                mine.photos.isEmpty() -> Message("No photos yet")
                else -> LazyVerticalGrid(GridCells.Fixed(3), contentPadding = PaddingValues(2.dp)) {
                    items(mine.photos, key = { it.url }) { photo ->
                        AsyncImage(photo.url, photo.caption.ifEmpty { photo.placeName }, Modifier.padding(2.dp).aspectRatio(1f), contentScale = ContentScale.Crop)
                    }
                }
            }
        }
    }

    toDelete?.let { review ->
        AlertDialog(
            onDismissRequest = { toDelete = null },
            title = { Text("Delete this review?") },
            text = { Text("Your review of ${review.placeName} and its photos will be removed.") },
            confirmButton = {
                TextButton(onClick = {
                    toDelete = null
                    scope.launch {
                        runCatching { sdk.myReviews.delete(review.id) }
                            .onSuccess { Toast.makeText(context, "Review deleted", Toast.LENGTH_SHORT).show() }
                            .onFailure { Toast.makeText(context, it.message, Toast.LENGTH_SHORT).show() }
                    }
                }) { Text("Delete", color = Color(0xFFDB2E2E)) }
            },
            dismissButton = { TextButton(onClick = { toDelete = null }) { Text("Cancel") } },
        )
    }
}

@Composable
private fun ReviewCard(review: MyReviewItem, onOpen: () -> Unit, onDelete: () -> Unit) {
    var menu by remember { mutableStateOf(false) }
    Card(Modifier.fillMaxWidth().clickable(onClick = onOpen), colors = CardDefaults.cardColors(containerColor = Color(0xFFF5F5F5))) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(review.placeName, fontWeight = FontWeight.SemiBold)
                    Text(review.dateLabel, style = MaterialTheme.typography.bodySmall, color = Color.Gray)
                }
                Box {
                    IconButton(onClick = { menu = true }) { Icon(Icons.Default.MoreVert, "Review options") }
                    DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                        DropdownMenuItem(text = { Text("Delete review") }, onClick = { menu = false; onDelete() })
                    }
                }
            }
            Text(review.text, style = MaterialTheme.typography.bodyMedium)
            if (review.providedFeatures.isNotEmpty()) {
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    review.providedFeatures.take(4).forEach {
                        Surface(shape = RoundedCornerShape(8.dp), color = Color(0xFFE3EEFF)) {
                            Text(it, Modifier.padding(horizontal = 8.dp, vertical = 4.dp), style = MaterialTheme.typography.labelSmall)
                        }
                    }
                }
            }
            if (review.photos.isNotEmpty()) {
                LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    items(review.photos, key = { it.url }) { photo ->
                        AsyncImage(photo.url, photo.caption, Modifier.size(64.dp).clip(RoundedCornerShape(8.dp)), contentScale = ContentScale.Crop)
                    }
                }
            }
        }
    }
}

@Composable
internal fun Message(text: String) {
    Box(Modifier.fillMaxWidth().padding(40.dp), contentAlignment = Alignment.Center) {
        Text(text, color = Color.Gray)
    }
}
