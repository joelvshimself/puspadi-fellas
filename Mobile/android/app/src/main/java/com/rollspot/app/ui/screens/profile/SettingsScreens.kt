package com.rollspot.app.ui.screens.profile

import android.widget.Toast
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.rollspot.shared.auth.AuthRules
import app.rollspot.shared.auth.AuthSession
import app.rollspot.shared.auth.MobilityRole
import app.rollspot.shared.places.PlaceRepository
import com.rollspot.app.BuildConfig
import com.rollspot.app.ui.rollspotSdk
import kotlinx.coroutines.launch


@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun Screen(title: String, onBack: () -> Unit, content: @Composable ColumnScope.() -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(title) },
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back") } },
            )
        },
    ) { padding -> Column(Modifier.fillMaxSize().padding(padding), content = content) }
}

/** Saved places, A–Z (shared SavedPlacesModel). */
@Composable
fun SavedPlacesScreen(onBack: () -> Unit, onOpenPlace: (String) -> Unit) {
    val saved = rollspotSdk().saved
    val state by saved.state.collectAsStateWithLifecycle()
    LaunchedEffect(Unit) { runCatching { saved.load() } }
    Screen("Saved", onBack) {
        when {
            state.isLoading && state.places.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
            state.places.isEmpty() -> Column(Modifier.fillMaxSize().padding(32.dp), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
                Text("No Saved Places", style = MaterialTheme.typography.titleMedium)
                Text("Bookmark places to easily view them here.", color = Color.Gray)
            }
            else -> LazyColumn {
                items(state.places, key = { it.id }) { place ->
                    ListItem(
                        headlineContent = { Text(place.name, fontWeight = FontWeight.SemiBold) },
                        supportingContent = { Text(place.address ?: place.category.orEmpty()) },
                        modifier = Modifier.clickable { onOpenPlace(place.id) },
                    )
                }
            }
        }
    }
}

@Composable
fun AboutScreen(onBack: () -> Unit) {
    Screen("About App", onBack) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("Rollspot", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
            Text("Version ${BuildConfig.VERSION_NAME}", color = Color.Gray)
            Text("Find out how accessible places are for wheelchair users, and help others by sharing what you see.")
            Text("Place data ${PlaceRepository.ATTRIBUTION}", style = MaterialTheme.typography.bodySmall, color = Color.Gray)
        }
    }
}
