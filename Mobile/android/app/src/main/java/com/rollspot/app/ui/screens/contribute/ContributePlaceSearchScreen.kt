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
import com.rollspot.app.ui.rollspotSdk
import com.rollspot.app.ui.screens.home.HomeViewModel

/** Pick the place to review: nearby places first, search results once something is typed (shared MapModel). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ContributePlaceSearchScreen(
    onNavigateBack: () -> Unit,
    onPlaceSelected: (String) -> Unit,
) {
    val sdk = rollspotSdk()
    val viewModel: HomeViewModel = viewModel { HomeViewModel(sdk) }
    val state by viewModel.state.collectAsStateWithLifecycle()
    LaunchedEffect(Unit) { viewModel.retry() }
    val places = if (state.isSearchActive) state.results.map { it.place } else state.pins.map { it.place }

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
                onValueChange = viewModel::onQueryChanged,
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text("Find a place") },
                leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                singleLine = true,
                shape = RoundedCornerShape(12.dp),
            )
            Spacer(Modifier.height(8.dp))
            if (state.isLoading || state.isSearching) LinearProgressIndicator(Modifier.fillMaxWidth())
            state.error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                items(places, key = { it.id }) { place ->
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
