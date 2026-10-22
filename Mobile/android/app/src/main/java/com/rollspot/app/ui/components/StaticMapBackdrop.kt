package com.rollspot.app.ui.components

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier

/** A non-interactive Bali map behind cards like "You're all set!" (iOS uses a disabled Map). */
@Composable
fun StaticMapBackdrop(modifier: Modifier = Modifier) {
    Box(modifier) {
        PinMap(
            pins = emptyList(),
            hasLocationPermission = false,
            initialLat = -8.7200,
            initialLng = 115.2000,
            cameraTarget = null,
            onCameraIdle = { _, _, _ -> },
            onPinClick = {},
            modifier = Modifier.fillMaxSize(),
        )
        // Swallow touches so the backdrop can't be panned.
        Box(Modifier.fillMaxSize().clickable(remember { MutableInteractionSource() }, indication = null) {})
    }
}
