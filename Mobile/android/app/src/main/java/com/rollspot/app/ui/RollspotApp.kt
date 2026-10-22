package com.rollspot.app.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
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
import com.rollspot.app.ui.screens.profile.ProfileScreen
import com.rollspot.app.ui.screens.profile.ProfileSettingsScreen
import com.rollspot.app.ui.screens.profile.SavedPlacesScreen
import com.rollspot.app.ui.screens.auth.AuthFlowScreen

@Composable
fun RollspotApp(review: String? = null) {
    val navController = rememberNavController()
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
                onContribute = { navController.navigate("contribute/flow/$placeId") },
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

        composable("auth") {
            AuthFlowScreen(
                onDone = { navController.navigate("me") { popUpTo("auth") { inclusive = true } } },
                onCancel = { navController.popBackStack() },
            )
        }

        // Profile (F5): signed-in user's page, settings and account.
        composable("me") {
            ProfileScreen(
                onBack = { navController.popBackStack() },
                onOpenSettings = { navController.navigate("settings") },
                onOpenPlace = { navController.navigate("place/$it") },
            )
        }
        composable("settings") {
            ProfileSettingsScreen(
                onBack = { navController.popBackStack() },
                onNavigate = { navController.navigate(it) },
                onSignedOut = { navController.popBackStack("home", inclusive = false) },
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
            )
        }
    }
}
