package it.tyrevibes.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview

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
                    TyreVibesApp()
                }
            }
        }
    }
}

@Composable
fun TyreVibesTheme(content: @Composable () -> Unit) {
    MaterialTheme {
        content()
    }
}

@Composable
fun TyreVibesApp() {
    // TODO: Implementare la navigazione e le schermate
    Text(text = "TyreVibes - Android")
}

@Preview(showBackground = true)
@Composable
fun DefaultPreview() {
    TyreVibesTheme {
        TyreVibesApp()
    }
}
