package com.rollspot.app.ui.screens.home

import android.Manifest
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import com.google.accompanist.permissions.ExperimentalPermissionsApi
import com.google.accompanist.permissions.isGranted
import com.google.accompanist.permissions.rememberPermissionState
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.*
import com.rollspot.app.data.models.Place
import com.rollspot.app.ui.components.GlassButton
import com.rollspot.app.ui.components.SearchBottomSheet

/**
 * Home screen with map and search.
 * Mirrors iOS HomeMapView
 */
@OptIn(ExperimentalPermissionsApi::class, ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    navController: NavController,
    viewModel: HomeViewModel = viewModel()
) {
    val context = LocalContext.current
    val locationPermission = rememberPermissionState(Manifest.permission.ACCESS_FINE_LOCATION)
    
    val cameraPositionState = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(
            LatLng(-8.7200, 115.2000), // Bali region
            12f
        )
    }
    
    val uiState by viewModel.uiState.collectAsState()
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = false)
    var showSearchSheet by remember { mutableStateOf(true) }
    
    // Request location permission on first launch
    LaunchedEffect(locationPermission) {
        if (!locationPermission.status.isGranted) {
            locationPermission.launchPermissionRequest()
        }
    }
    
    // Load nearby places when camera moves
    LaunchedEffect(cameraPositionState.isMoving) {
        if (!cameraPositionState.isMoving) {
            val center = cameraPositionState.position.target
            viewModel.loadNearbyPlaces(center)
        }
    }
    
    Box(modifier = Modifier.fillMaxSize()) {
        // Map layer
        GoogleMap(
            modifier = Modifier.fillMaxSize(),
            cameraPositionState = cameraPositionState,
            properties = MapProperties(
                isMyLocationEnabled = locationPermission.status.isGranted
            ),
            uiSettings = MapUiSettings(
                myLocationButtonEnabled = false,
                zoomControlsEnabled = false,
                compassEnabled = false
            )
        ) {
            // Place markers
            uiState.nearbyPlaces.forEach { place ->
                Marker(
                    state = MarkerState(position = place.coordinate),
                    title = place.name,
                    snippet = place.category,
                    onClick = {
                        navController.navigate("place/${place.id}")
                        true
                    }
                )
            }
        }
        
        // Top bar with filter and profile buttons
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
                .statusBarsPadding(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            GlassButton(
                onClick = { /* TODO: Show filter */ },
                icon = Icons.Default.FilterList
            )
            
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                GlassButton(
                    onClick = { navController.navigate("saved") },
                    icon = Icons.Default.Bookmark
                )
                GlassButton(
                    onClick = { /* TODO: Show profile */ },
                    icon = Icons.Default.Person
                )
            }
        }
        
        // Location button
        Box(
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(16.dp)
                .padding(bottom = 200.dp)
        ) {
            GlassButton(
                onClick = {
                    viewModel.centerOnUserLocation(cameraPositionState)
                },
                icon = if (locationPermission.status.isGranted) {
                    Icons.Default.MyLocation
                } else {
                    Icons.Default.LocationOff
                }
            )
        }
        
        // Search bottom sheet
        if (showSearchSheet) {
            SearchBottomSheet(
                sheetState = sheetState,
                places = uiState.nearbyPlaces,
                searchQuery = uiState.searchQuery,
                onSearchQueryChange = { viewModel.updateSearchQuery(it) },
                onPlaceClick = { place ->
                    navController.navigate("place/${place.id}")
                },
                onExploreClick = { /* Current tab */ },
                onSavedClick = { navController.navigate("saved") },
                onContributeClick = { navController.navigate("contribute") }
            )
        }
    }
}
