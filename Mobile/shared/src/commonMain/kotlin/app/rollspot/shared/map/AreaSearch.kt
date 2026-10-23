package app.rollspot.shared.map

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** How big a found area is; decides how far the map zooms out to show it. */
enum class AreaKind(val radiusMeters: Int) {
    /** A street address or a single building. */
    Address(800),
    /** A neighbourhood, village or district. */
    Neighborhood(3_000),
    /** A town or city. */
    City(10_000),
    /** A province, state or island. */
    Region(60_000),
    Country(400_000),
}

/**
 * An address or area found by the phone's own geocoder (Apple Maps search on iOS, Android's
 * Geocoder). It only moves the map: places themselves always come from Rollspot's directory.
 */
data class AreaResult(
    val title: String,
    /** "Shibuya, Tokyo, Japan": where it is, for telling same-named places apart. */
    val subtitle: String,
    val lat: Double,
    val lng: Double,
    val kind: AreaKind,
) {
    val radiusMeters: Int get() = kind.radiusMeters
}

/** Implemented by each app over its platform geocoder; the map works without one. */
interface AreaSearchProvider {
    @Throws(Exception::class)
    suspend fun search(query: String, nearLat: Double, nearLng: Double): List<AreaResult>
}

/** An area the place directory covers (an active sync region on the backend). */
@Serializable
data class CoverageRegion(
    val id: String,
    val name: String,
    val south: Double,
    val west: Double,
    val north: Double,
    val east: Double,
    /** Where "Go to" lands: a busy spot. Falls back to the middle of the box. */
    @SerialName("focus_lat") val focusLat: Double? = null,
    @SerialName("focus_lng") val focusLng: Double? = null,
) {
    val centerLat: Double get() = focusLat ?: ((south + north) / 2)
    val centerLng: Double get() = focusLng ?: ((west + east) / 2)

    fun contains(lat: Double, lng: Double): Boolean = lat in south..north && lng in west..east
}
