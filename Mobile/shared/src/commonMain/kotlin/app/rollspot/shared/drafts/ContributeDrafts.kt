package app.rollspot.shared.drafts

import app.rollspot.shared.reviews.ContributeFlowState
import app.rollspot.shared.reviews.LocalReviewPhoto
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import kotlin.time.Clock
import kotlin.time.ExperimentalTime

/** A contribution someone started and hasn't submitted: what the Home "Continue Survey" banner offers. */
@Serializable
data class WaitingContribution(
    val placeId: String,
    val placeName: String,
    val userId: String,
    val updatedAtMillis: Long,
)

/**
 * Unfinished contributions, kept on the device per user. The Home banner shows [waiting], the
 * newest one for whoever is signed in; it hides on sign-out and comes back on sign-in.
 *
 * Android saves the whole shared flow with [saveFlow] and resumes with [restoreFlow]. iOS still runs
 * its own wizard (until F4 moves it onto the shared flow), so it only reports with [remember]/[forget].
 */
@OptIn(ExperimentalTime::class)
class ContributeDrafts(
    private val storage: DraftStorage,
    private val now: () -> Long = { Clock.System.now().toEpochMilliseconds() },
) {
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = false }
    private var userId: String? = null
    private var index: List<WaitingContribution> = readIndex()

    private val _waiting = MutableStateFlow<WaitingContribution?>(null)
    /** The banner: the signed-in user's most recent unfinished contribution, if it's fresh enough. */
    val waiting: StateFlow<WaitingContribution?> = _waiting.asStateFlow()

    /** Called by [app.rollspot.shared.RollspotSdk] whenever the signed-in user changes. */
    fun setUser(userId: String?) {
        this.userId = userId
        publish()
    }

    /** Remembers (or refreshes) that the signed-in user is part-way through reviewing [placeId]. */
    fun remember(placeId: String, placeName: String) {
        val user = userId ?: return
        index = index.filterNot { it.userId == user && it.placeId == placeId } +
            WaitingContribution(placeId, placeName.ifBlank { "This place" }, user, now())
        writeIndex()
        publish()
    }

    /** The contribution was submitted or discarded: drop it and its photos. */
    fun forget(placeId: String) {
        val user = userId ?: return
        index = index.filterNot { it.userId == user && it.placeId == placeId }
        storage.deleteFolder(folder(user, placeId))
        writeIndex()
        publish()
    }

    fun isWaiting(placeId: String): Boolean = userId?.let { user -> index.any { it.userId == user && it.placeId == placeId } } ?: false

    /** Saves the whole flow (answers + photo bytes) so it survives the app closing. Skips a flow with no answers yet. */
    fun saveFlow(state: ContributeFlowState, hasProgress: Boolean) {
        val user = userId ?: return
        if (!hasProgress) return
        val dir = folder(user, state.placeId)
        val photos = mutableListOf<LocalReviewPhoto>()
        mapPhotos(state) { photo -> photos += photo; photo }
        val names = photos.map { it.fileId }.toSet()
        val written = knownPhotos[dir].orEmpty()
        // Photo files never change once written (an edit is a new file id), so only new ones are written.
        for (photo in photos) {
            if (photo.fileId !in written && photo.jpeg.isNotEmpty()) storage.write("$dir/${photo.fileId}.jpg", photo.jpeg)
        }
        storage.write("$dir/$STATE_FILE", json.encodeToString(ContributeFlowState.serializer(), state.copy(showExitConfirmation = false)).encodeToByteArray())
        // Photos removed since the last save.
        knownPhotos[dir]?.filterNot { it in names }?.forEach { storage.write("$dir/$it.jpg", null) }
        knownPhotos[dir] = names
        remember(state.placeId, state.placeName)
    }

    /** The saved flow for [placeId] with its photos read back, or null when there's none (or it can't be read). */
    fun restoreFlow(placeId: String): ContributeFlowState? {
        val user = userId ?: return null
        val dir = folder(user, placeId)
        val text = storage.read("$dir/$STATE_FILE")?.decodeToString() ?: return null
        val saved = runCatching { json.decodeFromString(ContributeFlowState.serializer(), text) }.getOrNull() ?: return null
        val names = mutableSetOf<String>()
        val restored = mapPhotos(saved) { photo ->
            names += photo.fileId
            photo.copy(jpeg = storage.read("$dir/${photo.fileId}.jpg") ?: ByteArray(0))
        }
        knownPhotos[dir] = names
        return restored
    }

    private val knownPhotos = mutableMapOf<String, Set<String>>()

    private fun publish() {
        val user = userId
        val oldest = now() - MAX_AGE_MILLIS
        _waiting.value = if (user == null) null else index.filter { it.userId == user && it.updatedAtMillis >= oldest }.maxByOrNull { it.updatedAtMillis }
    }

    private fun readIndex(): List<WaitingContribution> =
        storage.read(INDEX_FILE)?.decodeToString()?.let { text ->
            runCatching { json.decodeFromString(ListSerializer(WaitingContribution.serializer()), text) }.getOrNull()
        } ?: emptyList()

    private fun writeIndex() {
        storage.write(INDEX_FILE, json.encodeToString(ListSerializer(WaitingContribution.serializer()), index).encodeToByteArray())
    }

    private fun folder(user: String, placeId: String) = "contributions/${safe(user)}/${safe(placeId)}"

    private fun safe(value: String) = value.map { if (it.isLetterOrDigit() || it == '-' || it == '_') it else '_' }.joinToString("")

    companion object {
        private const val INDEX_FILE = "contributions/index.json"
        private const val STATE_FILE = "flow.json"
        /** Older drafts stop showing on Home (they still resume from the place page). */
        const val MAX_AGE_MILLIS = 30L * 24 * 60 * 60 * 1000
    }
}

/** Every photo in a flow state, transformed by [transform] (used to strip and restore bytes). */
internal fun mapPhotos(state: ContributeFlowState, transform: (LocalReviewPhoto) -> LocalReviewPhoto): ContributeFlowState {
    fun list(photos: List<LocalReviewPhoto>) = photos.map(transform)
    fun evidence(map: Map<String, List<LocalReviewPhoto>>) = map.mapValues { (_, photos) -> list(photos) }
    return state.copy(
        supplementalNotes = state.supplementalNotes.mapValues { (_, notes) -> notes.copy(photos = list(notes.photos)) },
        entrancePhotos = list(state.entrancePhotos),
        completedEntrancePasses = state.completedEntrancePasses.map {
            it.copy(photos = list(it.photos), lobbyEvidence = evidence(it.lobbyEvidence), basementEvidence = evidence(it.basementEvidence))
        },
        completedElevatorPasses = state.completedElevatorPasses.map { it.copy(photos = list(it.photos), evidence = evidence(it.evidence)) },
        completedToiletPasses = state.completedToiletPasses.map { it.copy(photos = list(it.photos), evidence = evidence(it.evidence)) },
        toiletPhotos = list(state.toiletPhotos),
        toiletEvidence = evidence(state.toiletEvidence),
        lobbyEvidence = evidence(state.lobbyEvidence),
        basementEvidence = evidence(state.basementEvidence),
        elevatorPhotos = list(state.elevatorPhotos),
        elevatorEvidence = evidence(state.elevatorEvidence),
        seatingPhotos = list(state.seatingPhotos),
        parkingPhotos = list(state.parkingPhotos),
    )
}
