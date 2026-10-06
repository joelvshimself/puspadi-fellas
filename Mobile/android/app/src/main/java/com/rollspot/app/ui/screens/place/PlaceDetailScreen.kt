package com.rollspot.app.ui.screens.place

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import app.rollspot.shared.api.FeatureGrade
import app.rollspot.shared.api.Place
import app.rollspot.shared.places.OverallAccessibility
import app.rollspot.shared.places.PlaceRepository
import app.rollspot.shared.places.overallAccessibility
import com.rollspot.app.ui.rollspotSdk
import com.rollspot.app.ui.theme.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PlaceDetailScreen(placeId: String, onNavigateBack: () -> Unit) {
    val sdk = rollspotSdk()
    val viewModel: PlaceDetailViewModel = viewModel(key = placeId) { PlaceDetailViewModel(sdk, placeId) }
    val state by viewModel.state.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(state.place?.name ?: "") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { padding ->
        Box(Modifier.fillMaxSize().padding(padding)) {
            when {
                state.isLoading -> CircularProgressIndicator(Modifier.align(Alignment.Center))
                state.error != null -> Text(state.error!!, Modifier.align(Alignment.Center).padding(24.dp))
                state.place != null -> PlaceDetail(state.place!!)
            }
        }
    }
}

@Composable
private fun PlaceDetail(place: Place) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        GradeCard(place.overallAccessibility)
        place.address?.let {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.LocationOn, contentDescription = null, tint = Color.Gray, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(4.dp))
                Text(it, style = MaterialTheme.typography.bodyMedium, color = Color.Gray)
            }
        }
        place.osmWheelchair?.let {
            Text("OpenStreetMap lists wheelchair access as: ${valueLabel(it).lowercase()}", style = MaterialTheme.typography.bodySmall)
        }
        Text("Facilities", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        if (place.grade.isEmpty()) {
            Text("No reviews yet. Be the first to review this place.")
        } else {
            place.grade.forEach { FeatureRow(it) }
        }
        Text(PlaceRepository.ATTRIBUTION, style = MaterialTheme.typography.labelSmall, color = Color.Gray)
    }
}

@Composable
private fun GradeCard(grade: OverallAccessibility) {
    Card(colors = CardDefaults.cardColors(containerColor = grade.badgeBackground), shape = RoundedCornerShape(16.dp)) {
        Row(Modifier.fillMaxWidth().padding(24.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(grade.icon, contentDescription = null, tint = grade.badgeForeground, modifier = Modifier.size(40.dp))
            Spacer(Modifier.width(16.dp))
            Text(grade.label, style = MaterialTheme.typography.headlineSmall, color = grade.badgeForeground, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun FeatureRow(feature: FeatureGrade) {
    val (icon, tint) = valueIcon(feature.bestValue)
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, contentDescription = null, tint = tint)
        Spacer(Modifier.width(12.dp))
        Column {
            Text(featureLabel(feature.feature), style = MaterialTheme.typography.titleSmall)
            Text(valueLabel(feature.bestValue), style = MaterialTheme.typography.bodySmall, color = Color.Gray)
        }
    }
}
