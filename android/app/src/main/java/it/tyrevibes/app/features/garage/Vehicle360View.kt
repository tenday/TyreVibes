package it.tyrevibes.app.features.garage

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.ZoomIn
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Vista 360° del veicolo con rotazione automatica.
 *
 * Features:
 * - Visualizzazione veicolo con angolo variabile (200-231° per rotazione completa)
 * - Auto-rotazione con play/pause
 * - Indicatore circolare progresso rotazione
 * - Zoom controlli
 * - Integrazione con VehicleImageService per download immagini
 *
 * TODO: Implementare download immagini reali con VehicleImageService
 */
@Composable
fun Vehicle360View(
    make: String,
    modelFamily: String,
    year: String,
    paintId: String,
    loadingProgress: Double,
    isLoading: Boolean,
    onLoadingProgressChange: (Double) -> Unit,
    onLoadingChange: (Boolean) -> Unit
) {
    val angles = remember { (200..231).toList() } // 32 angoli per 360°
    var currentIndex by remember { mutableStateOf(0) }
    var isPlaying by remember { mutableStateOf(false) }
    var scale by remember { mutableStateOf(1.0f) }
    val scope = rememberCoroutineScope()

    // Auto-rotation effect
    LaunchedEffect(isPlaying) {
        if (isPlaying) {
            while (isPlaying) {
                delay(100) // 100ms per frame = 10 FPS
                currentIndex = (currentIndex + 1) % angles.size
            }
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF1C1C1E))
    ) {
        // TODO: Immagine veicolo dall'angolo corrente
        // Per ora placeholder
        if (!isLoading) {
            Box(
                modifier = Modifier
                    .fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    Text(
                        text = "[Vehicle Image - Angle ${angles[currentIndex]}°]",
                        color = Color.Gray,
                        fontSize = 14.sp
                    )
                    Text(
                        text = "$make $modelFamily",
                        color = Color.White,
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        text = "Year: $year | Color: $paintId",
                        color = Color.Gray,
                        fontSize = 14.sp
                    )
                }
            }
        }

        // Loading overlay
        if (isLoading) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.7f)),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    CircularProgressIndicator(
                        progress = loadingProgress.toFloat(),
                        modifier = Modifier.size(64.dp),
                        color = Color(0xFFFF6B6B)
                    )
                    Text(
                        text = "Loading ${(loadingProgress * 100).toInt()}%",
                        color = Color.White,
                        fontSize = 16.sp
                    )
                }
            }
        }

        // Controls
        if (!isLoading) {
            Column(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 40.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(30.dp)
            ) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(30.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Play/Pause button
                    FloatingActionButton(
                        onClick = { isPlaying = !isPlaying },
                        containerColor = Color(0xFF2C2C2E),
                        modifier = Modifier.size(50.dp)
                    ) {
                        Icon(
                            imageVector = if (isPlaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                            contentDescription = if (isPlaying) "Pause" else "Play",
                            tint = Color.White
                        )
                    }

                    // Rotation progress indicator
                    Box(
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator(
                            progress = currentIndex.toFloat() / angles.size.toFloat(),
                            modifier = Modifier.size(80.dp),
                            color = Color(0xFFFF6B6B),
                            strokeWidth = 6.dp,
                            trackColor = Color.White.copy(alpha = 0.2f)
                        )
                        Text(
                            text = "${(currentIndex.toFloat() / angles.size * 360).toInt()}°",
                            color = Color.White,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }

                    // Reset zoom button
                    FloatingActionButton(
                        onClick = { scale = 1.0f },
                        containerColor = Color(0xFF2C2C2E),
                        modifier = Modifier.size(50.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.ZoomIn,
                            contentDescription = "Reset Zoom",
                            tint = Color.White
                        )
                    }
                }

                // Gesture hint
                Text(
                    text = "Swipe left/right to rotate manually",
                    color = Color.Gray,
                    fontSize = 12.sp
                )
            }
        }
    }

    // Load images on mount
    LaunchedEffect(Unit) {
        scope.launch {
            onLoadingChange(true)
            // TODO: Preload images with VehicleImageService
            // for (i in 0..31) {
            //     delay(100)
            //     onLoadingProgressChange((i + 1) / 32.0)
            // }
            delay(2000) // Simulate loading
            onLoadingProgressChange(1.0)
            onLoadingChange(false)
        }
    }
}
