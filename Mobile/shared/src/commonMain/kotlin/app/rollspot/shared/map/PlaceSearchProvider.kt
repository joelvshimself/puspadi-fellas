package app.rollspot.shared.map

import app.rollspot.shared.api.Place
import app.rollspot.shared.places.PlaceRepository

/**
 * Where the map gets places from. Both apps use [RepositoryPlaceSearchProvider]
 * (Rollspot's own directory), so the same spot shows the same places with the
 * same IDs. The interface exists so [MapModel] can be tested without a network.
 */
interface PlaceSearchProvider {
    @Throws(Exception::class)
    suspend fun nearby(lat: Double, lng: Double, radiusMeters: Int): List<Place>

    @Throws(Exception::class)
    suspend fun search(query: String, nearLat: Double, nearLng: Double): List<Place>
}

class RepositoryPlaceSearchProvider(private val places: PlaceRepository) : PlaceSearchProvider {
    override suspend fun nearby(lat: Double, lng: Double, radiusMeters: Int): List<Place> =
        places.nearby(lat, lng, radiusMeters)

    override suspend fun search(query: String, nearLat: Double, nearLng: Double): List<Place> =
        places.search(query, nearLat, nearLng)
}
