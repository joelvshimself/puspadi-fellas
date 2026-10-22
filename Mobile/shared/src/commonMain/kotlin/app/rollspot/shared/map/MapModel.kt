package app.rollspot.shared.map

import app.rollspot.shared.api.Place
import app.rollspot.shared.places.OverallAccessibility
import app.rollspot.shared.places.PlaceRepository
import app.rollspot.shared.places.distanceMeters
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.roundToInt

data class MapState(
    val centerLat: Double = BALI_LAT,
    val centerLng: Double = BALI_LNG,
    val radiusMeters: Int = PlaceRepository.DEFAULT_RADIUS_METERS,
    /** Every place loaded for the visible region, nearest first. Feeds the "Nearby" list. */
    val pins: List<MapPin> = emptyList(),
    /** The grade the map is filtered to. The design shows no pins until one is chosen. */
    val gradeFilter: OverallAccessibility? = null,
    /** True while the filter is widening the search area to find a match. */
    val isWidening: Boolean = false,
    /** Set when the camera should move (after widening); [MapFocus.nonce] changes on each request. */
    val focus: MapFocus? = null,
    val query: String = "",
    /** Only meaningful while [isSearchActive]. */
    val results: List<MapPin> = emptyList(),
    /** Places the user opened from the map or search, newest first (the clock rows in the design). */
    val recentPlaces: List<Place> = emptyList(),
    val selected: MapPin? = null,
    val isLoading: Boolean = false,
    /** True once a nearby request has finished, even with zero places: lets views show "nothing here" instead of a spinner. */
    val hasLoaded: Boolean = false,
    val isSearching: Boolean = false,
    val error: String? = null,
) {
    val isSearchActive: Boolean get() = query.trim().length >= PlaceRepository.MIN_QUERY_LENGTH

    /** [recentPlaces] with distance from the map center. */
    val recentPins: List<MapPin> get() = recentPlaces.map { pinFor(it, centerLat, centerLng) }

    /** Recent places whose name contains the query: shown first while typing. */
    val matchingRecents: List<MapPin>
        get() {
            val needle = query.trim()
            return if (needle.length < PlaceRepository.MIN_QUERY_LENGTH) emptyList()
            else recentPins.filter { it.place.name.contains(needle, ignoreCase = true) }
        }

    /** [results] without the places already listed as recents. */
    val freshResults: List<MapPin> get() = results.filterNot { r -> matchingRecents.any { it.id == r.id } }

    /** What the map draws: nothing by default, only places with the chosen grade once filtered. */
    val visiblePins: List<MapPin> get() = gradeFilter?.let { grade -> pins.filter { it.grade == grade } } ?: emptyList()

    companion object {
        const val BALI_LAT = -8.7200
        const val BALI_LNG = 115.1700
    }
}

/** Where the camera should go, e.g. after the filter widened the search area. */
data class MapFocus(val lat: Double, val lng: Double, val radiusMeters: Int, val nonce: Int)

/**
 * Everything the home map does that isn't drawing: which places the visible
 * region shows, search, recent places and the selection. The apps tell it
 * where the camera is and what was typed or tapped; they render [state].
 *
 * Panning fires many region changes per second. They're debounced, small moves
 * are ignored, and a newer request cancels an older one, so the API sees at most
 * one `nearby` call per settled camera position.
 */
