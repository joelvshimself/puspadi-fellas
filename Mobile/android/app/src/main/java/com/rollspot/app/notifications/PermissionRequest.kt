package com.rollspot.app.notifications

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import com.rollspot.app.ui.rollspotSdk

/**
 * Asks Android for notification permission, only while the shared model says it hasn't been asked
 * (a switch turned on, or the first saved place). Returns the function to call at that moment.
 */
@Composable
fun rememberNotificationPermissionRequest(): () -> Unit {
    val context = LocalContext.current
    val notifications = rollspotSdk().notifications
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {
        Push.Permission.markAsked(context)
        notifications.setPermission(Push.Permission.status(context))
    }
    return remember(launcher) {
        {
            if (notifications.state.value.canAskPermission && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                launcher.launch(Manifest.permission.POST_NOTIFICATIONS)
            }
        }
    }
}
