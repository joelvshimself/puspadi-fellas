package com.rollspot.app

import android.app.Application
import app.rollspot.shared.RollspotSdk
import app.rollspot.shared.auth.AndroidTokenStore

class RollspotApplication : Application() {
    /** Business logic lives in the shared module; the app creates it once here. */
    lateinit var sdk: RollspotSdk
        private set

    override fun onCreate() {
        super.onCreate()
        sdk = RollspotSdk(BuildConfig.API_BASE_URL, AndroidTokenStore(this))
    }
}
