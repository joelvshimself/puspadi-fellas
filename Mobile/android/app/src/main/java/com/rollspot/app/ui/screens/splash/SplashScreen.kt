package com.rollspot.app.ui.screens.splash

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rollspot.app.R
import com.rollspot.app.ui.theme.GradientBackground
import kotlinx.coroutines.delay

/** Launch screen, mirroring iOS SplashScreenView: the wheel turns once every 3s for 2s. */
@Composable
fun SplashScreen(onFinished: () -> Unit = {}) {
    val rotation by rememberInfiniteTransition(label = "splash").animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(tween(3_000, easing = LinearEasing), RepeatMode.Restart),
        label = "wheel",
    )
    LaunchedEffect(Unit) {
        delay(2_000)
        onFinished()
    }
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        GradientBackground()
        Image(
            painterResource(R.drawable.splash_wheel), contentDescription = null,
            modifier = Modifier.offset(y = (-75).dp).size(143.dp).rotate(rotation),
        )
        Image(
            painterResource(R.drawable.splash_base), contentDescription = null,
            modifier = Modifier.offset(y = (-16).dp).size(147.dp, 73.dp),
        )
        Text("RollSpot", fontSize = 40.sp, fontWeight = FontWeight.Bold, color = Color.Black, modifier = Modifier.offset(y = 60.dp))
    }
}
