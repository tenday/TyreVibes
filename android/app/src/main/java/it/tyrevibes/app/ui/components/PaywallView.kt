package it.tyrevibes.app.ui.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import it.tyrevibes.app.ui.theme.SoraFontFamily

/**
 * Premium Features enum
 */
enum class PremiumFeature(
    val icon: ImageVector,
    val title: String,
    val description: String
) {
    UNLIMITED_VEHICLES(
        Icons.Default.DirectionsCar,
        "Veicoli Illimitati",
        "Hai raggiunto il limite di veicoli gratuiti. Passa a Premium per aggiungerne senza limiti."
    ),
    UNLIMITED_TIRES(
        Icons.Default.SportsSoccer,
        "Pneumatici Illimitati",
        "Hai raggiunto il limite di pneumatici gratuiti. Passa a Premium per aggiungerne senza limiti."
    ),
    UNLIMITED_ANALYSES(
        Icons.Default.Analytics,
        "Analisi Illimitate",
        "Hai raggiunto il limite di analisi mensili. Passa a Premium per analisi illimitate."
    ),
    ADVANCED_REPORTS(
        Icons.Default.Assessment,
        "Report Avanzati",
        "Sblocca report dettagliati con grafici, proiezioni e raccomandazioni personalizzate."
    ),
    CLOUD_SYNC(
        Icons.Default.Cloud,
        "Sincronizzazione Cloud",
        "Sincronizza i tuoi dati su tutti i dispositivi con backup automatico."
    ),
    NO_ADS(
        Icons.Default.Block,
        "Esperienza Senza Pubblicità",
        "Rimuovi tutti gli annunci pubblicitari per un'esperienza senza interruzioni."
    )
}

/**
 * Full Paywall View
 */
@Composable
fun PaywallView(
    feature: PremiumFeature,
    onDismiss: () -> Unit,
    onUpgrade: () -> Unit,
    modifier: Modifier = Modifier
) {
    var visible by remember { mutableStateOf(false) }
    var scale by remember { mutableStateOf(0.9f) }

    LaunchedEffect(Unit) {
        visible = true
        scale = 1f
    }

    val scaleAnim by animateFloatAsState(
        targetValue = scale,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessMedium
        ),
        label = "scale"
    )

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.85f))
            .alpha(if (visible) 1f else 0f),
        contentAlignment = Alignment.Center
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth(0.9f)
                .scale(scaleAnim)
                .verticalScroll(rememberScrollState())
                .background(
                    color = Color(0xFF1C1C1E),
                    shape = RoundedCornerShape(24.dp)
                )
                .border(
                    width = 1.dp,
                    brush = Brush.linearGradient(
                        colors = listOf(
                            Color(0xFFFFD700).copy(alpha = 0.5f),
                            Color(0xFFFF8C00).copy(alpha = 0.5f)
                        )
                    ),
                    shape = RoundedCornerShape(24.dp)
                )
                .padding(32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            // Icon with glow
            PremiumIcon(feature.icon)

            // Title section
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.Star,
                        contentDescription = null,
                        tint = Color(0xFFFFD700),
                        modifier = Modifier.size(16.dp)
                    )

                    Text(
                        text = "Premium Feature",
                        fontFamily = SoraFontFamily,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 14.sp,
                        color = Color(0xFFFFD700)
                    )
                }

                Text(
                    text = feature.title,
                    fontFamily = SoraFontFamily,
                    fontWeight = FontWeight.Bold,
                    fontSize = 24.sp,
                    color = Color.White,
                    textAlign = TextAlign.Center
                )
            }

            // Description
            Text(
                text = feature.description,
                fontFamily = SoraFontFamily,
                fontWeight = FontWeight.Normal,
                fontSize = 16.sp,
                color = Color.White.copy(alpha = 0.8f),
                textAlign = TextAlign.Center,
                lineHeight = 24.sp
            )

            // Benefits list
            Column(
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                BenefitRow("Accesso illimitato a tutte le funzionalità")
                BenefitRow("Supporto clienti prioritario")
                BenefitRow("Esperienza senza pubblicità")
                BenefitRow("Sincronizzazione cloud multi-dispositivo")
            }

            // Buttons
            Column(
                verticalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                // Upgrade button
                Button(
                    onClick = onUpgrade,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(56.dp)
                        .shadow(15.dp, RoundedCornerShape(16.dp)),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color.Transparent
                    ),
                    contentPadding = PaddingValues(0.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .background(
                                brush = Brush.linearGradient(
                                    colors = listOf(
                                        Color(0xFFFFD700),
                                        Color(0xFFFF8C00)
                                    )
                                ),
                                shape = RoundedCornerShape(16.dp)
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                imageVector = Icons.Default.Star,
                                contentDescription = null,
                                tint = Color.White
                            )

                            Text(
                                text = "Passa a Premium",
                                fontFamily = SoraFontFamily,
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 18.sp,
                                color = Color.White
                            )
                        }
                    }
                }

                // Dismiss button
                TextButton(
                    onClick = onDismiss,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(
                        text = "Forse più tardi",
                        fontFamily = SoraFontFamily,
                        fontWeight = FontWeight.Medium,
                        fontSize = 16.sp,
                        color = Color.White.copy(alpha = 0.7f)
                    )
                }
            }
        }
    }
}

