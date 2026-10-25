package com.rollspot.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import app.rollspot.shared.notifications.NotificationsModel
import com.rollspot.app.notifications.Push
import com.rollspot.app.ui.DesignReview
import com.rollspot.app.ui.DesignReviewRoot
import com.rollspot.app.ui.RollspotApp
import com.rollspot.app.ui.screens.splash.SplashScreen
import com.rollspot.app.ui.theme.RollspotTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        handleDeepLink(intent)
        val review = intent?.getStringExtra(DesignReview.EXTRA)
        setContent {
            RollspotTheme {
                Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
                    if (DesignReview.isEnabled(review)) {
                        DesignReviewRoot(review!!, intent?.getStringExtra(DesignReview.TOKEN_EXTRA))
                    } else {
                        var showSplash by rememberSaveable { mutableStateOf(true) }
                        if (showSplash) SplashScreen(onFinished = { showSplash = false }) else RollspotApp()
                    }
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleDeepLink(intent)
    }

    override fun onResume() {
        super.onResume()
        // The user may have changed notification access in system settings while away.
        (application as RollspotApplication).sdk.notifications.setPermission(Push.Permission.status(this))
    }

    private fun handleDeepLink(intent: Intent?) {
        val app = application as RollspotApplication
        // A tapped notification (ours, or a push shown by the system in the background) carries the place.
        intent?.getStringExtra(NotificationsModel.PLACE_ID_KEY)?.takeIf { it.isNotBlank() }?.let {
            app.pendingPlaceLink.value = it
            intent.removeExtra(NotificationsModel.PLACE_ID_KEY)
        }
        val uri = intent?.data ?: return
        // Same link format iOS shares (DeepLinkRouter.swift): the place opens on either app.
        if (uri.scheme == "puspadifellas" && uri.host == "place") {
            uri.getQueryParameter("place_id")?.takeIf { it.isNotBlank() }?.let { app.pendingPlaceLink.value = it }
        }
    }
}
