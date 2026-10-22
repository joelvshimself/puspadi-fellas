package com.rollspot.app.ui

import androidx.compose.runtime.Composable
import app.rollspot.shared.auth.AuthStep
import com.rollspot.app.BuildConfig
import com.rollspot.app.ui.screens.auth.AuthFlowScreen
import com.rollspot.app.ui.screens.auth.AuthPreview
import com.rollspot.app.ui.screens.splash.SplashScreen

/**
 * Debug-only design review: `adb shell am start ... --es designReview <screen>` opens one screen in
 * a fixed state for side-by-side comparison with iOS (`-designReview <screen>`) and the Figma frames.
 * Screen names match iOS App/DesignReview/DesignReview.swift.
 */
object DesignReview {
    const val EXTRA = "designReview"
    private const val EMAIL = "name@gmail.com"

    fun isEnabled(screen: String?) = BuildConfig.DEBUG && !screen.isNullOrBlank()

    fun authPreview(screen: String): AuthPreview? = when (screen) {
        "welcome" -> AuthPreview()
        "emailFound" -> AuthPreview(listOf(AuthStep.Welcome, AuthStep.EmailFound(EMAIL)))
        "emailFoundFilled" -> AuthPreview(listOf(AuthStep.Welcome, AuthStep.EmailFound(EMAIL)), password = "password123")
        "emailFoundError" -> AuthPreview(
            listOf(AuthStep.Welcome, AuthStep.EmailFound(EMAIL)), password = "password123", error = "Incorrect password. Try again.",
        )
        "createPassword" -> AuthPreview(listOf(AuthStep.Welcome, AuthStep.CreatePassword(EMAIL)))
        "name" -> AuthPreview(listOf(AuthStep.Welcome, AuthStep.CreatePassword(EMAIL), AuthStep.Name("")))
        "mobility" -> AuthPreview(listOf(AuthStep.Welcome, AuthStep.CreatePassword(EMAIL), AuthStep.Name(""), AuthStep.Mobility))
        "mobilityFilled" -> AuthPreview(
            listOf(AuthStep.Welcome, AuthStep.CreatePassword(EMAIL), AuthStep.Name(""), AuthStep.Mobility), aids = listOf("Wheelchair"),
        )
        "allSet" -> AuthPreview(listOf(AuthStep.AllSet))
        else -> null
    }
}

@Composable
fun DesignReviewRoot(screen: String) {
    when (screen) {
        "splash" -> SplashScreen()
        "home", "homeFilter", "homeFilterChosen", "homeSearch", "homeSearchQuery" -> RollspotApp(review = screen)
        else -> DesignReview.authPreview(screen)?.let { AuthFlowScreen(onDone = {}, onCancel = {}, preview = it) }
    }
}
