package com.rollspot.app.data.services

import com.google.android.gms.maps.model.LatLng
import com.rollspot.app.data.SupabaseClient
import com.rollspot.app.data.models.Place
import io.github.jan.supabase.functions.functions
import io.ktor.client.call.body
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * Searches for nearby places using the Supabase directory.
 * Mirrors iOS NearbyPlacesService
 */
object NearbyPlacesService {
    
    @Serializable
    private data class NearbyPlacesRequest(
        val lat: Double,
        val lng: Double,
        val radius: Double = 5000.0 // 5km default
    )
    
    @Serializable
    private data class NearbyPlaceResponse(
        @SerialName("place_id")
        val placeId: String,
        val name: String,
        val category: String? = null,
        val lat: Double,
        val lng: Double,
        val distance: Double? = null,
        val phone: String? = null,
        val website: String? = null,
        @SerialName("opening_hours")
        val openingHours: String? = null,
        @SerialName("data_attribution")
        val dataAttribution: String? = null,
        @SerialName("known_names")
        val knownNames: List<String>? = null
    )
    
    /**
     * Searches for places in the given region.
     */
    suspend fun search(
        center: LatLng,
        radiusMeters: Double = 5000.0
    ): List<Place> = withContext(Dispatchers.IO) {
        try {
            val client = SupabaseClient.client
            val request = NearbyPlacesRequest(
                lat = center.latitude,
                lng = center.longitude,
                radius = radiusMeters
            )
            
            val response = client.functions.invoke(
                function = "places-nearby",
                body = request
            )
            
            val json = Json { 
                ignoreUnknownKeys = true
                coerceInputValues = true
            }
            
            val places = json.decodeFromString<List<NearbyPlaceResponse>>(
                response.body<String>()
            )
            
            places.map { it.toPlace() }
        } catch (e: Exception) {
            emptyList()
        }
    }
    
    private fun NearbyPlaceResponse.toPlace(): Place {
        return Place(
            name = name,
            category = category ?: "Place",
            coordinate = LatLng(lat, lng),
            distance = distance?.let { "${(it / 1000).toInt()} km" } ?: "",
            directoryPlaceId = placeId,
            knownNames = knownNames ?: emptyList(),
            phone = phone,
            website = website,
            openingHours = openingHours,
            dataAttribution = dataAttribution
        )
    }
}
