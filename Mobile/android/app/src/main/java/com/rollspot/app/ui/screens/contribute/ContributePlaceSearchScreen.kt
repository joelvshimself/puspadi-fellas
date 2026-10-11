package com.rollspot.app.ui.screens.contribute

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import app.rollspot.shared.api.Place
import app.rollspot.shared.places.PlaceRepository
import com.rollspot.app.BuildConfig
import com.rollspot.app.data.MockPlaces
import com.rollspot.app.ui.rollspotSdk
import com.rollspot.app.ui.screens.home.HomeViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ContributePlaceSearchScreen(
    onNavigateBack: () -> Unit,
    onPlaceSelected: (String) -> Unit,
) {
    if (BuildConfig.DEBUG) {
        MockPlaceSearchContent(onNavigateBack, onPlaceSelected)
    } else {
        ApiPlaceSearchContent(onNavigateBack, onPlaceSelected)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MockPlaceSearchContent(
    onNavigateBack: () -> Unit,
    onPlaceSelected: (String) -> Unit,
) {
    var query by remember { mutableStateOf("") }
    val places = remember(query) { MockPlaces.filter(query) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Choose a place (mock)") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding).padding(horizontal = 16.dp)) {
            Text(
                "Debug list — no network. Tap a place to open the review form.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(
                value = query,
                onValueChange = { query = it },
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text("Filter mock places") },
                leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                singleLine = true,
                shape = RoundedCornerShape(12.dp),
            )
            Spacer(Modifier.height(8.dp))
            LazyColumn(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                items(places, key = { it.id }) { place ->
                    PlaceRow(place, onClick = { onPlaceSelected(place.id) })
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ApiPlaceSearchContent(
    onNavigateBack: () -> Unit,
    onPlaceSelected: (String) -> Unit,
) {
    val sdk = rollspotSdk()
    val viewModel: HomeViewModel = viewModel { HomeViewModel(sdk) }
    val state by viewModel.state.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Choose a place") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding).padding(horizontal = 16.dp)) {
            OutlinedTextField(
                value = state.query,
                onValueChange = viewModel::onQueryChange,
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text("Find a place") },
                leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                singleLine = true,
                shape = RoundedCornerShape(12.dp),
            )
            Spacer(Modifier.height(8.dp))
            LazyColumn(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                items(state.visiblePlaces, key = { it.id }) { place ->
                    PlaceRow(place, onClick = { onPlaceSelected(place.id) })
                }
            }
            Text(
                PlaceRepository.ATTRIBUTION,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(vertical = 8.dp),
            )
        }
    }
}

@Composable
private fun PlaceRow(place: Place, onClick: () -> Unit) {
    ListItem(
        headlineContent = { Text(place.name) },
        supportingContent = { place.address?.let { Text(it) } },
        modifier = Modifier.clickable(onClick = onClick),
    )
}
