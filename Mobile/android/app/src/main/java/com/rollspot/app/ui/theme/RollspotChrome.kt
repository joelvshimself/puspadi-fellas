package com.rollspot.app.ui.theme

import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rollspot.app.R
import dev.chrisbanes.haze.HazeState
import dev.chrisbanes.haze.HazeStyle
import dev.chrisbanes.haze.HazeTint
import dev.chrisbanes.haze.hazeEffect

/**
 * Rollspot's visual language on Android. Every value mirrors the iOS app
 * (Views/Auth/AuthChrome.swift and friends) so both platforms look the same.
 */
object Rollspot {
    val BrandBlue = Color(0xFF007AFF)
    val FieldFill = Color(0xFFF0F0F0)
    val ErrorRed = Color(0xFFDB2E2E)
    val ErrorFill = Color(0xFFFFF0F0)
    val GradientTop = Color(0xFFB8E0FF)
    val Secondary = Color(0x993C3C43) // iOS .secondary label
    val Disabled = Color(0x59808080) // iOS Color.gray.opacity(0.35)

    // iOS Dynamic Type default sizes.
    val Title = TextStyle(fontSize = 28.sp, fontWeight = FontWeight.Bold, lineHeight = 34.sp)
    val Subheadline = TextStyle(fontSize = 15.sp, lineHeight = 20.sp)
    val Caption = TextStyle(fontSize = 12.sp, lineHeight = 16.sp)
    val Body = TextStyle(fontSize = 17.sp, lineHeight = 22.sp)

    /** CSS-style ease-out, as in the iOS press style. */
    val EaseOut = CubicBezierEasing(0f, 0f, 0.58f, 1f)
}

/** Light-blue fade at the top of sign-in and splash screens (iOS AuthGradientBackground). */
@Composable
fun GradientBackground(modifier: Modifier = Modifier) {
    Box(
        modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(Rollspot.GradientTop, Color.White, Color.White))),
    )
}

/**
 * Press feedback the moment a finger lands (not on release): 0.97 scale, 120ms ease-out.
 * Same values as iOS `PressableButtonStyle`. Skipped when animations are off.
 */
fun Modifier.pressScale(interaction: MutableInteractionSource): Modifier = composed {
    val pressed by interaction.collectIsPressedAsState()
    val animationsOn = remember { animationsEnabled() }
    val scale by animateFloatAsState(
        targetValue = if (pressed && animationsOn) 0.97f else 1f,
        animationSpec = tween(120, easing = Rollspot.EaseOut),
        label = "press",
    )
    graphicsLayer { scaleX = scale; scaleY = scale; alpha = if (pressed) 0.9f else 1f }
}

private fun animationsEnabled(): Boolean = android.animation.ValueAnimator.areAnimatorsEnabled()

@Composable
fun ContinueButton(
    title: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    loading: Boolean = false,
    onClick: () -> Unit,
) {
    val interaction = remember { MutableInteractionSource() }
    val active = enabled && !loading
    Row(
        modifier
            .fillMaxWidth()
            .height(52.dp)
            .pressScale(interaction)
            .clip(CircleShape)
            .background(if (active) Rollspot.BrandBlue else Rollspot.Disabled)
            .clickable(interactionSource = interaction, indication = null, enabled = active, onClick = onClick),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (loading) {
            CircularProgressIndicator(Modifier.size(18.dp), color = Color.White, strokeWidth = 2.dp)
            Spacer(Modifier.width(8.dp))
        }
        Text(title, style = Rollspot.Body.copy(fontWeight = FontWeight.Bold), color = Color.White)
    }
}

/** 52dp rounded field: grey fill, blue ring when focused, red ring + pink fill on error (iOS AuthFieldBox). */
@Composable
fun FieldBox(focused: Boolean, error: Boolean, modifier: Modifier = Modifier, content: @Composable RowScope.() -> Unit) {
    val shape = RoundedCornerShape(16.dp)
    Row(
        modifier
            .fillMaxWidth()
            .height(52.dp)
            .clip(shape)
            .background(if (error) Rollspot.ErrorFill else Rollspot.FieldFill)
            .then(
                when {
                    error -> Modifier.border(1.5.dp, Rollspot.ErrorRed, shape)
                    focused -> Modifier.border(1.5.dp, Rollspot.BrandBlue, shape)
                    else -> Modifier
                },
            )
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        content = content,
    )
}

/** 36dp translucent circle with a chevron (iOS AuthBackButton). */
@Composable
fun BackCircleButton(onClick: () -> Unit, modifier: Modifier = Modifier) {
    val interaction = remember { MutableInteractionSource() }
    Box(
        modifier
            .size(36.dp)
            .pressScale(interaction)
            .clip(CircleShape)
            .background(Color.White.copy(alpha = 0.7f))
            .clickable(interactionSource = interaction, indication = null, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, contentDescription = "Back", tint = Color.Black)
    }
}

/** 4dp capsule progress (iOS AuthProgressBar). */
@Composable
fun StepProgressBar(progress: Float, modifier: Modifier = Modifier) {
    BoxWithConstraints(modifier.fillMaxWidth().height(4.dp).clip(CircleShape).background(Color(0x26808080))) {
        Box(Modifier.width(maxOf(8.dp, maxWidth * progress)).fillMaxHeight().clip(CircleShape).background(Rollspot.BrandBlue))
    }
}

/** "Continue with Google": light outlined row with the four-colour G (same as iOS). */
@Composable
fun GoogleButton(enabled: Boolean, onClick: () -> Unit) {
    val interaction = remember { MutableInteractionSource() }
    val shape = RoundedCornerShape(16.dp)
    Row(
        Modifier
            .fillMaxWidth()
            .height(52.dp)
            .pressScale(interaction)
            .clip(shape)
            .background(Color.White)
            .border(BorderStroke(1.dp, Color.Black.copy(alpha = 0.18f)), shape)
            .clickable(interactionSource = interaction, indication = null, enabled = enabled, onClick = onClick),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Image(painterResource(R.drawable.ic_google_g), contentDescription = null, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(10.dp))
        Text("Continue with Google", style = Rollspot.Body.copy(fontWeight = FontWeight.SemiBold), color = Color.Black)
    }
}

/** The blurred backdrop glass surfaces read from. Screens with something behind glass provide one. */
val LocalHazeState = staticCompositionLocalOf<HazeState?> { null }

/**
 * Frosted glass, the Android stand-in for iOS Liquid Glass (`.glassEffect`): the content behind
 * is blurred and tinted white. Without a backdrop it falls back to translucent white.
 */
fun Modifier.glass(shape: Shape, tint: Float = 0.55f, blur: Dp = 24.dp): Modifier = composed {
    val haze = LocalHazeState.current
    val base = this.clip(shape)
    val surface = if (haze != null) {
        base.hazeEffect(
            state = haze,
            style = HazeStyle(
                backgroundColor = Color.White,
                tints = listOf(HazeTint(Color.White.copy(alpha = tint))),
                blurRadius = blur,
                noiseFactor = 0f,
            ),
        )
    } else {
        base.background(Color.White.copy(alpha = 0.92f))
    }
    surface.border(BorderStroke(0.5.dp, Color.White.copy(alpha = 0.6f)), shape)
}
