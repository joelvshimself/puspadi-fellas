package com.rollspot.app.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.rollspot.app.ui.screens.home.HomeScreen
import com.rollspot.app.ui.screens.place.PlaceDetailScreen
import com.rollspot.app.ui.screens.contribute.ContributeFlowScreen
import com.rollspot.app.ui.screens.contribute.ContributePlaceSearchScreen
import com.rollspot.app.ui.screens.contribute.ContributeScreen
import com.rollspot.app.ui.screens.profile.AboutScreen
import com.rollspot.app.ui.screens.profile.MyAccountScreen
import com.rollspot.app.ui.screens.profile.NotificationsScreen
import com.rollspot.app.ui.screens.profile.ProfileScreen
import com.rollspot.app.ui.screens.profile.SavedPlacesScreen
import com.rollspot.app.ui.screens.review.EditResponseScreen
import com.rollspot.app.ui.screens.auth.AuthFlowScreen

@Composable
fun RollspotApp(review: String? = null) {
    val navController = rememberNavController()
    val sdk = rollspotSdk()
    val app = androidx.compose.ui.platform.LocalContext.current.applicationContext as com.rollspot.app.RollspotApplication
    val pendingPlace by app.pendingPlaceLink.collectAsState()
    LaunchedEffect(pendingPlace) {
        pendingPlace?.let {
            navController.navigate("place/$it")
            app.pendingPlaceLink.value = null
        }
    }
    
    NavHost(
        navController = navController,
        startDestination = "home"
    ) {
        composable("home") {
            HomeScreen(navController = navController, review = review)
        }
        
        composable(
            route = "place/{placeId}",
            arguments = listOf(
                navArgument("placeId") { type = NavType.StringType }
            )
        ) { backStackEntry ->
            val placeId = backStackEntry.arguments?.getString("placeId").orEmpty()
            PlaceDetailScreen(
                placeId = placeId,
                onNavigateBack = { navController.popBackStack() },
                // Like iOS: sign in first, then the form (never a sign-in prompt at Submit).
                onContribute = {
                    val flow = "contribute/flow/$placeId"
                    navController.navigate(if (sdk.isSignedIn()) flow else authRoute(next = flow))
                },
                onNeedsSignIn = { navController.navigate("auth") },
            )
        }

        composable("saved") {
            SavedPlacesScreen(
                onBack = { navController.popBackStack() },
                onOpenPlace = { navController.navigate("place/$it") },
            )
        }
        
        // Profile button: the account when signed in, otherwise the sign-in flow.
        composable("profile") {
            val auth = rollspotSdk().auth
            androidx.compose.runtime.LaunchedEffect(Unit) {
                navController.navigate(if (auth.isSignedIn) "me" else "auth") { popUpTo("profile") { inclusive = true } }
            }
        }

        // `next`: where to go once signed in ("back" returns to the screen that asked).
        composable(
            "auth?next={next}",
            arguments = listOf(navArgument("next") { type = NavType.StringType; nullable = true }),
        ) { entry ->
            val next = entry.arguments?.getString("next")
            AuthFlowScreen(
                onDone = {
                    when (next) {
                        null -> navController.navigate("me") { popUpTo("auth?next={next}") { inclusive = true } }
                        BACK -> navController.popBackStack()
                        else -> navController.navigate(next) { popUpTo("auth?next={next}") { inclusive = true } }
                    }
                },
                onCancel = { navController.popBackStack() },
            )
        }

        // Profile (F5): signed-in user's page, settings and account.
        composable("me") { entry ->
            val updated by entry.savedStateHandle.getStateFlow(REVIEW_UPDATED, false).collectAsStateWithLifecycle()
            ProfileScreen(
                onBack = { navController.popBackStack() },
                onOpenPlace = { navController.navigate("place/$it") },
                onOpenMyAccount = { navController.navigate("my-account") },
                onOpenAbout = { navController.navigate("about") },
                onSignedOut = { navController.popBackStack("home", inclusive = false) },
                onEditReview = { navController.navigate("review/$it/edit") },
                onResumeContribution = { navController.navigate("contribute/flow/$it") },
                onOpenNotifications = { navController.navigate("notifications") },
                reviewUpdated = updated,
                onUpdatedShown = { entry.savedStateHandle[REVIEW_UPDATED] = false },
            )
        }
        composable("review/{reviewId}/edit", arguments = listOf(navArgument("reviewId") { type = NavType.StringType })) { entry ->
            EditResponseScreen(
                reviewId = entry.arguments?.getString("reviewId").orEmpty(),
                onClose = { navController.popBackStack() },
                onSaved = {
                    navController.previousBackStackEntry?.savedStateHandle?.set(REVIEW_UPDATED, true)
                    navController.popBackStack()
                },
            )
        }
        composable("my-account") {
            MyAccountScreen(
                onBack = { navController.popBackStack() },
                onAccountDeleted = { navController.popBackStack("home", inclusive = false) },
            )
        }
        composable("about") {
            AboutScreen(onBack = { navController.popBackStack() })
        }
        composable("notifications") {
            NotificationsScreen(onBack = { navController.popBackStack() })
        }

        composable("contribute") {
            ContributeScreen(
                onNavigateBack = { navController.popBackStack() },
                onStartReview = { navController.navigate("contribute/search") },
            )
        }
        composable("contribute/search") {
            ContributePlaceSearchScreen(
                onNavigateBack = { navController.popBackStack() },
                onPlaceSelected = { placeId ->
                    navController.navigate("contribute/flow/$placeId") {
                        popUpTo("contribute/search") { inclusive = true }
                    }
                },
            )
        }
        composable(
            route = "contribute/flow/{placeId}",
            arguments = listOf(navArgument("placeId") { type = NavType.StringType }),
        ) { backStackEntry ->
            val placeId = backStackEntry.arguments?.getString("placeId").orEmpty()
            ContributeFlowScreen(
                placeId = placeId,
                onFinished = { navController.popBackStack() },
                onNeedsSignIn = { navController.navigate(authRoute(next = BACK)) },
            )
        }
    }
}

/** Set on the profile entry when Edit Response saved, so it shows "Review successfully updated". */
private const val REVIEW_UPDATED = "reviewUpdated"

/** "Sign in, then come back here": the auth route pops itself instead of opening Profile. */
private const val BACK = "back"

private fun authRoute(next: String) = "auth?next=" + android.net.Uri.encode(next)

private fun app.rollspot.shared.RollspotSdk.isSignedIn() = auth.isSignedIn
