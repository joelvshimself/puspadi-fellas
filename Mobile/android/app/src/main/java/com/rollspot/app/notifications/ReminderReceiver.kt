package com.rollspot.app.notifications

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import app.rollspot.shared.notifications.NotificationsModel
import com.rollspot.app.R

/** Fires when the unfinished-review reminder is due (scheduled by [Push.Reminder]). */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val placeId = intent.getStringExtra(NotificationsModel.PLACE_ID_KEY) ?: return
        val placeName = intent.getStringExtra(PLACE_NAME).orEmpty()
        Push.show(
            context,
            Push.Channels.REMINDERS,
            context.getString(R.string.reminder_title),
            context.getString(R.string.reminder_body, placeName),
            placeId,
            id = REMINDER_NOTIFICATION_ID,
        )
    }

    companion object {
        const val PLACE_NAME = "place_name"
        private const val REMINDER_NOTIFICATION_ID = 4_201
    }
}
