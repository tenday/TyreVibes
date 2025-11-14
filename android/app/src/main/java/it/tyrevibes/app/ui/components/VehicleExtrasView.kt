package it.tyrevibes.app.ui.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import it.tyrevibes.app.core.model.*
import it.tyrevibes.app.ui.theme.SoraFontFamily
import kotlin.math.cos
import kotlin.math.sin

// ========================================
// 1. REVISION TIMELINE VIEW
// ========================================

enum class ConnectionStatus {
    GOOD, WARNING, NEUTRAL;

    val color: Color
        get() = when (this) {
            GOOD -> Color(0xFF34C759)
            WARNING -> Color(0xFFFF8C00)
            NEUTRAL -> Color.Gray
        }
}

@Composable
fun RevisionTimelineView(
    revisions: List<VehicleRevision>,
    modifier: Modifier = Modifier
) {
    var selectedRevision by remember { mutableStateOf<VehicleRevision?>(null) }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 20.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        Text(
            text = "Cronologia Revisioni",
            fontFamily = SoraFontFamily,
            fontWeight = FontWeight.Bold,
            fontSize = 18.sp,
            color = Color.White,
            modifier = Modifier.padding(horizontal = 20.dp)
        )

        LazyRow(
            modifier = Modifier.fillMaxWidth(),
            contentPadding = PaddingValues(horizontal = 30.dp),
            horizontalArrangement = Arrangement.spacedBy(0.dp)
        ) {
            itemsIndexed(revisions) { index, revision ->
                TimelineNode(
                    revision = revision,
                    index = index,
                    isFirst = index == 0,
                    isLast = index == revisions.lastIndex,
                    isSelected = selectedRevision?.id == revision.id,
                    onClick = {
                        selectedRevision = if (selectedRevision?.id == revision.id) null else revision
                    }
                )

                if (index < revisions.lastIndex) {
                    TimelineConnector(
                        status = getConnectionStatus(revision, revisions[index + 1])
                    )
                }
            }
        }

        // Selected revision detail card
        selectedRevision?.let { revision ->
            RevisionDetailCard(revision = revision)
        }
    }
}

@Composable
private fun TimelineNode(
    revision: VehicleRevision,
    index: Int,
    isFirst: Boolean,
    isLast: Boolean,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    val statusColor = getRevisionStatusColor(revision)
    var appear by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(index * 100L)
        appear = true
    }

    val scale by animateFloatAsState(
        targetValue = if (appear) 1f else 0.5f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessLow
        ),
        label = "appear"
    )

    Column(
        modifier = Modifier
            .width(100.dp)
            .scale(scale)
            .alpha(if (appear) 1f else 0f)
            .clickable(onClick = onClick),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        // Date label
        Text(
            text = formatRevisionDate(revision.dataRevisione),
            fontFamily = SoraFontFamily,
            fontWeight = FontWeight.Medium,
            fontSize = 10.sp,
            color = Color.White.copy(alpha = 0.7f)
        )

        // Node circle
        Box(
            modifier = Modifier
                .size(50.dp)
                .shadow(if (isSelected) 15.dp else 5.dp, CircleShape)
                .background(
                    brush = Brush.radialGradient(
                        colors = listOf(
                            statusColor.copy(alpha = 0.8f),
                            statusColor.copy(alpha = 0.4f)
                        )
                    ),
                    shape = CircleShape
                )
                .border(
                    width = if (isSelected) 3.dp else 2.dp,
                    color = statusColor,
                    shape = CircleShape
                )
                .scale(if (isSelected) 1.2f else 1f),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = getRevisionStatusIcon(revision),
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(20.dp)
            )
        }

        // KM badge
        revision.kmRevisione?.let { km ->
            if (km.isNotEmpty()) {
                Row(
                    modifier = Modifier
                        .background(
                            color = Color.Black.copy(alpha = 0.3f),
                            shape = RoundedCornerShape(8.dp)
                        )
                        .padding(horizontal = 8.dp, vertical = 4.dp),
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.Speed,
                        contentDescription = null,
                        tint = Color.White.copy(alpha = 0.8f),
                        modifier = Modifier.size(8.dp)
                    )
                    Text(
                        text = "$km km",
                        fontFamily = SoraFontFamily,
                        fontWeight = FontWeight.Medium,
                        fontSize = 9.sp,
                        color = Color.White.copy(alpha = 0.8f)
                    )
                }
            }
        }
    }
}

