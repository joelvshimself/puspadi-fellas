package com.rollspot.app.data.services

import com.rollspot.app.data.SupabaseClient
import com.rollspot.app.data.models.PlaceAccessibilityResponse
import com.rollspot.app.data.models.PlaceCacheStore
import io.github.jan.supabase.functions.functions
import io.ktor.client.call.body
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * Collapses concurrent enrich() calls for the same place onto a single request.
 * Mirrors iOS EnrichCoalescer
 */
private class EnrichCoalescer {
    private val inFlight = mutableMapOf<String, suspend () -> PlaceAccessibilityResponse>()
    private val mutex = Mutex()
    
    suspend fun run(
        key: String,
        operation: suspend () -> PlaceAccessibilityResponse
    ): PlaceAccessibilityResponse {
        mutex.withLock {
            if (inFlight.containsKey(key)) {
                val existing = inFlight[key]!!
                mutex.unlock()
                return existing()
            }
            inFlight[key] = operation
        }
        
        return try {
            operation()
        } finally {
            mutex.withLock {
                inFlight.remove(key)
            }
        }
    }
}

/**
 * Talks to the place-accessibility Edge Function.
 * Mirrors iOS AccessibilityService
 */
class AccessibilityService {
    
    private val client = SupabaseClient.client
    private val coalescer = EnrichCoalescer()
    private val cache = PlaceCache()
    
    @Serializable
    private data class EnrichRequestBody(
        val lat: Double,
        val lng: Double,
        val name: String?
    )
    
    /**
     * Whatever we already hold for this place, without touching the network.
     */
    suspend fun cached(lat: Double, lng: Double, name: String?): PlaceAccessibilityResponse? {
        return cache.get(lat, lng, name)
    }
    
    /**
     * Enriches a place with accessibility data from the backend.
     */
    suspend fun enrich(
        lat: Double,
        lng: Double,
        name: String?,
        userInitiated: Boolean = false
    ): Result<PlaceAccessibilityResponse> = runCatching {
        val key = PlaceCacheStore.key(lat, lng)
        
        // Check cache first
        cache.get(lat, lng, name)?.let { return Result.success(it) }
        
        // Check negative cache (backoff)
        if (!userInitiated) {
            cache.activeBackoff(key)?.let { 
                return Result.failure(Exception("Backing off: $it"))
            }
        }
        
        // Make request
        coalescer.run(key) {
            try {
                val body = EnrichRequestBody(lat, lng, name)
                val response = client.functions.invoke(
                    function = "place-accessibility",
                    body = body
                )
                
                val json = Json { 
                    ignoreUnknownKeys = true
                    coerceInputValues = true
                }
                val result = json.decodeFromString<PlaceAccessibilityResponse>(
                    response.body<String>()
                )
                
                cache.set(key, result)
                result
            } catch (e: Exception) {
                if (e !is kotlinx.coroutines.CancellationException) {
                    cache.recordFailure(key)
                }
                throw e
            }
        }
    }
    
    companion object {
        val shared = AccessibilityService()
    }
}

/**
 * Simple in-memory cache for place accessibility responses.
 * Mirrors iOS PlaceCacheStore behavior
 */
private class PlaceCache {
    private val cache = mutableMapOf<String, PlaceAccessibilityResponse>()
    private val failures = mutableMapOf<String, Long>()
    private val mutex = Mutex()
    
    suspend fun get(lat: Double, lng: Double, name: String?): PlaceAccessibilityResponse? {
        val key = PlaceCacheStore.key(lat, lng)
        return mutex.withLock {
            cache[key]
        }
    }
    
    suspend fun set(key: String, response: PlaceAccessibilityResponse) {
        mutex.withLock {
            cache[key] = response
            failures.remove(key)
        }
    }
    
    suspend fun activeBackoff(key: String): String? {
        return mutex.withLock {
            val lastFailure = failures[key] ?: return@withLock null
            val elapsed = System.currentTimeMillis() - lastFailure
            if (elapsed < 30_000) { // 30 second backoff
                "Too many recent failures"
            } else {
                null
            }
        }
    }
    
    suspend fun recordFailure(key: String) {
        mutex.withLock {
            failures[key] = System.currentTimeMillis()
        }
    }
}
