package it.tyrevibes.app.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import it.tyrevibes.app.features.auth.LoginScreen
import it.tyrevibes.app.features.auth.SignUpScreen
import it.tyrevibes.app.features.garage.GarageScreen
import it.tyrevibes.app.features.licenseplate.LicensePlateScannerScreen
import it.tyrevibes.app.features.map.MapScreen
import it.tyrevibes.app.features.notifications.NotificationsScreen
import it.tyrevibes.app.features.onboarding.OnBoardingScreen
import it.tyrevibes.app.features.onboarding.SplashScreen
import it.tyrevibes.app.features.profile.ProfileScreen
import it.tyrevibes.app.features.settings.SettingsScreen
import it.tyrevibes.app.features.tyre.TyreAnalysisScreen

/**
 * Navigation Routes
 */
sealed class Screen(val route: String) {
    object Splash : Screen("splash")
    object OnBoarding : Screen("onboarding")
    object Login : Screen("login")
    object SignUp : Screen("signup")
    object ForgotPassword : Screen("forgot_password")
    object Home : Screen("home")
    object Garage : Screen("garage")
    object VehicleDetails : Screen("vehicle_details/{vehicleId}") {
        fun createRoute(vehicleId: Int) = "vehicle_details/$vehicleId"
    }
    object AddVehicle : Screen("add_vehicle")
    object LicensePlateScanner : Screen("license_plate_scanner")
    object TyreAnalysis : Screen("tyre_analysis")
    object TreadAnalysis : Screen("tread_analysis")
    object Map : Screen("map")
    object Settings : Screen("settings")
    object Profile : Screen("profile")
    object Notifications : Screen("notifications")
    object Reports : Screen("reports")
}

/**
 * Main Navigation Graph
 */
@Composable
fun NavGraph(
    navController: NavHostController = rememberNavController(),
    startDestination: String = Screen.Splash.route
) {
    NavHost(
        navController = navController,
        startDestination = startDestination
    ) {
        // Splash Screen
        composable(Screen.Splash.route) {
            SplashScreen(
                onNavigateToOnBoarding = {
                    navController.navigate(Screen.OnBoarding.route) {
                        popUpTo(Screen.Splash.route) { inclusive = true }
                    }
                },
                onNavigateToHome = {
                    navController.navigate(Screen.Garage.route) {
                        popUpTo(Screen.Splash.route) { inclusive = true }
                    }
                }
            )
        }

        // OnBoarding
        composable(Screen.OnBoarding.route) {
            OnBoardingScreen(
                onNavigateToLogin = {
                    navController.navigate(Screen.Login.route) {
                        popUpTo(Screen.OnBoarding.route) { inclusive = true }
                    }
                }
            )
        }

        // Authentication
        composable(Screen.Login.route) {
            LoginScreen(
                onNavigateToSignUp = {
                    navController.navigate(Screen.SignUp.route)
                },
                onNavigateToForgotPassword = {
                    navController.navigate(Screen.ForgotPassword.route)
                },
                onNavigateToHome = {
                    navController.navigate(Screen.Garage.route) {
                        popUpTo(Screen.Login.route) { inclusive = true }
                    }
                }
            )
        }

        composable(Screen.SignUp.route) {
            SignUpScreen(
                onNavigateToLogin = {
                    navController.popBackStack()
                },
                onNavigateToHome = {
                    navController.navigate(Screen.Garage.route) {
                        popUpTo(Screen.SignUp.route) { inclusive = true }
                    }
                }
            )
        }

        composable(Screen.ForgotPassword.route) {
            // TODO: ForgotPasswordScreen - Simple implementation
        }

        // Main App
        composable(Screen.Home.route) {
            // Redirect to Garage for now
            GarageScreen(
                onNavigateToAddVehicle = {
                    navController.navigate(Screen.LicensePlateScanner.route)
                },
                onNavigateToVehicleDetails = { vehicleId ->
                    navController.navigate(Screen.VehicleDetails.createRoute(vehicleId))
                }
            )
        }

        composable(Screen.Garage.route) {
            GarageScreen(
                onNavigateToAddVehicle = {
                    navController.navigate(Screen.LicensePlateScanner.route)
                },
                onNavigateToVehicleDetails = { vehicleId ->
                    navController.navigate(Screen.VehicleDetails.createRoute(vehicleId))
                }
            )
        }

        composable(Screen.VehicleDetails.route) { backStackEntry ->
            val vehicleId = backStackEntry.arguments?.getString("vehicleId")?.toIntOrNull()
            // TODO: VehicleDetailsScreen(vehicleId)
        }

        composable(Screen.AddVehicle.route) {
            // Redirect to License Plate Scanner
            LicensePlateScannerScreen(
                onNavigateBack = { navController.popBackStack() },
                onPlateDetected = { plate ->
                    // TODO: Navigate to vehicle details with plate
                    navController.popBackStack()
                }
            )
        }

        composable(Screen.LicensePlateScanner.route) {
            LicensePlateScannerScreen(
                onNavigateBack = { navController.popBackStack() },
                onPlateDetected = { plate ->
                    // TODO: Navigate to vehicle details with plate
                    navController.popBackStack()
                }
            )
        }

        composable(Screen.TyreAnalysis.route) {
            TyreAnalysisScreen(
                onNavigateBack = { navController.popBackStack() },
                onStartAnalysis = {
                    // TODO: Navigate to camera/analysis
                }
            )
        }

        composable(Screen.TreadAnalysis.route) {
            TyreAnalysisScreen(
                onNavigateBack = { navController.popBackStack() },
                onStartAnalysis = {
                    // TODO: Navigate to camera/analysis
                }
            )
        }

        composable(Screen.Map.route) {
            MapScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        composable(Screen.Settings.route) {
            SettingsScreen(
                onNavigateBack = { navController.popBackStack() },
                onNavigateToProfile = {
                    navController.navigate(Screen.Profile.route)
                }
            )
        }

        composable(Screen.Profile.route) {
            ProfileScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        composable(Screen.Notifications.route) {
            NotificationsScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        composable(Screen.Reports.route) {
            // TODO: ReportsScreen - Simple implementation
        }
    }
}
