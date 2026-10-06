package com.rollspot.app

import android.app.Application
import app.rollspot.shared.RollspotSdk
import app.rollspot.shared.auth.AndroidTokenStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.launch

class RollspotApplication : Application() {
    /** Business logic lives in the shared module; the app creates it once here. */
    lateinit var sdk: RollspotSdk
        private set

    /** App-lifetime work (session restore). */
    val appScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    /** Fires when the email verification link (puspadi://auth/callback) opens the app. */
    val authCallbacks = MutableSharedFlow<Unit>(extraBufferCapacity = 1)

    override fun onCreate() {
        super.onCreate()
        sdk = RollspotSdk(BuildConfig.API_BASE_URL, AndroidTokenStore(this))
        appScope.launch { runCatching { sdk.auth.restore() } }
    }
}
