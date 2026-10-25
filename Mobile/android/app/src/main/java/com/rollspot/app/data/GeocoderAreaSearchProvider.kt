package com.rollspot.app.data

import android.content.Context
import android.location.Address
import android.location.Geocoder
import android.os.Build
import app.rollspot.shared.map.AreaKind
import app.rollspot.shared.map.AreaResult
import app.rollspot.shared.map.AreaSearchProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlin.coroutines.resume

/**
 * Addresses and areas from Android's own Geocoder (no key, no public OSM servers). It only moves
 * the map; places always come from Rollspot's directory. Devices without a geocoder backend
 * (some emulators, de-Googled phones) simply get no area results.
 */
class GeocoderAreaSearchProvider(context: Context) : AreaSearchProvider {
    private val context = context.applicationContext

    override suspend fun search(query: String, nearLat: Double, nearLng: Double): List<AreaResult> {
        if (!Geocoder.isPresent()) return emptyList()
        val geocoder = Geocoder(context)
        val addresses = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                suspendCancellableCoroutine { continuation ->
                    geocoder.getFromLocationName(query, MAX_RESULTS, object : Geocoder.GeocodeListener {
                        override fun onGeocode(addresses: MutableList<Address>) {
                            if (continuation.isActive) continuation.resume(addresses.toList())
                        }

                        override fun onError(errorMessage: String?) {
                            if (continuation.isActive) continuation.resume(emptyList())
                        }
                    })
                }
            } else {
                withContext(Dispatchers.IO) {
                    @Suppress("DEPRECATION")
                    geocoder.getFromLocationName(query, MAX_RESULTS).orEmpty()
                }
            }
        } catch (error: Exception) {
            return emptyList()
        }
        return addresses.mapNotNull(::toArea)
    }

    private fun toArea(address: Address): AreaResult? {
        if (!address.hasLatitude() || !address.hasLongitude()) return null
        val title = listOf(address.featureName, address.locality, address.subAdminArea, address.adminArea, address.countryName)
            .firstOrNull { !it.isNullOrBlank() } ?: return null
        val subtitle = listOf(address.locality, address.adminArea, address.countryName)
            .filter { !it.isNullOrBlank() && it != title }
            .distinct()
            .joinToString(", ")
        val kind = when {
            !address.thoroughfare.isNullOrBlank() -> AreaKind.Address
            !address.subLocality.isNullOrBlank() -> AreaKind.Neighborhood
            !address.locality.isNullOrBlank() -> AreaKind.City
            !address.adminArea.isNullOrBlank() -> AreaKind.Region
            else -> AreaKind.Country
        }
        return AreaResult(title, subtitle, address.latitude, address.longitude, kind)
    }

    private companion object {
        const val MAX_RESULTS = 5
    }
}
