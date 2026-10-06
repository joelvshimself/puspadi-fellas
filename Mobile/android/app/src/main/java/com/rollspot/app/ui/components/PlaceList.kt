package com.rollspot.app.ui.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import app.rollspot.shared.api.Place
import app.rollspot.shared.places.distanceLabel
import app.rollspot.shared.places.overallAccessibility
import com.rollspot.app.ui.theme.badgeBackground
import com.rollspot.app.ui.theme.badgeForeground
import com.rollspot.app.ui.theme.label

@Composable
fun PlaceList(
    places: List<Place>,
    fromLat: Double,
    fromLng: Double,
    onPlaceClick: (Place) -> Unit,
    modifier: Modifier = Modifier,
) {
    LazyColumn(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        items(places, key = { it.id }) { place ->
            PlaceListItem(place, place.distanceLabel(fromLat, fromLng), onClick = { onPlaceClick(place) })
        }
    }
}

@Composable
private fun PlaceListItem(place: Place, distance: String, onClick: () -> Unit) {
    val grade = place.overallAccessibility
    Card(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
        colors = CardDefaults.cardColors(containerColor = Color(0xFFF5F5F5)),
    ) {
        Row(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(modifier = Modifier.weight(1f)) {
                Text(place.name, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                Text(
                    listOfNotNull(place.address, distance).joinToString(" · "),
                    style = MaterialTheme.typography.bodySmall,
                    color = Color.Gray,
                )
            }
            Surface(shape = RoundedCornerShape(8.dp), color = grade.badgeBackground) {
                Text(
                    grade.label,
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                    style = MaterialTheme.typography.labelSmall,
                    color = grade.badgeForeground,
                )
            }
        }
    }
}
