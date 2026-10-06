package app.rollspot.shared.places

import app.rollspot.shared.api.Place
import kotlin.math.asin
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.sqrt

/** Great-circle distance in meters. */
fun distanceMeters(lat1: Double, lng1: Double, lat2: Double, lng2: Double): Double {
    val rad = kotlin.math.PI / 180
    val dLat = (lat2 - lat1) * rad
    val dLng = (lng2 - lng1) * rad
    val h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1 * rad) * cos(lat2 * rad) * sin(dLng / 2) * sin(dLng / 2)
    return 2 * 6_371_000 * asin(sqrt(h))
}

/** "350 m", "1.2 km", "12 km": the same label on both apps. */
fun formatDistance(meters: Double): String = when {
    meters < 1_000 -> "${(meters / 10).roundToInt() * 10} m"
    meters < 10_000 -> "${(meters / 100).roundToInt() / 10.0} km"
    else -> "${(meters / 1_000).roundToInt()} km"
}

fun Place.distanceLabel(fromLat: Double, fromLng: Double): String = formatDistance(distanceMeters(fromLat, fromLng, lat, lng))