@Composable
private fun TimelineConnector(
    status: ConnectionStatus
) {
    Box(
        modifier = Modifier
            .width(50.dp)
            .height(3.dp)
            .background(
                brush = Brush.horizontalGradient(
                    colors = listOf(
                        status.color.copy(alpha = 0.6f),
                        status.color.copy(alpha = 0.3f)
                    )
                )
            )
    )
}

@Composable
private fun RevisionDetailCard(
    revision: VehicleRevision,
    modifier: Modifier = Modifier
) {
    var appear by remember { mutableStateOf(false) }

    LaunchedEffect(revision) {
        appear = true
    }

    val scale by animateFloatAsState(
        targetValue = if (appear) 1f else 0.9f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy
        ),
        label = "appear"
    )

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp)
            .scale(scale)
            .alpha(if (appear) 1f else 0f)
            .background(
                color = Color.White.copy(alpha = 0.05f),
                shape = RoundedCornerShape(16.dp)
            )
            .border(
                width = 1.dp,
                color = Color(0xFF34C759).copy(alpha = 0.3f),
                shape = RoundedCornerShape(16.dp)
            )
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Default.Description,
                contentDescription = null,
                tint = Color(0xFF34C759),
                modifier = Modifier.size(20.dp)
            )

            Text(
                text = "Dettagli Revisione",
                fontFamily = SoraFontFamily,
                fontWeight = FontWeight.Bold,
                fontSize = 16.sp,
                color = Color.White
            )
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            InfoBlock(
                icon = Icons.Default.CalendarToday,
                label = "Data",
                value = revision.dataRevisione ?: "N/A"
            )

            InfoBlock(
                icon = Icons.Default.CheckCircle,
                label = "Esito",
                value = revision.esitoRevisione ?: "N/A"
            )

            InfoBlock(
                icon = Icons.Default.Speed,
                label = "Chilometraggio",
                value = (revision.kmRevisione ?: "N/A") + " km"
            )
        }
    }
}

@Composable
private fun InfoBlock(
    icon: ImageVector,
    label: String,
    value: String
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = Color.White.copy(alpha = 0.6f),
                modifier = Modifier.size(12.dp)
            )

            Text(
                text = label,
                fontFamily = SoraFontFamily,
                fontWeight = FontWeight.Medium,
                fontSize = 11.sp,
                color = Color.White.copy(alpha = 0.6f)
            )
        }

        Text(
            text = value,
            fontFamily = SoraFontFamily,
            fontWeight = FontWeight.SemiBold,
            fontSize = 13.sp,
            color = Color.White
        )
    }
}

private fun getRevisionStatusColor(revision: VehicleRevision): Color {
    val esito = revision.esitoRevisione?.lowercase() ?: return Color.Gray
    return when {
        esito.contains("positive") || esito.contains("pass") -> Color(0xFF34C759)
        esito.contains("negative") || esito.contains("fail") -> Color(0xFFFF3B30)
        else -> Color(0xFFFF8C00)
    }
}

private fun getRevisionStatusIcon(revision: VehicleRevision): ImageVector {
    val esito = revision.esitoRevisione?.lowercase() ?: return Icons.Default.Help
    return when {
        esito.contains("positive") || esito.contains("pass") -> Icons.Default.Check
        esito.contains("negative") || esito.contains("fail") -> Icons.Default.Close
        else -> Icons.Default.Warning
    }
}

private fun getConnectionStatus(current: VehicleRevision, next: VehicleRevision): ConnectionStatus {
    val currentPositive = current.esitoRevisione?.lowercase()?.contains("positive") == true
    val nextPositive = next.esitoRevisione?.lowercase()?.contains("positive") == true

    return when {
        currentPositive && nextPositive -> ConnectionStatus.GOOD
        !currentPositive || !nextPositive -> ConnectionStatus.WARNING
        else -> ConnectionStatus.NEUTRAL
    }
}

