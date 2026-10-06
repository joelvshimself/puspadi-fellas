package com.rollspot.app.data

import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.functions.Functions
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.realtime.Realtime
import io.github.jan.supabase.storage.Storage

/**
 * Single shared Supabase client for the app. Edge Function callers and Postgrest
 * queries all use this so we don't open multiple anonymous sessions.
 * 
 * Mirrors iOS SupabaseClientProvider.
 */
object SupabaseClient {
    
    private lateinit var _client: io.github.jan.supabase.SupabaseClient
    
    val client: io.github.jan.supabase.SupabaseClient
        get() = _client
    
    fun initialize(url: String, anonKey: String) {
        _client = createSupabaseClient(
            supabaseUrl = url,
            supabaseKey = anonKey
        ) {
            install(Auth) {
                scheme = "puspadi"
                host = "auth"
            }
            install(Postgrest)
            install(Functions)
            install(Storage)
            install(Realtime)
        }
    }
}
