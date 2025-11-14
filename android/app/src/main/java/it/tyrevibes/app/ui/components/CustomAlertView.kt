package it.tyrevibes.app.ui.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import it.tyrevibes.app.ui.theme.SoraFontFamily
import kotlinx.coroutines.delay

/**
 * Custom Alert View con effetto glass morphism e animazione typewriter
 */
@Composable
fun CustomAlertView(
    title: String,
    showProgress: Boolean = false,
    modifier: Modifier = Modifier,
    onDismiss: (() -> Unit)? = null
) {
    var visible by remember { mutableStateOf(false) }
    var scale by remember { mutableStateOf(0f) }
    var displayedText by remember { mutableStateOf("") }
    var currentIndex by remember { mutableStateOf(0) }

    // Animazione di ingresso
    LaunchedEffect(Unit) {
        visible = true
        delay(100)
        scale = 1f

        // Effetto typewriter
        delay(300)
        while (currentIndex < title.length) {
            displayedText = title.substring(0, currentIndex + 1)
            currentIndex++
            delay(30)
        }

        // Auto-dismiss dopo 3 secondi se non c'è progress
        if (!showProgress && onDismiss != null) {
            delay(3000)
            scale = 0f
            delay(300)
            onDismiss()
        }
    }

    val scaleAnim by animateFloatAsState(
        targetValue = scale,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessLow
        ),
        label = "scale"
    )

    val offsetY by animateFloatAsState(
        targetValue = if (visible) 40f else -1000f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessMedium
        ),
        label = "offsetY"
    )

    Box(
        modifier = modifier
            .fillMaxSize()
            .wrapContentSize(Alignment.TopCenter)
            .offset(y = offsetY.dp)
            .scale(scaleAnim)
    ) {
        // Glass morphism background
        Row(
            modifier = Modifier
                .background(
                    brush = Brush.linearGradient(
                        colors = listOf(
                            Color.White.copy(alpha = 0.15f),
                            Color.White.copy(alpha = 0.05f)
                        ),
                        start = Offset(0f, 0f),
                        end = Offset(1000f, 1000f)
                    ),
                    shape = RoundedCornerShape(24.dp)
                )
                .padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            if (displayedText.isNotEmpty()) {
                Text(
                    text = displayedText,
                    fontFamily = SoraFontFamily,
                    fontSize = 16.sp,
                    color = Color.White,
                    modifier = Modifier.alpha(if (displayedText.isNotEmpty()) 1f else 0f)
                )
            }

            if (showProgress) {
                CircularProgressIndicator(
                    modifier = Modifier.size(16.dp),
                    color = Color.White,
                    strokeWidth = 2.dp
                )
            }
        }
    }
}
