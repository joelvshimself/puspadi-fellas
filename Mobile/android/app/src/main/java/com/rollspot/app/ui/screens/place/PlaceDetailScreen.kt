package com.rollspot.app.ui.screens.place

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.rollspot.app.data.models.OverallAccessibility

/**
 * Place detail screen with accessibility info.
 * Mirrors iOS PlaceDetailView
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PlaceDetailScreen(
    placeId: String?,
    onNavigateBack: () -> Unit,
    viewModel: PlaceDetailViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    var selectedTab by remember { mutableStateOf(0) }
    
    LaunchedEffect(placeId) {
        placeId?.let { viewModel.loadPlace(it) }
    }
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(uiState.place?.name ?: "Place Details") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back"
                        )
                    }
                },
                actions = {
                    IconButton(onClick = { /* TODO: Save */ }) {
                        Icon(Icons.Default.Bookmark, contentDescription = "Save")
                    }
                    IconButton(onClick = { /* TODO: Share */ }) {
                        Icon(Icons.Default.Share, contentDescription = "Share")
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
        ) {
            uiState.place?.let { place ->
                // Header with grade
                uiState.grade?.let { grade ->
                    AccessibilityGradeCard(grade = grade)
                }
                
                // Info section
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = Color(0xFFF5F5F5)
                    )
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(
                            text = place.category,
                            style = MaterialTheme.typography.bodyLarge,
                            color = Color.Gray
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        place.address.takeIf { it.isNotEmpty() }?.let {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    Icons.Default.LocationOn,
                                    contentDescription = null,
                                    modifier = Modifier.size(16.dp),
                                    tint = Color.Gray
                                )
                                Spacer(modifier = Modifier.width(4.dp))
                                Text(
                                    text = it,
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = Color.Gray
                                )
                            }
                        }
                        place.phone?.let {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    Icons.Default.Phone,
                                    contentDescription = null,
                                    modifier = Modifier.size(16.dp),
                                    tint = Color.Gray
                                )
                                Spacer(modifier = Modifier.width(4.dp))
                                Text(
                                    text = it,
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = Color.Gray
                                )
                            }
                        }
                    }
                }
                
                // Tabs
                TabRow(selectedTabIndex = selectedTab) {
                    Tab(
                        selected = selectedTab == 0,
                        onClick = { selectedTab = 0 },
                        text = { Text("Facilities") }
                    )
                    Tab(
                        selected = selectedTab == 1,
                        onClick = { selectedTab = 1 },
                        text = { Text("Routes") }
                    )
                    Tab(
                        selected = selectedTab == 2,
                        onClick = { selectedTab = 2 },
                        text = { Text("Reviews") }
                    )
                }
                
                // Tab content
                Box(modifier = Modifier.padding(16.dp)) {
                    when (selectedTab) {
                        0 -> FacilitiesTab(uiState.accessibilityFeatures)
                        1 -> RoutesTab()
                        2 -> ReviewsTab()
                    }
                }
            } ?: run {
                if (uiState.isLoading) {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator()
                    }
                }
            }
        }
    }
}

@Composable
private fun AccessibilityGradeCard(grade: OverallAccessibility) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = grade.badgeBackground
        ),
        shape = RoundedCornerShape(16.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(24.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = when (grade) {
                    OverallAccessibility.ACCESSIBLE -> Icons.Default.ThumbUp
                    OverallAccessibility.PARTIALLY_ACCESSIBLE -> Icons.Default.ThumbsUpDown
                    OverallAccessibility.NOT_ACCESSIBLE -> Icons.Default.ThumbDown
                    OverallAccessibility.NO_DATA -> Icons.Default.Help
                },
                contentDescription = null,
                modifier = Modifier.size(48.dp),
                tint = grade.badgeForeground
            )
            Spacer(modifier = Modifier.width(16.dp))
            Text(
                text = grade.label,
                style = MaterialTheme.typography.headlineMedium,
                color = grade.badgeForeground,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

@Composable
private fun FacilitiesTab(features: List<com.rollspot.app.data.models.AccessibilityFeatureGrade>) {
    if (features.isEmpty()) {
        Text("No facility information available yet.")
    } else {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            features.forEach { feature ->
                FacilityItem(feature)
            }
        }
    }
}

@Composable
private fun FacilityItem(feature: com.rollspot.app.data.models.AccessibilityFeatureGrade) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = Color(0xFFF5F5F5)
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = when (feature.bestValue) {
                    "yes" -> Icons.Default.CheckCircle
                    "no" -> Icons.Default.Cancel
                    "limited" -> Icons.Default.Warning
                    else -> Icons.Default.Help
                },
                contentDescription = null,
                tint = when (feature.bestValue) {
                    "yes" -> Color(0xFF28B445)
                    "no" -> Color(0xFFEB3C32)
                    "limited" -> Color(0xFFFF9114)
                    else -> Color.Gray
                }
            )
            Spacer(modifier = Modifier.width(12.dp))
            Column {
                Text(
                    text = feature.featureLabel,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )
                Text(
                    text = feature.valueLabel,
                    style = MaterialTheme.typography.bodyMedium,
                    color = Color.Gray
                )
            }
        }
    }
}

@Composable
private fun RoutesTab() {
    Text("Routes information coming soon...")
}

@Composable
private fun ReviewsTab() {
    Text("Reviews coming soon...")
}
