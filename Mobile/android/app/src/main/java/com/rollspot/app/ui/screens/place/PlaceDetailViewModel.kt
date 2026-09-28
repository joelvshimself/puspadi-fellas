package com.rollspot.app.ui.screens.place

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.rollspot.app.data.models.AccessibilityFeatureGrade
import com.rollspot.app.data.models.OverallAccessibility
import com.rollspot.app.data.models.Place
import com.rollspot.app.data.models.collapseAccessibility
import com.rollspot.app.data.services.AccessibilityService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class PlaceDetailUiState(
    val place: Place? = null,
    val grade: OverallAccessibility? = null,
    val accessibilityFeatures: List<AccessibilityFeatureGrade> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null
)

class PlaceDetailViewModel : ViewModel() {
    
    private val _uiState = MutableStateFlow(PlaceDetailUiState())
    val uiState: StateFlow<PlaceDetailUiState> = _uiState.asStateFlow()
    
    private val accessibilityService = AccessibilityService.shared
    
    fun loadPlace(placeId: String) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            
            // TODO: Load actual place data from cache or API
            // For now, we'll create a placeholder and load accessibility data
            
            // Mock place data based on placeId
            val mockPlace = Place(
                id = placeId,
                name = "Loading...",
                category = "Place",
                coordinate = com.google.android.gms.maps.model.LatLng(-8.7200, 115.2000)
            )
            
            _uiState.update { 
                it.copy(
                    place = mockPlace,
                    isLoading = false
                )
            }
            
            // Load accessibility grade
            loadAccessibilityGrade(mockPlace)
        }
    }
    
    private fun loadAccessibilityGrade(place: Place) {
        viewModelScope.launch {
            try {
                val result = accessibilityService.enrich(
                    lat = place.coordinate.latitude,
                    lng = place.coordinate.longitude,
                    name = place.name,
                    userInitiated = true
                )
                
                result.onSuccess { response ->
                    val features = response.grade ?: emptyList()
                    val grade = collapseAccessibility(features)
                    
                    _uiState.update { 
                        it.copy(
                            grade = grade,
                            accessibilityFeatures = features
                        )
                    }
                }
            } catch (e: Exception) {
                _uiState.update { 
                    it.copy(error = e.message)
                }
            }
        }
    }
}
