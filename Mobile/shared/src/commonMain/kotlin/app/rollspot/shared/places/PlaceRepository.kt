package app.rollspot.shared.places

import app.rollspot.shared.api.Place
import app.rollspot.shared.api.RollspotApi

/**
 * Places come from Rollspot's own directory (OpenStreetMap data synced by the
 * backend), so both apps see the same places with the same IDs. Map rendering
 * stays native; which places exist and how they're graded is decided here.
 */
class PlaceRepository(private val api: RollspotApi) {

    @Throws(Exception::class)
    suspend fun nearby(lat: Double, lng: Double, radiusMeters: Int = DEFAULT_RADIUS_METERS): List<Place> =
        api.nearbyPlaces(lat, lng, radiusMeters.coerceIn(500, 20_000))

    /** Returns nothing for queries too short to be useful, so views can call this on every keystroke. */
    @Throws(Exception::class)
    suspend fun search(query: String, nearLat: Double? = null, nearLng: Double? = null): List<Place> {
        val trimmed = query.trim()
        if (trimmed.length < MIN_QUERY_LENGTH) return emptyList()
        return api.searchPlaces(trimmed, nearLat, nearLng)
    }

    /** [key] is a Rollspot place ID or `osm:<type>/<id>`, e.g. from a deep link. */
    @Throws(Exception::class)
    suspend fun place(key: String): Place = api.place(key)

    companion object {
        const val DEFAULT_RADIUS_METERS = 5_000
        const val MIN_QUERY_LENGTH = 2
        /** Required wherever place data is shown (ODbL). */
        const val ATTRIBUTION = "© OpenStreetMap contributors"
    }
}
