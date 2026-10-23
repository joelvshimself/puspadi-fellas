package com.rollspot.app.notifications

import app.rollspot.shared.notifications.NotificationsModel
import app.rollspot.shared.notifications.PushPlatform
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.rollspot.app.RollspotApplication
import kotlinx.coroutines.launch

/**
 * Firebase Cloud Messaging. In the background the system shows pushes itself (on the channel the
 * backend names); in the foreground they arrive here and are shown the same way.
 */
class RollspotMessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        val app = application as RollspotApplication
        app.appScope.launch { runCatching { app.sdk.notifications.setPushToken(token, PushPlatform.Android) } }
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val notification = message.notification ?: return
        val placeId = message.data[NotificationsModel.PLACE_ID_KEY]
        Push.show(
            this,
            channel = notification.channelId ?: if (message.data["kind"] == "announcement") Push.Channels.ANNOUNCEMENTS else Push.Channels.REVIEWS,
            title = notification.title.orEmpty(),
            body = notification.body.orEmpty(),
            placeId = placeId,
            // One notification per place, like the backend's collapse key.
            id = (placeId ?: message.messageId ?: "rollspot").hashCode(),
        )
    }
}
