package com.rollspot.app.ui.screens.place

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.rollspot.shared.RollspotSdk
import app.rollspot.shared.api.Place
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class PlaceDetailUiState(val place: Place? = null, val isLoading: Boolean = true, val error: String? = null)

// TODO(F3 #34): replace with the shared PlaceDetailModel (reviews, photos, notes).
class PlaceDetailViewModel(private val sdk: RollspotSdk, private val placeKey: String) : ViewModel() {
    private val _state = MutableStateFlow(PlaceDetailUiState())
    val state: StateFlow<PlaceDetailUiState> = _state.asStateFlow()

    init {
        viewModelScope.launch {
            _state.value = try {
                PlaceDetailUiState(place = sdk.places.place(placeKey), isLoading = false)
            } catch (error: Exception) {
                PlaceDetailUiState(isLoading = false, error = error.message)
            }
        }
    }
}
