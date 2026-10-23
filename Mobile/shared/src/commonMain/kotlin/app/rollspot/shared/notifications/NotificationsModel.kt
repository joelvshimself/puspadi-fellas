package app.rollspot.shared.notifications

import app.rollspot.shared.api.RollspotApi
import app.rollspot.shared.drafts.ContributeDrafts
import app.rollspot.shared.profile.ProfileModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update

/** What the phone itself allows. The apps read it from the OS and report it with [NotificationsModel.setPermission]. */
enum class NotificationPermission { NotAsked, Granted, Denied }

enum class PushPlatform(val wire: String) { Ios("ios"), Android("android") }

/** The three switches on the Notifications screen. */
data class NotificationSettings(
    val savedPlaceReviews: Boolean = true,
    val announcements: Boolean = true,
    val reviewReminders: Boolean = true,
)

data class NotificationsState(
    val settings: NotificationSettings = NotificationSettings(),
    val permission: NotificationPermission = NotificationPermission.NotAsked,
    val isSignedIn: Boolean = false,
    val error: String? = null,
) {
    /** The phone blocks notifications: the screen says so and links to the system settings. */
    val isBlocked: Boolean get() = permission == NotificationPermission.Denied

    /** The system prompt hasn't been shown yet: ask at a moment that explains itself (first save, a switch turned on). */
    val canAskPermission: Boolean get() = permission == NotificationPermission.NotAsked

    /** Whether this phone should be subscribed to the Firebase announcements topic. */
    val receivesAnnouncements: Boolean get() = permission == NotificationPermission.Granted && settings.announcements
}

/**
 * A local reminder for an unfinished review, scheduled on the phone (no server). The apps keep exactly
 * one scheduled under [ID]: replace it when the plan changes, cancel it when the plan is null.
 */
data class ReminderPlan(val placeId: String, val placeName: String, val fireAtMillis: Long) {
    companion object {
        const val ID = "rollspot.review-reminder"
        /** How long after the last answer the reminder comes. */
        const val DELAY_MILLIS = 24L * 60 * 60 * 1000
    }
}

/**
 * Push notifications and reminders, for both apps. The apps hand over the Firebase token and the
 * OS permission, show [state] on the Notifications screen, schedule [reminder], and subscribe to
 * [ANNOUNCEMENTS_TOPIC] while [NotificationsState.receivesAnnouncements] is true.
 */
class NotificationsModel internal constructor(
    private val api: RollspotApi,
    private val profile: ProfileModel,
    drafts: ContributeDrafts,
    private val scope: CoroutineScope,
) {
    private var platform: PushPlatform? = null
    private var pushToken: String? = null
    private var userId: String? = null
    /** token + user last sent to the backend, so the same pair isn't registered twice. */
    private var registered: Pair<String, String>? = null

    private val local = MutableStateFlow(NotificationsState())
    /** A switch flipped but not saved yet: shown right away, undone if saving fails. */
    private val pending = MutableStateFlow<NotificationSettings?>(null)

    val state: StateFlow<NotificationsState> = combine(local, profile.state, pending) { local, profileState, pending ->
        val saved = profileState.profile?.let {
            NotificationSettings(it.notifySavedPlaceReviews, it.notifyAnnouncements, it.notifyReviewReminders)
        } ?: NotificationSettings()
        local.copy(settings = pending ?: saved)
    }.stateIn(scope, SharingStarted.Eagerly, NotificationsState())

    /** The unfinished-review reminder to have scheduled right now, or null for none. */
    val reminder: StateFlow<ReminderPlan?> = combine(drafts.waiting, state) { waiting, state ->
        if (waiting == null || state.permission != NotificationPermission.Granted || !state.settings.reviewReminders) {
            null
        } else {
            ReminderPlan(waiting.placeId, waiting.placeName, waiting.updatedAtMillis + ReminderPlan.DELAY_MILLIS)
        }
    }.stateIn(scope, SharingStarted.Eagerly, null)

    /** Call whenever the app learns the OS permission (launch, return from Settings, after the prompt). */
    fun setPermission(permission: NotificationPermission) {
        local.update { it.copy(permission = permission) }
    }

    /** The Firebase token, whenever Firebase hands one over (first launch, and when it rotates). */
    @Throws(Exception::class)
    suspend fun setPushToken(token: String, platform: PushPlatform) {
        this.platform = platform
        pushToken = token
        registerIfNeeded()
    }

    @Throws(Exception::class)
    suspend fun setSavedPlaceReviews(on: Boolean) = change({ it.copy(savedPlaceReviews = on) }) {
        profile.updateNotifications(savedPlaceReviews = on)
    }

    @Throws(Exception::class)
    suspend fun setAnnouncements(on: Boolean) = change({ it.copy(announcements = on) }) {
        profile.updateNotifications(announcements = on)
    }

    @Throws(Exception::class)
    suspend fun setReviewReminders(on: Boolean) = change({ it.copy(reviewReminders = on) }) {
        profile.updateNotifications(reviewReminders = on)
    }

    // ---- Session (called by RollspotSdk) ----

    internal suspend fun signedIn(userId: String) {
        this.userId = userId
        local.update { it.copy(isSignedIn = true) }
        registerIfNeeded()
    }

    internal fun signedOut() {
        userId = null
        registered = null
        pending.value = null
        local.update { it.copy(isSignedIn = false, error = null) }
    }

    /** Before the session ends, so the signed-out user's pushes stop reaching this phone. */
    internal suspend fun unregister() {
        val token = pushToken ?: return
        if (registered?.first == token) runCatching { api.unregisterPushDevice(token) }
        registered = null
    }

    private suspend fun registerIfNeeded() {
        val token = pushToken ?: return
        val user = userId ?: return
        val platform = platform ?: return
        if (registered == token to user) return
        try {
            api.registerPushDevice(token, platform.wire)
            registered = token to user
        } catch (error: Exception) {
            // Tried again on the next launch or token change; pushes just don't arrive until then.
        }
    }

    private suspend fun change(edit: (NotificationSettings) -> NotificationSettings, save: suspend () -> Unit) {
        pending.value = edit(state.value.settings)
        local.update { it.copy(error = null) }
        try {
            save()
        } catch (error: Exception) {
            local.update { it.copy(error = "Couldn't save that. Check your connection and try again.") }
            throw error
        } finally {
            pending.value = null
        }
    }

    companion object {
        /** Firebase topic for announcements; matches the backend. */
        const val ANNOUNCEMENTS_TOPIC = "announcements"
        /** Push and reminder payloads carry the place to open under this key. */
        const val PLACE_ID_KEY = "place_id"
    }
}
