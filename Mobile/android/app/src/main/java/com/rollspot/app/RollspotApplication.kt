package com.rollspot.app

import android.app.Application
import com.rollspot.app.data.SupabaseClient

class RollspotApplication : Application() {
    
    override fun onCreate() {
        super.onCreate()
        
        // Initialize Supabase client
        SupabaseClient.initialize(
            url = BuildConfig.SUPABASE_URL,
            anonKey = BuildConfig.SUPABASE_ANON_KEY
        )
    }
}
