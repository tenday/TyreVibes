package it.tyrevibes.app.ui.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import it.tyrevibes.app.ui.theme.SoraFontFamily
import kotlin.math.pow
import kotlin.math.sqrt

/**
 * Heat Map Data Models
 */
data class DepthHeatMap(
    val gridSize: GridSize,
    val dataPoints: List<List<Double>>,
    val colorScheme: HeatMapColorScheme,
    val interpolated: Boolean = false
) {
    data class GridSize(val rows: Int, val columns: Int)

    enum class HeatMapColorScheme {
        THERMAL, RAINBOW, MONOCHROME;

        val colors: List<Color>
            get() = when (this) {
                THERMAL -> listOf(
                    Color(0xFF00FF00), // Green (good)
                    Color(0xFFFFFF00), // Yellow
                    Color(0xFFFF8C00), // Orange
                    Color(0xFFFF0000)  // Red (critical)
                )
                RAINBOW -> listOf(
                    Color(0xFF0000FF), // Blue
                    Color(0xFF00FFFF), // Cyan
                    Color(0xFF00FF00), // Green
                    Color(0xFFFFFF00), // Yellow
                    Color(0xFFFF0000)  // Red
                )
                MONOCHROME -> listOf(
                    Color(0xFF000000),
                    Color(0xFF808080),
                    Color(0xFFFFFFFF)
                )
            }
    }

    fun colorForDepth(depth: Double, minDepth: Double, maxDepth: Double): Color {
        val normalized = ((depth - minDepth) / (maxDepth - minDepth)).coerceIn(0.0, 1.0)
        val colors = colorScheme.colors
        val index = (normalized * (colors.size - 1)).toFloat()
        val lowerIndex = index.toInt().coerceIn(0, colors.size - 2)
        val upperIndex = (lowerIndex + 1).coerceIn(0, colors.size - 1)
        val fraction = index - lowerIndex

        return lerp(colors[lowerIndex], colors[upperIndex], fraction)
    }

    private fun lerp(start: Color, end: Color, fraction: Float): Color {
        return Color(
            red = start.red + (end.red - start.red) * fraction,
            green = start.green + (end.green - start.green) * fraction,
            blue = start.blue + (end.blue - start.blue) * fraction,
            alpha = start.alpha + (end.alpha - start.alpha) * fraction
        )
    }
}

data class DepthMeasurementPoint(
    val x: Double,
    val y: Double,
    val depth: Double,
    val timestamp: Long = System.currentTimeMillis()
)

/**
 * Heat Map View Component
 */
@Composable
fun HeatMapView(
    heatMap: DepthHeatMap,
    minDepth: Double,
    maxDepth: Double,
    modifier: Modifier = Modifier
) {
    var selectedCell by remember { mutableStateOf<Pair<Int, Int>?>(null) }
    var showLegend by remember { mutableStateOf(true) }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "Mappa di Profondità",
                fontFamily = SoraFontFamily,
                fontWeight = FontWeight.Bold,
                fontSize = 18.sp,
                color = Color.White
            )

            IconButton(onClick = { showLegend = !showLegend }) {
                Icon(
                    imageVector = if (showLegend) Icons.Default.Visibility else Icons.Default.VisibilityOff,
                    contentDescription = "Toggle legend",
                    tint = Color.White.copy(alpha = 0.7f)
                )
            }
        }

        // Heat Map Grid
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(1.5f)
                .background(
                    color = Color.Black.copy(alpha = 0.2f),
                    shape = RoundedCornerShape(12.dp)
                )
        ) {
            Canvas(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(8.dp)
            ) {
                val cellWidth = size.width / heatMap.gridSize.columns
                val cellHeight = size.height / heatMap.gridSize.rows

                for (row in 0 until heatMap.gridSize.rows) {
                    for (col in 0 until heatMap.gridSize.columns) {
                        val depth = heatMap.dataPoints[row][col]
                        val color = heatMap.colorForDepth(depth, minDepth, maxDepth)

                        val isSelected = selectedCell?.first == row && selectedCell?.second == col

                        drawRoundRect(
                            color = color,
                            topLeft = Offset(col * cellWidth + 1.dp.toPx(), row * cellHeight + 1.dp.toPx()),
                            size = Size(cellWidth - 2.dp.toPx(), cellHeight - 2.dp.toPx()),
                            cornerRadius = CornerRadius(4.dp.toPx())
                        )

                        // Selected cell border
                        if (isSelected) {
                            drawRoundRect(
                                color = Color.White,
                                topLeft = Offset(col * cellWidth, row * cellHeight),
                                size = Size(cellWidth, cellHeight),
                                cornerRadius = CornerRadius(4.dp.toPx()),
                                style = androidx.compose.ui.graphics.drawscope.Stroke(width = 3.dp.toPx())
                            )
                        }
                    }
                }
            }

            // Selected cell info overlay
            selectedCell?.let { (row, col) ->
                val depth = heatMap.dataPoints[row][col]
                Box(
                    modifier = Modifier
                        .align(Alignment.TopCenter)
                        .padding(top = 16.dp)
                        .background(
                            color = Color.Black.copy(alpha = 0.8f),
                            shape = RoundedCornerShape(8.dp)
                        )
                        .padding(8.dp)
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Text(
                            text = String.format("%.1f mm", depth),
                            fontFamily = SoraFontFamily,
                            fontWeight = FontWeight.Bold,
                            fontSize = 14.sp,
                            color = Color.White
                        )
                        Text(
                            text = "Row $row, Col $col",
                            fontFamily = SoraFontFamily,
                            fontSize = 10.sp,
                            color = Color.White.copy(alpha = 0.8f)
                        )
                    }
                }
            }
        }

        // Legend
        if (showLegend) {
            HeatMapLegend(
                colorScheme = heatMap.colorScheme,
                minValue = minDepth,
                maxValue = maxDepth
            )
        }
    }
}

