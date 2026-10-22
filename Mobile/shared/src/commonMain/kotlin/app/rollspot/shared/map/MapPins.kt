package app.rollspot.shared.map

import app.rollspot.shared.api.Place
import app.rollspot.shared.places.OverallAccessibility
import app.rollspot.shared.places.distanceLabel
import app.rollspot.shared.places.distanceMeters
import app.rollspot.shared.places.overallAccessibility

/** A place as the map and the result list show it: the grade and distance are already decided. */
data class MapPin(
    val place: Place,
    val grade: OverallAccessibility,
    val distanceMeters: Double,
    val distanceLabel: String,
) {
    val id: String get() = place.id
}

/** Two entries closer than this with the same normalized name are one place (e.g. a mall mapped as node and way). */
const val DUPLICATE_DISTANCE_METERS = 75.0

/** "Beachwalk  Bali!" and "beachwalk bali" compare equal. */
fun normalizePlaceName(name: String): String = name.lowercase().filter { it.isLetterOrDigit() }

/**
 * Drops duplicates (same normalized name within [DUPLICATE_DISTANCE_METERS]),
 * keeping the entry with more graded features. Order of first appearance is kept.
 */
fun dedupePlaces(places: List<Place>): List<Place> {
    val kept = mutableListOf<Place>()
    for (place in places) {
        val key = normalizePlaceName(place.name)
        val index = kept.indexOfFirst {
            it.id == place.id ||
                (normalizePlaceName(it.name) == key && distanceMeters(it.lat, it.lng, place.lat, place.lng) < DUPLICATE_DISTANCE_METERS)
        }
        when {
            index < 0 -> kept += place
            place.grade.size > kept[index].grade.size -> kept[index] = place
        }
    }
    return kept
}

/** One place as the map and lists show it, with grade and distance from ([lat], [lng]). */
fun pinFor(place: Place, lat: Double, lng: Double): MapPin = MapPin(
    place = place,
    grade = place.overallAccessibility,
    distanceMeters = distanceMeters(lat, lng, place.lat, place.lng),
    distanceLabel = place.distanceLabel(lat, lng),
)

/** Dedupes, attaches grade and distance from ([lat], [lng]), and sorts nearest first (ties by name). */
fun toPins(places: List<Place>, lat: Double, lng: Double): List<MapPin> =
    dedupePlaces(places)
        .map { pinFor(it, lat, lng) }
        .sortedWith(compareBy<MapPin> { it.distanceMeters }.thenBy { it.place.name })