private fun formatRevisionDate(dateString: String?): String {
    dateString ?: return ""
    val components = dateString.split("-")
    return if (components.size >= 2) {
        "${components[1]}/${components[0].takeLast(2)}"
    } else ""
}

// ========================================
// 2. SIMPLE 3D TYRE VISUALIZATION
// ========================================

@Composable
fun Tyre3DView(
    tyre: VehicleTyre,
    modifier: Modifier = Modifier
) {
    var rotation by remember { mutableStateOf(0f) }

    LaunchedEffect(Unit) {
        while (true) {
            rotation += 1f
            if (rotation >= 360f) rotation = 0f
            kotlinx.coroutines.delay(16)
        }
    }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        Text(
            text = "Visualizzazione 3D Pneumatico",
            fontFamily = SoraFontFamily,
            fontWeight = FontWeight.Bold,
            fontSize = 18.sp,
            color = Color.White
        )

        Box(
            modifier = Modifier
                .size(250.dp)
                .background(
                    brush = Brush.radialGradient(
                        colors = listOf(
                            Color(0xFF007AFF).copy(alpha = 0.1f),
                            Color.Transparent
                        )
                    )
                ),
            contentAlignment = Alignment.Center
        ) {
            // Simple 3D tyre visualization
            Canvas(modifier = Modifier.fillMaxSize()) {
                val centerX = size.width / 2
                val centerY = size.height / 2
                val radius = size.minDimension * 0.4f

                // Outer tyre
                drawCircle(
                    brush = Brush.radialGradient(
                        colors = listOf(
                            Color.Black,
                            Color.Gray,
                            Color.Black
                        ),
                        center = Offset(centerX, centerY),
                        radius = radius
                    ),
                    radius = radius,
                    center = Offset(centerX, centerY)
                )

                // Tread pattern
                for (i in 0 until 12) {
                    val angle = (i * 30f + rotation) * (Math.PI / 180f).toFloat()
                    val x1 = centerX + (radius * 0.8f) * cos(angle)
                    val y1 = centerY + (radius * 0.8f) * sin(angle)
                    val x2 = centerX + radius * cos(angle)
                    val y2 = centerY + radius * sin(angle)

                    drawLine(
                        color = Color(0xFF34C759),
                        start = Offset(x1, y1),
                        end = Offset(x2, y2),
                        strokeWidth = 4.dp.toPx()
                    )
                }

                // Inner rim
                drawCircle(
                    brush = Brush.radialGradient(
                        colors = listOf(
                            Color.Gray,
                            Color.White,
                            Color.Gray
                        )
                    ),
                    radius = radius * 0.4f,
                    center = Offset(centerX, centerY)
                )
            }

            // Central specs
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Text(
                    text = "${tyre.width ?: 0}/${tyre.ratio ?: 0}",
                    fontFamily = SoraFontFamily,
                    fontWeight = FontWeight.Bold,
                    fontSize = 24.sp,
                    color = Color.White
                )

                Text(
                    text = "R${tyre.diameter ?: 0}",
                    fontFamily = SoraFontFamily,
                    fontWeight = FontWeight.Medium,
                    fontSize = 18.sp,
                    color = Color.White.copy(alpha = 0.8f)
                )
            }
        }

        // Control info
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            QuickSpec(
                label = "Larghezza",
                value = "${tyre.width ?: 0}mm",
                color = Color(0xFF007AFF)
            )

            QuickSpec(
                label = "Rapporto",
                value = "${tyre.ratio ?: 0}%",
                color = Color(0xFF34C759)
            )

            QuickSpec(
                label = "Diametro",
                value = "R${tyre.diameter ?: 0}",
                color = Color(0xFFAF52DE)
            )
        }
    }
}

