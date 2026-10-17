package com.rollspot.app.ui.screens.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.rollspot.shared.RollspotSdk
import app.rollspot.shared.api.Place
import com.rollspot.app.BuildConfig
import com.rollspot.app.data.MockPlaces
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class HomeUiState(
    val centerLat: Double = BALI_LAT,
    val centerLng: Double = BALI_LNG,
    val nearby: List<Place> = emptyList(),
    val query: String = "",
    val results: List<Place> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null,
) {
    val visiblePlaces: List<Place> get() = if (query.isBlank()) nearby else results

    companion object {
        const val BALI_LAT = -8.7200
        const val BALI_LNG = 115.1700
    }
}

// TODO(F2 #33): replace with the shared MapModel; this is the minimum to exercise the shared API.
class HomeViewModel(private val sdk: RollspotSdk) : ViewModel() {
    private val _state = MutableStateFlow(HomeUiState())
    val state: StateFlow<HomeUiState> = _state.asStateFlow()
    private var searchJob: Job? = null

    init {
        loadNearby(HomeUiState.BALI_LAT, HomeUiState.BALI_LNG)
    }

    fun loadNearby(lat: Double, lng: Double) {
        _state.update { it.copy(centerLat = lat, centerLng = lng, isLoading = true, error = null) }
        viewModelScope.launch {
            try {
                val places = sdk.places.nearby(lat, lng)
                _state.update { it.copy(nearby = places, isLoading = false, error = null) }
            } catch (error: Exception) {
                val fallback = debugMockPlaces("")
                _state.update {
                    it.copy(
                        nearby = fallback,
                        isLoading = false,
                        error = if (fallback.isEmpty()) error.message else null,
                    )
                }
            }
        }
    }

    fun onQueryChange(query: String) {
        _state.update { it.copy(query = query) }
        searchJob?.cancel()
        if (query.isBlank()) {
            _state.update { it.copy(results = emptyList(), error = null, isLoading = false) }
            return
        }
        if (isPark23Query(query)) {
            _state.update {
                it.copy(results = listOfNotNull(MockPlaces.find(MockPlaces.PARK23_ID)), isLoading = false, error = null)
            }
            return
        }
        searchJob = viewModelScope.launch {
            delay(300)
            val current = _state.value
            val mocks = debugMockPlaces(query)
            try {
                val api = sdk.places.search(query, current.centerLat, current.centerLng)
                _state.update { it.copy(results = mergePlaces(mocks, api), error = null) }
            } catch (error: Exception) {
                _state.update {
                    it.copy(
                        results = mocks,
                        error = if (mocks.isEmpty()) error.message else null,
                    )
                }
            }
        }
    }

    private fun isPark23Query(query: String): Boolean =
        query.lowercase().filter { it.isLetterOrDigit() }.contains("park23")

    private fun debugMockPlaces(query: String): List<Place> =
        if (!BuildConfig.DEBUG) emptyList() else MockPlaces.filter(query)

    private fun mergePlaces(mocks: List<Place>, api: List<Place>): List<Place> {
        if (mocks.isEmpty()) return api
        val seen = mocks.map { it.id }.toMutableSet()
        return mocks + api.filter { it.id !in seen }
    }
}
