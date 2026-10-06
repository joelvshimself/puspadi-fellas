package com.rollspot.app.ui.screens.home

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import app.rollspot.shared.places.PlaceRepository
import com.rollspot.app.data.LocationService
import com.rollspot.app.ui.components.GlassButton
import com.rollspot.app.ui.components.PlaceList
import com.rollspot.app.ui.rollspotSdk

/**
 * Home. The map itself arrives with F2 (#33, OpenStreetMap tiles); until then
 * this shows the same nearby places and search results the map will pin.
 */
@Composable
fun HomeScreen(navController: NavController) {
    val sdk = rollspotSdk()
    val viewModel: HomeViewModel = viewModel { HomeViewModel(sdk) }
    val state by viewModel.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val location = remember { LocationService(context) }

    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
        location.lastKnownLocation()?.let { viewModel.loadNearby(it.latitude, it.longitude) }
    }
    LaunchedEffect(Unit) {
        if (location.hasPermission) {
            location.lastKnownLocation()?.let { viewModel.loadNearby(it.latitude, it.longitude) }
        } else {
            permission.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION))
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .statusBarsPadding()
            .padding(horizontal = 16.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("Rollspot", style = MaterialTheme.typography.headlineSmall)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                GlassButton(onClick = { navController.navigate("saved") }, icon = Icons.Default.Bookmark)
                GlassButton(onClick = { navController.navigate("contribute") }, icon = Icons.Default.Person)
            }
        }
        OutlinedTextField(
            value = state.query,
            onValueChange = viewModel::onQueryChange,
            modifier = Modifier.fillMaxWidth(),
            placeholder = { Text("Find a place") },
            leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
            singleLine = true,
            shape = RoundedCornerShape(12.dp),
        )
        Spacer(Modifier.height(12.dp))
        state.error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
        if (state.isLoading && state.visiblePlaces.isEmpty()) {
            Box(Modifier.fillMaxWidth().padding(32.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
        }
        PlaceList(
            places = state.visiblePlaces,
            fromLat = state.centerLat,
            fromLng = state.centerLng,
            onPlaceClick = { navController.navigate("place/${it.id}") },
            modifier = Modifier.weight(1f),
        )
        Text(
            PlaceRepository.ATTRIBUTION,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(vertical = 8.dp),
        )
    }
}
