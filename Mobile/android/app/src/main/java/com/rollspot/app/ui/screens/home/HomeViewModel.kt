package com.rollspot.app.ui.screens.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.rollspot.shared.RollspotSdk
import app.rollspot.shared.map.MapModel
import app.rollspot.shared.map.MapPin
import app.rollspot.shared.map.MapState
import app.rollspot.shared.places.OverallAccessibility
import kotlinx.coroutines.flow.StateFlow

/** The shared MapModel does the work; this only ties its lifetime to the screen. */
class HomeViewModel(sdk: RollspotSdk) : ViewModel() {
    private val model = MapModel(sdk.placeSearch, viewModelScope)

    val state: StateFlow<MapState> = model.state

    fun onRegionChanged(lat: Double, lng: Double, radiusMeters: Int) = model.onRegionChanged(lat, lng, radiusMeters)
    fun onQueryChanged(query: String) = model.onQueryChanged(query)
    fun clearQuery() = model.clearQuery()
    fun setGradeFilter(grade: OverallAccessibility) = model.setGradeFilter(grade)
    fun select(pin: MapPin) = model.select(pin)
    fun retry() = model.refresh()
}
