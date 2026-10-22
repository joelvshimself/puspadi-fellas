package com.rollspot.app.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import app.rollspot.shared.auth.AuthStep
import com.rollspot.app.BuildConfig
import com.rollspot.app.ui.screens.auth.AuthFlowScreen
import com.rollspot.app.ui.screens.auth.AuthPreview
import com.rollspot.app.ui.screens.profile.MyAccountScreen
import com.rollspot.app.ui.screens.profile.ProfileScreen
import com.rollspot.app.ui.screens.profile.ProfileTab
import com.rollspot.app.ui.screens.review.EditResponseScreen
import com.rollspot.app.ui.screens.splash.SplashScreen

/**
 * Debug-only design review: `adb shell am start ... --es designReview <screen>` opens one screen in
 * a fixed state for side-by-side comparison with iOS (`-designReview <screen>`) and the Figma frames.
 * Screen names match iOS App/DesignReview/DesignReview.swift.
 */
object DesignReview {
    const val EXTRA = "designReview"
    /** Signed-in screens: a local test account, passed as extras so it's never committed. */
    const val EMAIL_EXTRA = "designReviewEmail"
    const val PASSWORD_EXTRA = "designReviewPassword"
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
fun DesignReviewRoot(screen: String, email: String? = null, password: String? = null) {
    when (screen) {
        "splash" -> SplashScreen()
        "home", "homeFilter", "homeFilterChosen", "homeSearch", "homeSearchQuery" -> RollspotApp(review = screen)
        "profile", "profileDeleteReview", "profilePhotos", "profileSettings", "profileLanguage" -> SignedIn(email, password) {
            val tab = when (screen) {
                "profilePhotos" -> ProfileTab.Photos
                "profileSettings", "profileLanguage" -> ProfileTab.Settings
                else -> ProfileTab.Reviews
            }
            ProfileScreen({}, {}, {}, {}, {}, initialTab = tab, review = screen)
        }
        "editResponse", "editResponseLeave" -> SignedIn(email, password) {
            val mine = rollspotSdk().myReviews
            var reviewId by remember { mutableStateOf<String?>(null) }
            LaunchedEffect(Unit) {
                runCatching { mine.load() }
                reviewId = mine.state.value.reviews.firstOrNull { it.editable }?.id
            }
            reviewId?.let { EditResponseScreen(it, onClose = {}, onSaved = {}, review = screen) }
        }
        "myAccount", "mobilityProfile", "deleteAccount", "accountDeleted" -> SignedIn(email, password) {
            MyAccountScreen(onBack = {}, onAccountDeleted = {}, review = screen)
        }
        else -> DesignReview.authPreview(screen)?.let { AuthFlowScreen(onDone = {}, onCancel = {}, preview = it) }
    }
}

/** Signs in with the account from the launch extras, then shows the screen. */
@Composable
private fun SignedIn(email: String?, password: String?, content: @Composable () -> Unit) {
    val auth = rollspotSdk().auth
    var ready by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        if (!auth.isSignedIn && email != null && password != null) runCatching { auth.signIn(email, password) }
        ready = true
    }
    if (ready) content()
}
