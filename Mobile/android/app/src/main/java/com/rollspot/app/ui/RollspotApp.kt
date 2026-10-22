package com.rollspot.app.ui

import androidx.compose.runtime.Composable
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.rollspot.app.ui.screens.home.HomeScreen
import com.rollspot.app.ui.screens.place.PlaceDetailScreen
import com.rollspot.app.ui.screens.saved.SavedScreen
import com.rollspot.app.ui.screens.contribute.ContributeScreen
import com.rollspot.app.ui.screens.account.AccountScreen
import com.rollspot.app.ui.screens.auth.AuthFlowScreen

@Composable
fun RollspotApp() {
    val navController = rememberNavController()
    
    NavHost(
        navController = navController,
        startDestination = "home"
    ) {
        composable("home") {
            HomeScreen(navController = navController)
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
                onNavigateBack = { navController.popBackStack() }
            )
        }
        
        composable("saved") {
            SavedScreen(onNavigateBack = { navController.popBackStack() })
        }
        
        // Profile button: the account when signed in, otherwise the sign-in flow.
        composable("profile") {
            val auth = rollspotSdk().auth
            androidx.compose.runtime.LaunchedEffect(Unit) {
                navController.navigate(if (auth.isSignedIn) "account" else "auth") { popUpTo("profile") { inclusive = true } }
            }
        }

        composable("auth") {
            AuthFlowScreen(
                onDone = { navController.navigate("account") { popUpTo("auth") { inclusive = true } } },
                onCancel = { navController.popBackStack() },
            )
        }

        composable("account") {
            AccountScreen(
                onSignedOut = { navController.popBackStack() },
                onNavigateBack = { navController.popBackStack() },
            )
        }

        composable("contribute") {
            ContributeScreen(onNavigateBack = { navController.popBackStack() })
        }
    }
}
