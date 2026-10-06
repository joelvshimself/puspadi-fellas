package com.rollspot.app.ui

import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext
import app.rollspot.shared.RollspotSdk
import com.rollspot.app.RollspotApplication

@Composable
fun rollspotSdk(): RollspotSdk = (LocalContext.current.applicationContext as RollspotApplication).sdk
