package com.rollspot.app.data.models

import androidx.compose.ui.graphics.Color
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Mirrors one row returned by the accessibility_grade() Postgres function.
 * Mirrors iOS AccessibilityFeatureGrade
 */
@Serializable
data class AccessibilityFeatureGrade(
    val feature: String,
    @SerialName("best_value")
    val bestValue: String,
    val confidence: Double
) {
    val featureLabel: String
        get() = when (feature) {
            "entrance" -> "Entrance"
            "parking" -> "Parking"
            "restroom" -> "Restroom"
            "seating" -> "Seating"
            "elevator" -> "Elevator"
            else -> feature.replaceFirstChar { it.uppercase() }
        }
    
    val valueLabel: String
        get() = when (bestValue) {
            "yes" -> "Accessible"
            "no" -> "Not accessible"
            "limited" -> "Limited access"
            else -> "Unknown"
        }
    
    val symbolName: String
        get() = when (bestValue) {
            "yes" -> "check_circle"
            "no" -> "cancel"
            "limited" -> "warning"
            else -> "help"
        }
}

/**
 * The place_cache row as returned by the Edge Function.
 * Mirrors iOS PlaceCacheRow
 */
@Serializable
data class PlaceCacheRow(
    @SerialName("place_id")
    val placeId: String,
    val name: String? = null,
    val lat: Double? = null,
    val lng: Double? = null,
    @SerialName("osm_accessibility")
    val osmAccessibility: Map<String, String>? = null,
    @SerialName("image_url")
    val imageUrl: String? = null,
    @SerialName("image_attribution")
    val imageAttribution: String? = null,
    @SerialName("refresh_claimed_at")
    val refreshClaimedAt: String? = null
)

/**
 * Response shape of place-accessibility Edge Function.
 * Mirrors iOS PlaceAccessibilityResponse
 */
@Serializable
data class PlaceAccessibilityResponse(
    val status: String,
    val place: PlaceCacheRow? = null,
    val grade: List<AccessibilityFeatureGrade>? = null
)

/**
 * Overall accessibility badge shown on pins and detail headers.
 * Mirrors iOS OverallAccessibility
 */
enum class OverallAccessibility {
    ACCESSIBLE,
    PARTIALLY_ACCESSIBLE,
    NOT_ACCESSIBLE,
    NO_DATA;
    
    val label: String
        get() = when (this) {
            ACCESSIBLE -> "Accessible"
            PARTIALLY_ACCESSIBLE -> "Moderately Accessible"
            NOT_ACCESSIBLE -> "Not Accessible"
            NO_DATA -> "No Data Available"
        }
    
    val color: Color
        get() = when (this) {
            ACCESSIBLE -> Color(0xFF28B445)
            PARTIALLY_ACCESSIBLE -> Color(0xFFFF9114)
            NOT_ACCESSIBLE -> Color(0xFFEB3C32)
            NO_DATA -> Color.Gray
        }
    
    val symbolName: String
        get() = when (this) {
            ACCESSIBLE -> "thumb_up"
            PARTIALLY_ACCESSIBLE -> "thumbs_up_down"
            NOT_ACCESSIBLE -> "thumb_down"
            NO_DATA -> "help"
        }
    
    val badgeBackground: Color
        get() = when (this) {
            ACCESSIBLE -> Color(0xFFDFF5E2)
            PARTIALLY_ACCESSIBLE -> Color(0xFFFFE8BB)
            NOT_ACCESSIBLE -> Color(0xFFFFE7E5)
            NO_DATA -> Color(0xFFE7E7E7)
        }
    
    val badgeForeground: Color
        get() = when (this) {
            ACCESSIBLE -> Color(0xFF0A6E17)
            PARTIALLY_ACCESSIBLE -> Color(0xFFC86B00)
            NOT_ACCESSIBLE -> Color(0xFFDE362C)
            NO_DATA -> Color(0xFF5F5F5F)
        }
}

/**
 * Collapses per-feature grades into a single badge.
 * Mirrors iOS collapseAccessibility function.
 */
fun collapseAccessibility(grades: List<AccessibilityFeatureGrade>?): OverallAccessibility {
    if (grades.isNullOrEmpty()) return OverallAccessibility.NO_DATA
    
    val known = grades.filter { it.bestValue in listOf("yes", "no", "limited") }
    if (known.isEmpty()) return OverallAccessibility.NO_DATA
    
    return when {
        known.any { it.bestValue == "no" } -> OverallAccessibility.NOT_ACCESSIBLE
        known.any { it.bestValue == "limited" } -> OverallAccessibility.PARTIALLY_ACCESSIBLE
        else -> OverallAccessibility.ACCESSIBLE
    }
}
