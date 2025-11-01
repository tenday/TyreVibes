package it.tyrevibes.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import androidx.navigation.compose.rememberNavController
import it.tyrevibes.app.navigation.NavGraph
import it.tyrevibes.app.navigation.Screen
import it.tyrevibes.app.ui.theme.TyreVibesTheme

/**
 * MainActivity - Entry point dell'applicazione Android
 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            TyreVibesTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    val navController = rememberNavController()
                    NavGraph(
                        navController = navController,
                        startDestination = Screen.Login.route
                    )
                }
            }
        }
    }
}
