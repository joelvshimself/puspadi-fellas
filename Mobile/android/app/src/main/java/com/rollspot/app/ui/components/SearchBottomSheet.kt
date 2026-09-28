package com.rollspot.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.rollspot.app.data.models.Place

/**
 * Search bottom sheet with category tabs.
 * Mirrors iOS SearchSheet
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SearchBottomSheet(
    sheetState: SheetState,
    places: List<Place>,
    searchQuery: String,
    onSearchQueryChange: (String) -> Unit,
    onPlaceClick: (Place) -> Unit,
    onExploreClick: () -> Unit,
    onSavedClick: () -> Unit,
    onContributeClick: () -> Unit
) {
    var selectedTab by remember { mutableStateOf(0) }
    
    ModalBottomSheet(
        onDismissRequest = { },
        sheetState = sheetState,
        containerColor = Color.White.copy(alpha = 0.95f),
        dragHandle = {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 8.dp),
                contentAlignment = Alignment.Center
            ) {
                Box(
                    modifier = Modifier
                        .width(40.dp)
                        .height(4.dp)
                        .clip(RoundedCornerShape(2.dp))
                        .background(Color.Gray.copy(alpha = 0.3f))
                )
            }
        }
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
        ) {
            // Search bar
            OutlinedTextField(
                value = searchQuery,
                onValueChange = onSearchQueryChange,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 16.dp),
                placeholder = { Text("Find a place") },
                leadingIcon = {
                    Icon(
                        imageVector = Icons.Default.Search,
                        contentDescription = "Search"
                    )
                },
                singleLine = true,
                shape = RoundedCornerShape(12.dp),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedContainerColor = Color.White,
                    unfocusedContainerColor = Color(0xFFF5F5F5)
                )
            )
            
            // Category tabs
            TabRow(
                selectedTabIndex = selectedTab,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 16.dp),
                containerColor = Color.Transparent,
                indicator = { }
            ) {
                Tab(
                    selected = selectedTab == 0,
                    onClick = {
                        selectedTab = 0
                        onExploreClick()
                    },
                    text = {
                        Text(
                            "Explore",
                            fontWeight = if (selectedTab == 0) FontWeight.Bold else FontWeight.Normal
                        )
                    }
                )
                Tab(
                    selected = selectedTab == 1,
                    onClick = {
                        selectedTab = 1
                        onSavedClick()
                    },
                    text = {
                        Text(
                            "Saved",
                            fontWeight = if (selectedTab == 1) FontWeight.Bold else FontWeight.Normal
                        )
                    }
                )
                Tab(
                    selected = selectedTab == 2,
                    onClick = {
                        selectedTab = 2
                        onContributeClick()
                    },
                    text = {
                        Text(
                            "Contribute",
                            fontWeight = if (selectedTab == 2) FontWeight.Bold else FontWeight.Normal
                        )
                    }
                )
            }
            
            // Places list
            LazyColumn(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(places) { place ->
                    PlaceListItem(
                        place = place,
                        onClick = { onPlaceClick(place) }
                    )
                }
            }
        }
    }
}

@Composable
private fun PlaceListItem(
    place: Place,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
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
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = place.name,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )
                Text(
                    text = place.category,
                    style = MaterialTheme.typography.bodyMedium,
                    color = Color.Gray
                )
                if (place.distance.isNotEmpty()) {
                    Text(
                        text = place.distance,
                        style = MaterialTheme.typography.bodySmall,
                        color = Color.Gray
                    )
                }
            }
            
            // Accessibility badge
            place.grade?.let { grade ->
                Surface(
                    shape = RoundedCornerShape(8.dp),
                    color = grade.badgeBackground
                ) {
                    Text(
                        text = grade.label.take(1),
                        modifier = Modifier.padding(8.dp),
                        color = grade.badgeForeground,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }
    }
}