class MapModel(
    private val provider: PlaceSearchProvider,
    private val scope: CoroutineScope,
    private val regionDebounceMs: Long,
    private val searchDebounceMs: Long,
) {
    /** For iOS, which has no lifecycle scope to hand in. Call [dispose] when the screen goes away. */
    constructor(provider: PlaceSearchProvider) : this(
        provider,
        CoroutineScope(SupervisorJob() + Dispatchers.Main),
        REGION_DEBOUNCE_MS,
        SEARCH_DEBOUNCE_MS,
    )

    /** For Android: pass `viewModelScope`. */
    constructor(provider: PlaceSearchProvider, scope: CoroutineScope) : this(
        provider,
        scope,
        REGION_DEBOUNCE_MS,
        SEARCH_DEBOUNCE_MS,
    )

    private val _state = MutableStateFlow(MapState())
    val state: StateFlow<MapState> = _state.asStateFlow()

    private var regionJob: Job? = null
    private var searchJob: Job? = null
    private var filterJob: Job? = null
    private var loaded: Triple<Double, Double, Int>? = null

    /**
     * The camera stopped at ([lat], [lng]) showing [latitudeDelta] × [longitudeDelta] degrees.
     * Both apps call this so they ask for exactly the same area from the same camera.
     */
    fun onViewportChanged(lat: Double, lng: Double, latitudeDelta: Double, longitudeDelta: Double) =
        onRegionChanged(lat, lng, viewportRadiusMeters(lat, latitudeDelta, longitudeDelta))

    /** The camera stopped at ([lat], [lng]) showing roughly [radiusMeters] around it. */
    fun onRegionChanged(lat: Double, lng: Double, radiusMeters: Int) {
        // The filter is moving the camera itself and loads its own places.
        if (_state.value.isWidening) return
        val radius = radiusMeters.coerceIn(MIN_RADIUS_METERS, MAX_RADIUS_METERS)
        _state.update { it.copy(centerLat = lat, centerLng = lng, radiusMeters = radius) }
        regionJob?.cancel()
        if (!needsReload(lat, lng, radius)) {
            _state.update { it.copy(isLoading = false) }
            return
        }
        regionJob = scope.launch {
            delay(regionDebounceMs)
            _state.update { it.copy(isLoading = true, error = null) }
            try {
                val places = provider.nearby(lat, lng, radius)
                loaded = Triple(lat, lng, radius)
                _state.update { it.copy(pins = toPins(places, lat, lng), isLoading = false, hasLoaded = true) }
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (error: Exception) {
                _state.update { it.copy(isLoading = false, hasLoaded = true, error = error.message ?: "Couldn't load places") }
            }
        }
    }

    /**
     * Filters the map to [grade]; choosing the active grade again clears it.
     * If nothing in view has that grade, the search area doubles (up to
     * [MAX_FILTER_STEPS] times, capped at [MAX_RADIUS_METERS]) until something does,
     * then [MapState.focus] asks the view to move there. If nothing is found the
     * map stays where it was.
     */
    fun setGradeFilter(grade: OverallAccessibility) {
        filterJob?.cancel()
        val current = _state.value
        if (current.gradeFilter == grade) {
            _state.update { it.copy(gradeFilter = null, isWidening = false) }
            return
        }
        _state.update { it.copy(gradeFilter = grade, isWidening = false) }
        if (current.pins.any { it.grade == grade }) return
        regionJob?.cancel()
        // The cancelled region load can't clear its own spinner.
        _state.update { it.copy(isLoading = false) }
        filterJob = scope.launch {
            _state.update { it.copy(isWidening = true, error = null) }
            try {
                var radius = current.radiusMeters
                repeat(MAX_FILTER_STEPS) {
                    if (radius >= MAX_RADIUS_METERS) return@repeat
                    radius = (radius * 2).coerceAtMost(MAX_RADIUS_METERS)
                    val pins = toPins(provider.nearby(current.centerLat, current.centerLng, radius), current.centerLat, current.centerLng)
                    if (pins.any { it.grade == grade }) {
                        loaded = Triple(current.centerLat, current.centerLng, radius)
                        _state.update {
                            it.copy(
                                pins = pins,
                                radiusMeters = radius,
                                focus = MapFocus(current.centerLat, current.centerLng, radius, (it.focus?.nonce ?: 0) + 1),
                            )
                        }
                        return@launch
                    }
                }
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (error: Exception) {
                _state.update { it.copy(error = error.message ?: "Couldn't load places") }
            } finally {
                _state.update { it.copy(isWidening = false) }
            }
        }
    }

    /** Reloads the visible region even if the camera hasn't moved, e.g. after returning from a place page. */
    fun refresh() {
        loaded = null
        val current = _state.value
        onRegionChanged(current.centerLat, current.centerLng, current.radiusMeters)
    }

    fun onQueryChanged(query: String) {
        searchJob?.cancel()
        _state.update { it.copy(query = query) }
        val trimmed = query.trim()
        if (trimmed.length < PlaceRepository.MIN_QUERY_LENGTH) {
            _state.update { it.copy(results = emptyList(), isSearching = false) }
            return
        }
        // Spinner from the first keystroke, so the debounce gap doesn't flash "no results".
        _state.update { it.copy(isSearching = true, error = null) }
        searchJob = scope.launch {
            delay(searchDebounceMs)
            val center = _state.value
            try {
                val places = provider.search(trimmed, center.centerLat, center.centerLng)
                _state.update { it.copy(results = toPins(places, center.centerLat, center.centerLng), isSearching = false) }
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (error: Exception) {
                _state.update { it.copy(results = emptyList(), isSearching = false, error = error.message ?: "Search failed") }
            }
        }
    }

    /** Picks a place from the map or the results. Remembers the query that led to it. */
    fun select(pin: MapPin) {
        _state.update { it.copy(selected = pin, recentPlaces = it.recentPlaces.withRecent(pin.place)) }
    }

    /** A place page was opened from anywhere (list, deep link, saved): remember it in the recents. */
    fun open(place: Place) {
        _state.update { it.copy(recentPlaces = it.recentPlaces.withRecent(place)) }
    }

    /** Same as [select] for a place the app knows only by ID (e.g. tapped from its own list). Unknown IDs are ignored. */
    fun select(placeId: String) {
        val state = _state.value
        (state.pins + state.results + state.recentPins).firstOrNull { it.id == placeId }?.let(::select)
    }

    fun clearSelection() {
        _state.update { it.copy(selected = null) }
    }

    fun clearQuery() = onQueryChanged("")

    fun clearRecentPlaces() {
        _state.update { it.copy(recentPlaces = emptyList()) }
    }

    fun clearError() {
        _state.update { it.copy(error = null) }
    }

    fun dispose() {
        scope.cancel()
    }

    private fun needsReload(lat: Double, lng: Double, radius: Int): Boolean {
        val last = loaded ?: return true
        val moved = distanceMeters(last.first, last.second, lat, lng)
        val scale = radius.toDouble() / last.third
        return moved > last.third * RELOAD_MOVE_FRACTION || scale !in 1 / RELOAD_ZOOM_FACTOR..RELOAD_ZOOM_FACTOR
    }

    companion object {
        const val REGION_DEBOUNCE_MS = 400L
        const val SEARCH_DEBOUNCE_MS = 300L
        const val MIN_RADIUS_METERS = 500
        const val MAX_RADIUS_METERS = 20_000
        const val MAX_RECENT_PLACES = 5
        const val MAX_FILTER_STEPS = 4

        /** Moving less than this share of the radius keeps the pins we have. */
        const val RELOAD_MOVE_FRACTION = 0.25

        /** Zooming by less than this factor keeps the pins we have. */
        const val RELOAD_ZOOM_FACTOR = 1.25
    }
}

/** Newest first, one entry per place, capped. */
internal fun List<Place>.withRecent(place: Place): List<Place> =
    (listOf(place) + filterNot { it.id == place.id }).take(MapModel.MAX_RECENT_PLACES)

/**
 * Search radius for a visible map area: half its larger side in meters, with the
 * east-west side shrunk by latitude. One formula, so iOS and Android request the
 * same places from the same camera.
 */
fun viewportRadiusMeters(centerLat: Double, latitudeDelta: Double, longitudeDelta: Double): Int {
    val metersPerDegree = 111_320.0
    val north = latitudeDelta * metersPerDegree
    val east = longitudeDelta * metersPerDegree * cos(centerLat * PI / 180)
    return (maxOf(north, east) / 2).roundToInt()
        .coerceIn(MapModel.MIN_RADIUS_METERS, MapModel.MAX_RADIUS_METERS)
}
