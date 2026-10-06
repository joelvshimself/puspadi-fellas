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
        
        composable("contribute") {
            ContributeScreen(onNavigateBack = { navController.popBackStack() })
        }
    }
}
