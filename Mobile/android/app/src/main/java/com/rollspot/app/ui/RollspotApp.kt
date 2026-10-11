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
import com.rollspot.app.ui.screens.contribute.ContributeFlowScreen
import com.rollspot.app.ui.screens.contribute.ContributePlaceSearchScreen
import com.rollspot.app.ui.screens.contribute.ContributeScreen

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
                onNavigateBack = { navController.popBackStack() },
                onContribute = { id -> navController.navigate("contribute/flow/$id") },
            )
        }
        
        composable("saved") {
            SavedScreen(onNavigateBack = { navController.popBackStack() })
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
