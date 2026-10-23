package app.rollspot.shared.profile

import app.rollspot.shared.api.ApiException
import app.rollspot.shared.api.Profile
import app.rollspot.shared.api.ProfileUpdate
import app.rollspot.shared.api.RollspotApi
import app.rollspot.shared.auth.MobilityAids
import app.rollspot.shared.auth.MobilityRole
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlin.time.Clock
import kotlin.time.ExperimentalTime

data class ProfileState(
    val profile: Profile? = null,
    val isLoading: Boolean = false,
    val isSaving: Boolean = false,
    val isUploadingAvatar: Boolean = false,
    val error: String? = null,
) {
    /** What the header shows; "You" until a name is set. */
    val displayName: String get() = profile?.displayName?.trim()?.takeIf { it.isNotEmpty() } ?: "You"
    val avatarUrl: String? get() = profile?.avatarUrl
    val mobilityRole: MobilityRole? get() = profile?.let { MobilityRole.fromAids(it.mobilityAids) }
    /** Same label the backend puts next to this person's reviews. */
    val roleLabel: String? get() = profile?.let { MobilityAids.role(it.mobilityAids) }
}

/** A profile edit the user has to fix, with copy ready to show. */
class ProfileException(override val message: String) : Exception(message)

/**
 * The signed-in user's profile: name, mobility answers and avatar. Both apps'
 * profile and My Account screens render [state] and call these actions.
 */
class ProfileModel(private val api: RollspotApi) {
    private val _state = MutableStateFlow(ProfileState())
    val state: StateFlow<ProfileState> = _state.asStateFlow()

    @Throws(Exception::class)
    suspend fun load() {
        _state.update { it.copy(isLoading = true, error = null) }
        try {
            val profile = api.profile()
            _state.update { it.copy(profile = profile, isLoading = false) }
        } catch (error: ApiException) {
            _state.update { it.copy(isLoading = false, error = error.message) }
            throw error
        }
    }

    @Throws(Exception::class)
    suspend fun updateDisplayName(name: String) {
        val trimmed = name.trim()
        if (trimmed.isEmpty()) throw ProfileException("Enter your name.")
        if (trimmed.length > MAX_NAME_LENGTH) throw ProfileException("Use $MAX_NAME_LENGTH characters or fewer.")
        save(ProfileUpdate(displayName = trimmed))
    }

    @Throws(Exception::class)
    suspend fun updateMobilityRole(role: MobilityRole) = save(ProfileUpdate(mobilityAids = role.storageAids))

    @Throws(Exception::class)
    suspend fun updateMobilityAids(aids: List<String>) {
        if (aids.isEmpty()) throw ProfileException("Choose at least one option.")
        save(ProfileUpdate(mobilityAids = MobilityAids.options.filter { it in aids } + aids.filterNot { it in MobilityAids.options }))
    }

    /** Saves one or more notification switches; null leaves a switch as it is. */
    @Throws(Exception::class)
    suspend fun updateNotifications(
        savedPlaceReviews: Boolean? = null,
        announcements: Boolean? = null,
        reviewReminders: Boolean? = null,
    ) = save(ProfileUpdate(
        notifySavedPlaceReviews = savedPlaceReviews,
        notifyAnnouncements = announcements,
        notifyReviewReminders = reviewReminders,
    ))

    /** [jpeg] is already compressed by the app. Returns the new avatar URL. */
    @OptIn(ExperimentalTime::class)
    @Throws(Exception::class)
    suspend fun uploadAvatar(jpeg: ByteArray): String {
        if (jpeg.isEmpty()) throw ProfileException("That photo couldn't be read. Try another one.")
        if (jpeg.size > MAX_AVATAR_BYTES) throw ProfileException("That photo is too large. Choose a smaller one.")
        _state.update { it.copy(isUploadingAvatar = true, error = null) }
        try {
            // The avatar always lives at the same URL; a version query makes image caches fetch the new one.
            val url = api.uploadAvatar(jpeg) + "?v=" + Clock.System.now().toEpochMilliseconds()
            _state.update { it.copy(isUploadingAvatar = false, profile = it.profile?.copy(avatarUrl = url)) }
            return url
        } catch (error: ApiException) {
            _state.update { it.copy(isUploadingAvatar = false, error = error.message) }
            throw error
        }
    }

    /** Signed out: forget everything. */
    fun clear() {
        _state.value = ProfileState()
    }

    private suspend fun save(update: ProfileUpdate) {
        _state.update { it.copy(isSaving = true, error = null) }
        try {
            val profile = api.updateProfile(update)
            _state.update { it.copy(profile = profile, isSaving = false) }
        } catch (error: ApiException) {
            _state.update { it.copy(isSaving = false, error = error.message) }
            throw error
        }
    }

    companion object {
        const val MAX_NAME_LENGTH = 80
        /** Matches the backend's avatar limit. */
        const val MAX_AVATAR_BYTES = 5_000_000
    }
}
