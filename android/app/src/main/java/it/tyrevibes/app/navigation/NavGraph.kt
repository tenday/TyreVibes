package it.tyrevibes.app.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController

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
            // TODO: SplashScreen()
        }

        // OnBoarding
        composable(Screen.OnBoarding.route) {
            // TODO: OnBoardingScreen()
        }

        // Authentication
        composable(Screen.Login.route) {
            // TODO: LoginScreen()
        }

        composable(Screen.SignUp.route) {
            // TODO: SignUpScreen()
        }

        composable(Screen.ForgotPassword.route) {
            // TODO: ForgotPasswordScreen()
        }

        // Main App
        composable(Screen.Home.route) {
            // TODO: HomeScreen()
        }

        composable(Screen.Garage.route) {
            // TODO: GarageScreen()
        }

        composable(Screen.VehicleDetails.route) { backStackEntry ->
            val vehicleId = backStackEntry.arguments?.getString("vehicleId")?.toIntOrNull()
            // TODO: VehicleDetailsScreen(vehicleId)
        }

        composable(Screen.AddVehicle.route) {
            // TODO: AddVehicleScreen()
        }

        composable(Screen.LicensePlateScanner.route) {
            // TODO: LicensePlateScannerScreen()
        }

        composable(Screen.TyreAnalysis.route) {
            // TODO: TyreAnalysisScreen()
        }

        composable(Screen.TreadAnalysis.route) {
            // TODO: TreadAnalysisScreen()
        }

        composable(Screen.Map.route) {
            // TODO: MapScreen()
        }

        composable(Screen.Settings.route) {
            // TODO: SettingsScreen()
        }

        composable(Screen.Profile.route) {
            // TODO: ProfileScreen()
        }

        composable(Screen.Notifications.route) {
            // TODO: NotificationsScreen()
        }

        composable(Screen.Reports.route) {
            // TODO: ReportsScreen()
        }
    }
}
