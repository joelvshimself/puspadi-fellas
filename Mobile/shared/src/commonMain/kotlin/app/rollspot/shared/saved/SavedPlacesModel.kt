package app.rollspot.shared.saved

import app.rollspot.shared.api.ApiException
import app.rollspot.shared.api.Place
import app.rollspot.shared.api.RollspotApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

data class SavedPlacesState(
    /** A–Z by name, as the Saved list shows them. */
    val places: List<Place> = emptyList(),
    val isLoading: Boolean = false,
    val hasLoaded: Boolean = false,
    /** Places whose save/unsave request is in flight. */
    val pending: Set<String> = emptySet(),
    val error: String? = null,
) {
    val placeIds: Set<String> get() = places.map { it.id }.toSet()
    fun isSaved(placeId: String): Boolean = places.any { it.id == placeId }
}

sealed interface SaveOutcome {
    data object Saved : SaveOutcome
    data object Removed : SaveOutcome
    data object NeedsSignIn : SaveOutcome
    data class Failed(val message: String) : SaveOutcome
}

/**
 * Saved places for the signed-in user. The bookmark on a place page flips at once;
 * if the server refuses, it flips back. One request per place at a time.
 */
class SavedPlacesModel(private val api: RollspotApi, private val isSignedIn: () -> Boolean) {
    private val _state = MutableStateFlow(SavedPlacesState())
    val state: StateFlow<SavedPlacesState> = _state.asStateFlow()

    fun isSaved(placeId: String): Boolean = _state.value.isSaved(placeId)

    @Throws(Exception::class)
    suspend fun load() {
        if (!isSignedIn()) {
            clear()
            return
        }
        _state.update { it.copy(isLoading = true, error = null) }
        try {
            val saved = api.savedPlaces()
            // Keep optimistic changes still in flight instead of overwriting them with older server state.
            _state.update { current ->
                val pendingPlaces = current.places.filter { it.id in current.pending }
                val serverPlaces = saved.places.filterNot { it.id in current.pending }
                current.copy(places = sortByName(serverPlaces + pendingPlaces), isLoading = false, hasLoaded = true)
            }
        } catch (error: ApiException) {
            _state.update { it.copy(isLoading = false, hasLoaded = true, error = error.message) }
            throw error
        }
    }

    /** Saves [place] if it isn't saved yet, otherwise removes it. */
    suspend fun toggle(place: Place): SaveOutcome {
        if (!isSignedIn()) return SaveOutcome.NeedsSignIn
        val before = _state.value
        if (place.id in before.pending) return SaveOutcome.Failed("This place is already being updated.")
        val removing = before.isSaved(place.id)
        _state.update {
            it.copy(
                pending = it.pending + place.id,
                error = null,
                places = if (removing) it.places.filterNot { saved -> saved.id == place.id } else sortByName(it.places + place),
            )
        }
        return try {
            if (removing) api.unsavePlace(place.id) else api.savePlace(place.id)
            _state.update { it.copy(pending = it.pending - place.id) }
            if (removing) SaveOutcome.Removed else SaveOutcome.Saved
        } catch (error: ApiException) {
            _state.update {
                it.copy(
                    pending = it.pending - place.id,
                    error = error.message,
                    places = if (removing) sortByName(it.places + place) else it.places.filterNot { saved -> saved.id == place.id },
                )
            }
            SaveOutcome.Failed(error.message)
        }
    }

    fun clear() {
        _state.value = SavedPlacesState()
    }

    private fun sortByName(places: List<Place>) = places.distinctBy { it.id }.sortedBy { it.name.lowercase() }
}
