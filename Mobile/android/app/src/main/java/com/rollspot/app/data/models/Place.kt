package com.rollspot.app.data.models

import com.google.android.gms.maps.model.LatLng
import kotlinx.serialization.Serializable
import java.util.UUID

/**
 * Represents a place with accessibility information.
 * Mirrors iOS Place.swift
 */
data class Place(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val category: String,
    val distance: String = "",
    val address: String = "",
    val ratingLabel: String = "",
    val summary: String = "",
    val description: String = "",
    val coordinate: LatLng,
    val accentColor: Int = 0xFF007AFF.toInt(),
    val gallerySymbols: List<String> = emptyList(),
    val facilitySymbols: List<String> = emptyList(),
    val elevatorDetails: List<ElevatorDetail> = emptyList(),
    val reviewsSummary: String = "",
    var grade: OverallAccessibility? = null,
    val isLiveResult: Boolean = false,
    val directoryPlaceId: String? = null,
    val knownNames: List<String> = emptyList(),
    val phone: String? = null,
    val website: String? = null,
    val openingHours: String? = null,
    val dataAttribution: String? = null
) {
    data class ElevatorDetail(
        val symbol: String,
        val label: String
    )
    
    val matchableNames: Set<String>
        get() {
            val names = if (knownNames.isEmpty()) listOf(name) else knownNames
            return names.map { it.normalized() }.filter { it.isNotEmpty() }.toSet()
        }
    
    companion object {
        /**
         * Canonical place key shared with Supabase edge functions.
         * Mirrors iOS Place.canonicalPlaceId
         */
        fun canonicalPlaceId(lat: Double, lng: Double): String {
            return PlaceCacheStore.key(lat, lng)
        }
        
        fun canonicalPlaceId(coordinate: LatLng): String {
            return canonicalPlaceId(coordinate.latitude, coordinate.longitude)
        }
        
        /**
         * Builds a minimal Place from a search result.
         * Mirrors iOS Place.fromSearchResult
         */
        fun fromSearchResult(
            name: String,
            category: String,
            coordinate: LatLng,
            address: String = "",
            distance: String = ""
        ): Place {
            return Place(
                name = name,
                category = category,
                distance = distance,
                address = address,
                coordinate = coordinate,
                isLiveResult = true
            )
        }
    }
}

/**
 * Normalizes a place name for matching.
 */
fun String.normalized(): String {
    return this.lowercase()
        .replace(Regex("[^a-z0-9\\s]"), "")
        .replace(Regex("\\s+"), " ")
        .trim()
}

/**
 * Helper object for place cache key generation.
 * Mirrors iOS PlaceCacheStore.key
 */
object PlaceCacheStore {
    fun key(lat: Double, lng: Double): String {
        val roundedLat = "%.4f".format(lat)
        val roundedLng = "%.4f".format(lng)
        return "loc_${roundedLat}_${roundedLng}"
    }
}