@Composable
private fun PremiumIcon(icon: ImageVector) {
    val infiniteTransition = rememberInfiniteTransition(label = "glow")
    val glowAlpha by infiniteTransition.animateFloat(
        initialValue = 0.3f,
        targetValue = 0.6f,
        animationSpec = infiniteRepeatable(
            animation = tween(1500, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "glow"
    )

    Box(
        modifier = Modifier.size(100.dp),
        contentAlignment = Alignment.Center
    ) {
        // Glow background
        Box(
            modifier = Modifier
                .size(100.dp)
                .background(
                    brush = Brush.radialGradient(
                        colors = listOf(
                            Color(0xFFFFD700).copy(alpha = glowAlpha),
                            Color(0xFFFF8C00).copy(alpha = glowAlpha / 2),
                            Color.Transparent
                        )
                    ),
                    shape = CircleShape
                )
        )

        // Icon
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = Color(0xFFFFD700),
            modifier = Modifier.size(50.dp)
        )
    }
}

@Composable
private fun BenefitRow(text: String) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = Icons.Default.CheckCircle,
            contentDescription = null,
            tint = Color(0xFF34C759),
            modifier = Modifier.size(18.dp)
        )

        Text(
            text = text,
            fontFamily = SoraFontFamily,
            fontWeight = FontWeight.Medium,
            fontSize = 14.sp,
            color = Color.White.copy(alpha = 0.9f)
        )
    }
}

/**
 * Compact Paywall View
 */
@Composable
fun CompactPaywallView(
    feature: PremiumFeature,
    onUpgrade: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(
                color = Color(0xFF1C1C1E).copy(alpha = 0.95f),
                shape = RoundedCornerShape(16.dp)
            )
            .border(
                width = 1.dp,
                color = Color(0xFFFFD700).copy(alpha = 0.3f),
                shape = RoundedCornerShape(16.dp)
            )
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Default.Lock,
                contentDescription = null,
                tint = Color(0xFFFFD700),
                modifier = Modifier.size(24.dp)
            )

            Column(
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Text(
                    text = "Limite Raggiunto",
                    fontFamily = SoraFontFamily,
                    fontWeight = FontWeight.Bold,
                    fontSize = 18.sp,
                    color = Color.White
                )

                Text(
                    text = feature.description,
                    fontFamily = SoraFontFamily,
                    fontWeight = FontWeight.Normal,
                    fontSize = 14.sp,
                    color = Color.White.copy(alpha = 0.8f),
                    maxLines = 2
                )
            }
        }

        Button(
            onClick = onUpgrade,
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = Color.Transparent
            ),
            contentPadding = PaddingValues(0.dp)
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        brush = Brush.linearGradient(
                            colors = listOf(
                                Color(0xFFFFD700),
                                Color(0xFFFF8C00)
                            )
                        ),
                        shape = RoundedCornerShape(12.dp)
                    ),
                contentAlignment = Alignment.Center
            ) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.Star,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(14.dp)
                    )

                    Text(
                        text = "Passa a Premium",
                        fontFamily = SoraFontFamily,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 16.sp,
                        color = Color.White
                    )
                }
            }
        }
    }
}
