package it.tyrevibes.app.features.tyres

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Posizione pneumatico sul veicolo.
 */
enum class TirePosition(val displayName: String, val shortCode: String) {
    FRONT_LEFT("Front Left", "FL"),
    FRONT_RIGHT("Front Right", "FR"),
    REAR_LEFT("Rear Left", "RL"),
    REAR_RIGHT("Rear Right", "RR")
}

/**
 * Schermata di analisi pneumatico con selezione posizione.
 *
 * Features:
 * - Visualizzazione auto dall'alto (top-down view)
 * - Indicatori cliccabili per ogni pneumatico (FL, FR, RL, RR)
 * - Selezione posizione pneumatico da analizzare
 * - Pulsante "Start Analysis" attivo solo con selezione
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TireAnalysisScreen(
    vehicleMake: String,
    vehicleModel: String,
    tyreBrand: String,
    tyreModel: String,
    tyreSize: String,
    onNavigateBack: () -> Unit,
    onStartAnalysis: (TirePosition) -> Unit
) {
    var selectedTire by remember { mutableStateOf<TirePosition?>(null) }

    Scaffold(
        topBar = {
            TopAppBar(
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(
                            imageVector = Icons.Default.ArrowBack,
                            contentDescription = "Back",
                            tint = Color.White
                        )
                    }
                },
                title = {},
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color(0xFF1C1C1E)
                )
            )
        },
        containerColor = Color.Black
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            // Header info
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp, vertical = 12.dp)
            ) {
                Text(
                    text = "$vehicleMake $vehicleModel",
                    fontSize = 20.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White
                )
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    text = "$tyreBrand $tyreModel • $tyreSize",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium,
                    color = Color.White.copy(alpha = 0.7f)
                )
            }

            Spacer(modifier = Modifier.weight(1f))

            // Car con indicatori pneumatici
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(3f),
                contentAlignment = Alignment.Center
            ) {
                CarTireVisualization(
                    selectedTire = selectedTire,
                    onTireSelected = { selectedTire = it }
                )
            }

            Spacer(modifier = Modifier.weight(1f))

            // Start Analysis Button
            Button(
                onClick = {
                    selectedTire?.let { onStartAnalysis(it) }
                },
                enabled = selectedTire != null,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .padding(bottom = 16.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = if (selectedTire != null) {
                        Color(0xFFFF6B6B)
                    } else {
                        Color.Gray
                    },
                    disabledContainerColor = Color.Gray
                ),
                shape = RoundedCornerShape(25.dp)
            ) {
                Text(
                    text = "Start Analysis",
                    fontWeight = FontWeight.Bold,
                    fontSize = 16.sp,
                    modifier = Modifier.padding(vertical = 12.dp)
                )
            }
        }
    }
}

/**
 * Visualizzazione auto dall'alto con indicatori pneumatici cliccabili.
 */
@Composable
fun CarTireVisualization(
    selectedTire: TirePosition?,
    onTireSelected: (TirePosition) -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .aspectRatio(1f),
        contentAlignment = Alignment.Center
    ) {
        // Car body (semplificato - rettangolo con angoli arrotondati)
        Canvas(
            modifier = Modifier
                .fillMaxWidth(0.5f)
                .aspectRatio(0.4f)
        ) {
            val width = size.width
            val height = size.height

            // Car body
            drawRoundRect(
                color = Color.Gray,
                size = size,
                cornerRadius = androidx.compose.ui.geometry.CornerRadius(20f, 20f),
                style = Stroke(width = 4f)
            )

            // Windows (optional)
            drawRoundRect(
                color = Color.Gray.copy(alpha = 0.3f),
                topLeft = Offset(width * 0.15f, height * 0.15f),
                size = androidx.compose.ui.geometry.Size(width * 0.7f, height * 0.3f),
                cornerRadius = androidx.compose.ui.geometry.CornerRadius(10f, 10f)
            )
        }

        // Tire Indicators
        Box(modifier = Modifier.fillMaxSize()) {
            // Front Left
            TireIndicator(
                position = TirePosition.FRONT_LEFT,
                isSelected = selectedTire == TirePosition.FRONT_LEFT,
                onClick = { onTireSelected(TirePosition.FRONT_LEFT) },
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .offset(x = 40.dp, y = 100.dp)
            )

            // Front Right
            TireIndicator(
                position = TirePosition.FRONT_RIGHT,
                isSelected = selectedTire == TirePosition.FRONT_RIGHT,
                onClick = { onTireSelected(TirePosition.FRONT_RIGHT) },
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .offset(x = (-40).dp, y = 100.dp)
            )

            // Rear Left
            TireIndicator(
                position = TirePosition.REAR_LEFT,
                isSelected = selectedTire == TirePosition.REAR_LEFT,
                onClick = { onTireSelected(TirePosition.REAR_LEFT) },
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .offset(x = 40.dp, y = (-100).dp)
            )

            // Rear Right
            TireIndicator(
                position = TirePosition.REAR_RIGHT,
                isSelected = selectedTire == TirePosition.REAR_RIGHT,
                onClick = { onTireSelected(TirePosition.REAR_RIGHT) },
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .offset(x = (-40).dp, y = (-100).dp)
            )
        }
    }
}

/**
 * Indicatore singolo pneumatico cliccabile.
 */
@Composable
fun TireIndicator(
    position: TirePosition,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .size(60.dp)
            .background(
                color = if (isSelected) Color(0xFFFF6B6B) else Color(0xFF2C2C2E),
                shape = CircleShape
            )
            .border(
                width = 2.dp,
                color = if (isSelected) Color(0xFFFF6B6B) else Color.Gray,
                shape = CircleShape
            )
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        if (isSelected) {
            Icon(
                imageVector = Icons.Default.CheckCircle,
                contentDescription = "Selected",
                tint = Color.White,
                modifier = Modifier.size(32.dp)
            )
        } else {
            Text(
                text = position.shortCode,
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
        }
    }
}
