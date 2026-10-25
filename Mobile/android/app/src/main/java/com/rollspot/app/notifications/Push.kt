package com.rollspot.app.notifications

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import app.rollspot.shared.notifications.NotificationPermission
import app.rollspot.shared.notifications.NotificationsModel
import app.rollspot.shared.notifications.PushPlatform
import app.rollspot.shared.notifications.ReminderPlan
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.messaging.FirebaseMessaging
import com.rollspot.app.BuildConfig
import com.rollspot.app.MainActivity
import com.rollspot.app.R
import com.rollspot.app.RollspotApplication
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch

/**
 * The Android half of notifications (iOS: PushNotifications.swift). What to show and when lives in
 * the shared NotificationsModel; this file only talks to Firebase, the OS permission and AlarmManager.
 */
object Push {
    /** Firebase options come from local.properties; without them push stays off (reminders still work). */
    val isConfigured: Boolean
        get() = BuildConfig.FIREBASE_APP_ID.isNotBlank() && BuildConfig.FIREBASE_API_KEY.isNotBlank() &&
            BuildConfig.FIREBASE_PROJECT_ID.isNotBlank() && BuildConfig.FIREBASE_SENDER_ID.isNotBlank()

    /** Called once from [RollspotApplication.onCreate]. */
    fun start(app: RollspotApplication) {
        Channels.create(app)
        val notifications = app.sdk.notifications
        notifications.setPermission(Permission.status(app))

        if (isConfigured) {
            if (FirebaseApp.getApps(app).isEmpty()) {
                FirebaseApp.initializeApp(
                    app,
                    FirebaseOptions.Builder()
                        .setApiKey(BuildConfig.FIREBASE_API_KEY)
                        .setApplicationId(BuildConfig.FIREBASE_APP_ID)
                        .setProjectId(BuildConfig.FIREBASE_PROJECT_ID)
                        .setGcmSenderId(BuildConfig.FIREBASE_SENDER_ID)
                        .build(),
                )
            }
            val messaging = FirebaseMessaging.getInstance()
            messaging.isAutoInitEnabled = true
            messaging.token.addOnSuccessListener { token ->
                app.appScope.launch { runCatching { notifications.setPushToken(token, PushPlatform.Android) } }
            }
            app.appScope.launch {
                notifications.state.map { it.receivesAnnouncements }.distinctUntilChanged().collect { on ->
                    if (on) messaging.subscribeToTopic(NotificationsModel.ANNOUNCEMENTS_TOPIC)
                    else messaging.unsubscribeFromTopic(NotificationsModel.ANNOUNCEMENTS_TOPIC)
                }
            }
        }

        app.appScope.launch { notifications.reminder.collect { Reminder.schedule(app, it) } }
    }

    /** Posts a notification that opens [placeId] (or just the app) when tapped. */
    fun show(context: Context, channel: String, title: String, body: String, placeId: String?, id: Int) {
        if (Permission.status(context) != NotificationPermission.Granted) return
        val open = Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            .apply { placeId?.let { putExtra(NotificationsModel.PLACE_ID_KEY, it) } }
        val tap = PendingIntent.getActivity(
            context, id, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, channel)
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(ContextCompat.getColor(context, R.color.notification_accent))
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(tap)
            .setAutoCancel(true)
            .build()
        try {
            NotificationManagerCompat.from(context).notify(id, notification)
        } catch (_: SecurityException) {
            // Permission withdrawn between the check and the post.
        }
    }

    /** Ids match the backend's android.notification.channel_id (backend/src/push.ts). */
    object Channels {
        const val REVIEWS = "reviews"
        const val ANNOUNCEMENTS = "announcements"
        const val REMINDERS = "reminders"

        fun create(context: Context) {
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.createNotificationChannels(
                listOf(
                    NotificationChannel(REVIEWS, context.getString(R.string.notif_saved_title), NotificationManager.IMPORTANCE_DEFAULT),
                    NotificationChannel(REMINDERS, context.getString(R.string.notif_reminders_title), NotificationManager.IMPORTANCE_DEFAULT),
                    NotificationChannel(ANNOUNCEMENTS, context.getString(R.string.notif_news_title), NotificationManager.IMPORTANCE_LOW),
                ),
            )
        }
    }

    object Permission {
        private const val PREFS = "rollspot.notifications"
        private const val ASKED = "askedPermission"

        /**
         * Android 13+ has a runtime permission: never asked → NotAsked, asked and refused → Denied.
         * Older phones allow notifications unless they were switched off in system settings.
         */
        fun status(context: Context): NotificationPermission {
            val enabled = NotificationManagerCompat.from(context).areNotificationsEnabled()
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                return if (enabled) NotificationPermission.Granted else NotificationPermission.Denied
            }
            val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
            return when {
                granted && enabled -> NotificationPermission.Granted
                granted || wasAsked(context) -> NotificationPermission.Denied
                else -> NotificationPermission.NotAsked
            }
        }

        fun markAsked(context: Context) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(ASKED, true).apply()
        }

        private fun wasAsked(context: Context) =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(ASKED, false)
    }

    /** The one unfinished-review reminder (shared ReminderPlan), as an inexact alarm: no exact-alarm permission needed. */
    object Reminder {
        private const val REQUEST_CODE = 4_201

        fun schedule(context: Context, plan: ReminderPlan?) {
            val alarms = context.getSystemService(AlarmManager::class.java)
            val existing = pendingIntent(context, null)
            alarms.cancel(existing)
            if (plan == null || plan.fireAtMillis <= System.currentTimeMillis()) return
            alarms.set(AlarmManager.RTC_WAKEUP, plan.fireAtMillis, pendingIntent(context, plan))
        }

        private fun pendingIntent(context: Context, plan: ReminderPlan?): PendingIntent {
            val intent = Intent(context, ReminderReceiver::class.java).setAction(ReminderPlan.ID).apply {
                plan?.let {
                    putExtra(NotificationsModel.PLACE_ID_KEY, it.placeId)
                    putExtra(ReminderReceiver.PLACE_NAME, it.placeName)
                }
            }
            return PendingIntent.getBroadcast(
                context, REQUEST_CODE, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }
}