@Composable
private fun QuickSpec(
    label: String,
    value: String,
    color: Color
) {
    Column(
        modifier = Modifier
            .background(
                color = color.copy(alpha = 0.1f),
                shape = RoundedCornerShape(8.dp)
            )
            .padding(vertical = 8.dp, horizontal = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(
            text = label,
            fontFamily = SoraFontFamily,
            fontWeight = FontWeight.Medium,
            fontSize = 10.sp,
            color = Color.White.copy(alpha = 0.6f)
        )

        Text(
            text = value,
            fontFamily = SoraFontFamily,
            fontWeight = FontWeight.Bold,
            fontSize = 14.sp,
            color = color
        )
    }
}

// ========================================
// 3. INSURANCE DASHBOARD
// ========================================

enum class InsuranceStatus {
    ACTIVE, EXPIRING_SOON, EXPIRED, INACTIVE;

    val color: Color
        get() = when (this) {
            ACTIVE -> Color(0xFF34C759)
            EXPIRING_SOON -> Color(0xFFFF8C00)
            EXPIRED -> Color(0xFFFF3B30)
            INACTIVE -> Color.Gray
        }

    val text: String
        get() = when (this) {
            ACTIVE -> "Attiva"
            EXPIRING_SOON -> "In scadenza"
            EXPIRED -> "Scaduta"
            INACTIVE -> "Inattiva"
        }
}

@Composable
fun InsuranceDashboard(
    insurance: VehicleInsurance,
    modifier: Modifier = Modifier
) {
    val daysRemaining = 45 // Simplified - would calculate from expiry date

    Column(
        modifier = modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp)
    ) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Text(
                    text = "Assicurazione",
                    fontFamily = SoraFontFamily,
                    fontWeight = FontWeight.Bold,
                    fontSize = 24.sp,
                    color = Color.White
                )

                Text(
                    text = insurance.rcaCompany ?: "Compagnia",
                    fontFamily = SoraFontFamily,
                    fontWeight = FontWeight.Medium,
                    fontSize = 16.sp,
                    color = Color.White.copy(alpha = 0.7f)
                )
            }

            StatusBadge(status = InsuranceStatus.ACTIVE)
        }

        // Circular progress
        CircularProgressIndicator(
            daysRemaining = daysRemaining,
            expiryDate = insurance.rcaExpiry ?: ""
        )
    }
}

@Composable
private fun StatusBadge(status: InsuranceStatus) {
    Row(
        modifier = Modifier
            .background(
                color = status.color.copy(alpha = 0.2f),
                shape = RoundedCornerShape(20.dp)
            )
            .padding(horizontal = 12.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(8.dp)
                .background(status.color, CircleShape)
        )

        Text(
            text = status.text,
            fontFamily = SoraFontFamily,
            fontWeight = FontWeight.SemiBold,
            fontSize = 12.sp,
            color = Color.White
        )
    }
}

@Composable
private fun CircularProgressIndicator(
    daysRemaining: Int,
    expiryDate: String
) {
    val progress = (daysRemaining / 365f).coerceIn(0f, 1f)
    val progressColor = when {
        daysRemaining < 30 -> Color(0xFFFF3B30)
        daysRemaining < 60 -> Color(0xFFFF8C00)
        else -> Color(0xFF34C759)
    }

    Box(
        modifier = Modifier
            .size(200.dp),
        contentAlignment = Alignment.Center
    ) {
        // Background circle
        Canvas(modifier = Modifier.fillMaxSize()) {
            drawCircle(
                color = Color.Gray.copy(alpha = 0.2f),
                style = Stroke(width = 20.dp.toPx())
            )

            // Progress arc
            drawArc(
                color = progressColor,
                startAngle = -90f,
                sweepAngle = progress * 360f,
                useCenter = false,
                style = Stroke(width = 20.dp.toPx())
            )
        }

        // Center text
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                text = "$daysRemaining",
                fontFamily = SoraFontFamily,
                fontWeight = FontWeight.Bold,
                fontSize = 48.sp,
                color = Color.White
            )

            Text(
                text = "giorni rimanenti",
                fontFamily = SoraFontFamily,
                fontWeight = FontWeight.Medium,
                fontSize = 12.sp,
                color = Color.White.copy(alpha = 0.7f)
            )

            Text(
                text = "Scade: $expiryDate",
                fontFamily = SoraFontFamily,
                fontSize = 10.sp,
                color = Color.White.copy(alpha = 0.5f)
            )
        }
    }
}