@Composable
private fun HeatMapLegend(
    colorScheme: DepthHeatMap.HeatMapColorScheme,
    minValue: Double,
    maxValue: Double,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(
                color = Color.Black.copy(alpha = 0.3f),
                shape = RoundedCornerShape(12.dp)
            )
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text(
            text = "Scala Profondità (mm)",
            fontFamily = SoraFontFamily,
            fontWeight = FontWeight.SemiBold,
            fontSize = 12.sp,
            color = Color.White.copy(alpha = 0.8f)
        )

        // Gradient bar
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(20.dp)
                .background(
                    brush = Brush.horizontalGradient(
                        colors = colorScheme.colors
                    ),
                    shape = RoundedCornerShape(10.dp)
                )
        )

        // Min/Max labels
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(
                text = String.format("%.1f", minValue),
                fontFamily = SoraFontFamily,
                fontWeight = FontWeight.Medium,
                fontSize = 11.sp,
                color = Color.White.copy(alpha = 0.7f)
            )

            Text(
                text = String.format("%.1f", (minValue + maxValue) / 2),
                fontFamily = SoraFontFamily,
                fontWeight = FontWeight.Medium,
                fontSize = 11.sp,
                color = Color.White.copy(alpha = 0.7f)
            )

            Text(
                text = String.format("%.1f", maxValue),
                fontFamily = SoraFontFamily,
                fontWeight = FontWeight.Medium,
                fontSize = 11.sp,
                color = Color.White.copy(alpha = 0.7f)
            )
        }
    }
}

/**
 * Interpolated Heat Map View - genera heat map da punti sparsi
 */
@Composable
fun InterpolatedHeatMapView(
    measurements: List<DepthMeasurementPoint>,
    gridSize: Int = 10,
    minDepth: Double,
    maxDepth: Double,
    modifier: Modifier = Modifier
) {
    val heatMap = remember(measurements, gridSize) {
        generateInterpolatedHeatMap(measurements, gridSize)
    }

    HeatMapView(
        heatMap = heatMap,
        minDepth = minDepth,
        maxDepth = maxDepth,
        modifier = modifier
    )
}

private fun generateInterpolatedHeatMap(
    measurements: List<DepthMeasurementPoint>,
    gridSize: Int
): DepthHeatMap {
    val grid = MutableList(gridSize) { MutableList(gridSize) { 0.0 } }

    for (row in 0 until gridSize) {
        for (col in 0 until gridSize) {
            val x = col.toDouble() / (gridSize - 1)
            val y = row.toDouble() / (gridSize - 1)

            grid[row][col] = inverseDistanceWeighting(
                x = x,
                y = y,
                measurements = measurements,
                power = 2.0
            )
        }
    }

    return DepthHeatMap(
        gridSize = DepthHeatMap.GridSize(rows = gridSize, columns = gridSize),
        dataPoints = grid,
        colorScheme = DepthHeatMap.HeatMapColorScheme.THERMAL,
        interpolated = true
    )
}

private fun inverseDistanceWeighting(
    x: Double,
    y: Double,
    measurements: List<DepthMeasurementPoint>,
    power: Double = 2.0
): Double {
    var weightedSum = 0.0
    var weightSum = 0.0

    for (measurement in measurements) {
        val dx = x - measurement.x
        val dy = y - measurement.y
        val distance = sqrt(dx * dx + dy * dy)

        // Avoid division by zero
        if (distance < 0.001) {
            return measurement.depth
        }

        val weight = 1.0 / distance.pow(power)
        weightedSum += weight * measurement.depth
        weightSum += weight
    }

    return if (weightSum > 0) weightedSum / weightSum else 0.0
}

/**
 * Heat Map Statistics Panel
 */
@Composable
fun HeatMapStatisticsPanel(
    heatMap: DepthHeatMap,
    averageDepth: Double,
    minDepth: Double,
    maxDepth: Double,
    standardDeviation: Double,
    measurementCount: Int,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp)
            .background(
                color = Color.Black.copy(alpha = 0.3f),
                shape = RoundedCornerShape(12.dp)
            )
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(
            text = "Statistiche",
            fontFamily = SoraFontFamily,
            fontWeight = FontWeight.Bold,
            fontSize = 16.sp,
            color = Color.White
        )

        Column(
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            StatRow("Profondità Media", String.format("%.2f mm", averageDepth))
            StatRow("Profondità Minima", String.format("%.2f mm", minDepth))
            StatRow("Profondità Massima", String.format("%.2f mm", maxDepth))
            StatRow("Deviazione Standard", String.format("%.2f mm", standardDeviation))
            StatRow("Misurazioni", measurementCount.toString())
        }
    }
}

@Composable
private fun StatRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = label,
            fontFamily = SoraFontFamily,
            fontWeight = FontWeight.Medium,
            fontSize = 13.sp,
            color = Color.White.copy(alpha = 0.7f)
        )

        Text(
            text = value,
            fontFamily = SoraFontFamily,
            fontWeight = FontWeight.SemiBold,
            fontSize = 13.sp,
            color = Color.White
        )
    }
}
