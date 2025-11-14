package it.tyrevibes.app.ui.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import it.tyrevibes.app.ui.theme.SoraFontFamily

sealed class BottomNavItem(
    val route: String,
    val icon: ImageVector,
    val label: String
) {
    object Garage : BottomNavItem("garage", Icons.Default.DirectionsCar, "Garage")
    object Reports : BottomNavItem("reports", Icons.Default.Description, "Report")
    object TyreAnalysis : BottomNavItem("tyre_analysis", Icons.Default.Autorenew, "Analisi")
    object Shop : BottomNavItem("shop", Icons.Default.Store, "Negozi")
    object Settings : BottomNavItem("settings", Icons.Default.Settings, "Impostazioni")
}

/**
 * Bottom Navigation Bar con pulsante centrale galleggiante
 */
@Composable
fun TyreVibesBottomNavigation(
    selectedRoute: String,
    onNavigate: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val items = listOf(
        BottomNavItem.Garage,
        BottomNavItem.Reports,
        BottomNavItem.TyreAnalysis, // Central floating button
        BottomNavItem.Shop,
        BottomNavItem.Settings
    )

    Box(
        modifier = modifier
            .fillMaxWidth()
            .background(
                brush = Brush.verticalGradient(
                    colors = listOf(
                        Color(0xFF1F1F1F).copy(alpha = 0.95f),
                        Color(0xFF1F1F1F)
                    )
                )
            )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 8.dp, horizontal = 16.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically
        ) {
            items.forEach { item ->
                if (item == BottomNavItem.TyreAnalysis) {
                    // Central floating action button
                    CentralActionButton(
                        isSelected = selectedRoute == item.route,
                        onClick = { onNavigate(item.route) }
                    )
                } else {
                    // Regular nav items
                    BottomNavButton(
                        item = item,
                        isSelected = selectedRoute == item.route,
                        onClick = { onNavigate(item.route) }
                    )
                }
            }
        }
    }
}

@Composable
private fun BottomNavButton(
    item: BottomNavItem,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val scale by animateFloatAsState(
        targetValue = if (isSelected) 1.1f else 1f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessLow
        ),
        label = "scale"
    )

    IconButton(
        onClick = onClick,
        modifier = modifier.scale(scale)
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            // Glass morphism background when selected
            Box(
                modifier = Modifier.size(44.dp),
                contentAlignment = Alignment.Center
            ) {
                if (isSelected) {
                    Box(
                        modifier = Modifier
                            .size(44.dp)
                            .shadow(10.dp, CircleShape)
                            .background(
                                brush = Brush.radialGradient(
                                    colors = listOf(
                                        Color.White.copy(alpha = 0.2f),
                                        Color.White.copy(alpha = 0.1f)
                                    ),
                                    center = Offset(22f, 22f)
                                ),
                                shape = CircleShape
                            )
                    )
                }

                Icon(
                    imageVector = item.icon,
                    contentDescription = item.label,
                    tint = if (isSelected) Color.White else Color.Gray,
                    modifier = Modifier.size(24.dp)
                )
            }

            if (isSelected) {
                Text(
                    text = item.label,
                    fontFamily = SoraFontFamily,
                    fontSize = 10.sp,
                    color = Color.White.copy(alpha = 0.8f)
                )
            }
        }
    }
}

@Composable
private fun CentralActionButton(
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val scale by animateFloatAsState(
        targetValue = if (isSelected) 1.2f else 1f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessLow
        ),
        label = "scale"
    )

    // Pulse animation
    val infiniteTransition = rememberInfiniteTransition(label = "pulse")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = 1.1f,
        animationSpec = infiniteRepeatable(
            animation = tween(1000, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulse"
    )

    Box(
        modifier = modifier
            .offset(y = (-25).dp)
            .scale(if (isSelected) pulseScale else 1f)
    ) {
        FloatingActionButton(
            onClick = onClick,
            containerColor = Color.Transparent,
            contentColor = Color.White,
            modifier = Modifier
                .size(70.dp)
                .scale(scale)
                .shadow(15.dp, CircleShape)
                .background(
                    brush = Brush.linearGradient(
                        colors = listOf(
                            Color(0xFF007AFF),
                            Color(0xFF0051D5)
                        ),
                        start = Offset.Zero,
                        end = Offset.Infinite
                    ),
                    shape = CircleShape
                )
        ) {
            Icon(
                imageVector = Icons.Default.Autorenew,
                contentDescription = "Analisi Pneumatici",
                modifier = Modifier.size(36.dp),
                tint = Color.White
            )
        }
    }
}
