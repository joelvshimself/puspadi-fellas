package com.rollspot.app

import android.app.Application
import app.rollspot.shared.RollspotSdk
import app.rollspot.shared.drafts.FileDraftStorage
import app.rollspot.shared.auth.AndroidTokenStore
import com.rollspot.app.notifications.Push
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch

class RollspotApplication : Application() {
    /** Business logic lives in the shared module; the app creates it once here. */
    lateinit var sdk: RollspotSdk
        private set

    /** App-lifetime work (session restore). */
    val appScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    /** A shared place link (puspadifellas://place?place_id=…) waiting to be opened. */
    val pendingPlaceLink = MutableStateFlow<String?>(null)

    override fun onCreate() {
        super.onCreate()
        sdk = RollspotSdk(
            BuildConfig.API_BASE_URL,
            AndroidTokenStore(this),
            draftStorage = FileDraftStorage(java.io.File(filesDir, "drafts").path),
        )
        appScope.launch { runCatching { sdk.auth.restore() } }
        Push.start(this)
    }
}
