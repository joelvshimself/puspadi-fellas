package com.rollspot.app.ui.screens.place

import androidx.lifecycle.ViewModel
import app.rollspot.shared.RollspotSdk
import app.rollspot.shared.place.PlaceDetailState
import kotlinx.coroutines.flow.StateFlow

/**
 * Thin holder for the shared [app.rollspot.shared.place.PlaceDetailModel]: loading, review
 * mapping and the facility rules live in Mobile/shared so iOS shows the same data.
 */
class PlaceDetailViewModel(sdk: RollspotSdk, placeKey: String) : ViewModel() {
    private val model = sdk.placeDetailModel(placeKey)

    val state: StateFlow<PlaceDetailState> = model.state

    init {
        model.load()
    }

    fun retry() = model.refresh()

    // Lives in the view model because the screen leaves composition while another destination
    // (e.g. the review form) is on top; a remembered flag would reset and skip the reload.
    private var shownBefore = false

    /** Every return to the page after the first reloads it, so a just-submitted review shows. */
    fun onScreenResumed() {
        if (shownBefore) model.refresh() else shownBefore = true
    }

    override fun onCleared() {
        model.close()
    }
}
