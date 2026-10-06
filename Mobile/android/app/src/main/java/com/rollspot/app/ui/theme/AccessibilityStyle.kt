package com.rollspot.app.ui.theme

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ThumbDown
import androidx.compose.material.icons.filled.ThumbUp
import androidx.compose.material.icons.filled.ThumbsUpDown
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.automirrored.filled.Help
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import app.rollspot.shared.places.OverallAccessibility

// How grades *look* on Android. What a grade *is* comes from the shared module.

val OverallAccessibility.label: String
    get() = when (this) {
        OverallAccessibility.ACCESSIBLE -> "Accessible"
        OverallAccessibility.PARTIALLY_ACCESSIBLE -> "Moderately Accessible"
        OverallAccessibility.NOT_ACCESSIBLE -> "Not Accessible"
        OverallAccessibility.NO_DATA -> "No Data Available"
    }

val OverallAccessibility.color: Color
    get() = when (this) {
        OverallAccessibility.ACCESSIBLE -> Color(0xFF28B445)
        OverallAccessibility.PARTIALLY_ACCESSIBLE -> Color(0xFFFF9114)
        OverallAccessibility.NOT_ACCESSIBLE -> Color(0xFFEB3C32)
        OverallAccessibility.NO_DATA -> Color.Gray
    }

val OverallAccessibility.badgeBackground: Color
    get() = when (this) {
        OverallAccessibility.ACCESSIBLE -> Color(0xFFDFF5E2)
        OverallAccessibility.PARTIALLY_ACCESSIBLE -> Color(0xFFFFE8BB)
        OverallAccessibility.NOT_ACCESSIBLE -> Color(0xFFFFE7E5)
        OverallAccessibility.NO_DATA -> Color(0xFFE7E7E7)
    }

val OverallAccessibility.badgeForeground: Color
    get() = when (this) {
        OverallAccessibility.ACCESSIBLE -> Color(0xFF0A6E17)
        OverallAccessibility.PARTIALLY_ACCESSIBLE -> Color(0xFFC86B00)
        OverallAccessibility.NOT_ACCESSIBLE -> Color(0xFFDE362C)
        OverallAccessibility.NO_DATA -> Color(0xFF5F5F5F)
    }

val OverallAccessibility.icon: ImageVector
    get() = when (this) {
        OverallAccessibility.ACCESSIBLE -> Icons.Default.ThumbUp
        OverallAccessibility.PARTIALLY_ACCESSIBLE -> Icons.Default.ThumbsUpDown
        OverallAccessibility.NOT_ACCESSIBLE -> Icons.Default.ThumbDown
        OverallAccessibility.NO_DATA -> Icons.AutoMirrored.Filled.Help
    }

fun featureLabel(feature: String): String = when (feature) {
    "entrance" -> "Entrance"
    "elevator" -> "Elevator"
    "restroom" -> "Restroom"
    else -> feature.replaceFirstChar { it.uppercase() }
}

fun valueLabel(value: String): String = when (value) {
    "yes" -> "Accessible"
    "no" -> "Not accessible"
    "limited" -> "Limited access"
    else -> "Unknown"
}

fun valueIcon(value: String): Pair<ImageVector, Color> = when (value) {
    "yes" -> Icons.Default.CheckCircle to Color(0xFF28B445)
    "no" -> Icons.Default.Cancel to Color(0xFFEB3C32)
    "limited" -> Icons.Default.Warning to Color(0xFFFF9114)
    else -> Icons.AutoMirrored.Filled.Help to Color.Gray
}
