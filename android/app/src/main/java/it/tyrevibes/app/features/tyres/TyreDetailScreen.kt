package it.tyrevibes.app.features.tyres

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Download
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Dati mockup per TyreRegistered.
 * TODO: Sostituire con modello reale da database/API
 */
data class TyreRegistered(
    val id: Int,
    val vehicleId: Int,
    val brand: String,
    val model: String,
    val size: String,
    val dot: String,
    val loadIndex: String,
    val speedRating: String,
    val season: String
)

/**
 * Punto dati per il grafico lifecycle.
 */
data class ChartDataPoint(
    val distance: Int,
    val depth: Double,
    val isProjected: Boolean = false
)

/**
 * Schermata dettaglio pneumatico.
 *
 * Mostra:
 * - Informazioni pneumatico (marca, modello, stagione, DOT)
 * - Visualizzazione pneumatico 3D
 * - Card profondità battistrada per ogni posizione (FL, FR, RL, RR)
 * - Vita residua con progress bar
 * - Grafico lifecycle (storico + proiezione)
 * - Condizione pneumatico con barre verticali
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TyreDetailScreen(
    tyre: TyreRegistered,
    onNavigateBack: () -> Unit
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "${tyre.brand} ${tyre.model}",
                        fontSize = 18.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(
                            imageVector = Icons.Default.ArrowBack,
                            contentDescription = "Back",
                            tint = Color.White
                        )
                    }
                },
                actions = {
                    IconButton(onClick = { /* TODO: Export/Share */ }) {
                        Icon(
                            imageVector = Icons.Default.Download,
                            contentDescription = "Download",
                            tint = Color.White
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color(0xFF1C1C1E)
                )
            )
        },
        containerColor = Color(0xFF000000)
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .verticalScroll(rememberScrollState())
        ) {
            // Header con info pneumatico
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 20.dp)
            ) {
                InfoRow(label = "Make", value = tyre.brand)
                Spacer(modifier = Modifier.height(16.dp))
                InfoRow(label = "Model", value = tyre.model)
                Spacer(modifier = Modifier.height(16.dp))
                InfoRow(label = "Season", value = tyre.season)
                Spacer(modifier = Modifier.height(16.dp))
                InfoRow(label = "DOT", value = tyre.dot)
            }

            // TODO: Visualizzazione pneumatico 3D
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(200.dp)
                    .padding(vertical = 20.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "[Tyre 3D Visualization]",
                    color = Color.Gray,
                    fontSize = 14.sp
                )
            }

            // Card profondità battistrada
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp),
                horizontalArrangement = Arrangement.spacedBy(40.dp)
            ) {
                TreadDepthCard(
                    position = "FL",
                    depth = "7.2 mm",
                    progress = 0.9f,
                    color = Color.Green,
                    modifier = Modifier.weight(1f)
                )
                TreadDepthCard(
                    position = "FR",
                    depth = "7.2 mm",
                    progress = 0.9f,
                    color = Color.Green,
                    modifier = Modifier.weight(1f)
                )
            }

            Spacer(modifier = Modifier.height(20.dp))

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp),
                horizontalArrangement = Arrangement.spacedBy(40.dp)
            ) {
                TreadDepthCard(
                    position = "RL",
                    depth = "4.0 mm",
                    progress = 0.5f,
                    color = Color(0xFFFFA500), // Orange
                    modifier = Modifier.weight(1f)
                )
                TreadDepthCard(
                    position = "RR",
                    depth = "2.5 mm",
                    progress = 0.25f,
                    color = Color.Red,
                    modifier = Modifier.weight(1f)
                )
            }

            Spacer(modifier = Modifier.height(30.dp))

            // Vita residua
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp)
                    .background(
                        color = Color(0xFF2C2C2E),
                        shape = RoundedCornerShape(14.dp)
                    )
                    .padding(16.dp)
            ) {
                Text(
                    text = "Remaining Life",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Medium,
                    color = Color.Gray
                )
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = "80%",
                    fontSize = 28.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
                Spacer(modifier = Modifier.height(8.dp))
                LinearProgressIndicator(
                    progress = 0.8f,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(12.dp),
                    color = Color.Cyan,
                    trackColor = Color.Gray.copy(alpha = 0.3f)
                )
            }

            Spacer(modifier = Modifier.height(30.dp))

            // TODO: Grafico Lifecycle (Swift Charts -> Vico/MPAndroidChart)
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp)
                    .background(
                        color = Color(0xFF2C2C2E),
                        shape = RoundedCornerShape(14.dp)
                    )
                    .padding(16.dp)
            ) {
                Text(
                    text = "Tire Lifecycle",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White
                )
                Spacer(modifier = Modifier.height(16.dp))
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(200.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "[Lifecycle Chart - Historical + Projected]",
                        color = Color.Gray,
                        fontSize = 14.sp
                    )
                }
            }

            Spacer(modifier = Modifier.height(30.dp))

            // TODO: Condizione pneumatico con barre verticali
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp)
                    .background(
                        color = Color(0xFF2C2C2E),
                        shape = RoundedCornerShape(14.dp)
                    )
                    .padding(16.dp)
            ) {
                Text(
                    text = "Tire Condition",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White
                )
                Spacer(modifier = Modifier.height(16.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceEvenly
                ) {
                    TireConditionBar(position = "FL", percentage = 70, color = Color.Green)
                    TireConditionBar(position = "FR", percentage = 80, color = Color.Green)
                    TireConditionBar(position = "RL", percentage = 50, color = Color(0xFFFFA500))
                    TireConditionBar(position = "RR", percentage = 35, color = Color.Red)
                }
            }

            Spacer(modifier = Modifier.height(30.dp))
        }
    }
}

@Composable
fun InfoRow(label: String, value: String) {
    Column {
        Text(
            text = label,
            fontSize = 16.sp,
            fontWeight = FontWeight.SemiBold,
            color = Color.Gray
        )
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = value,
            fontSize = 18.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )
    }
}

@Composable
fun TreadDepthCard(
    position: String,
    depth: String,
    progress: Float,
    color: Color,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .background(
                color = Color(0xFF2C2C2E),
                shape = RoundedCornerShape(14.dp)
            )
            .padding(16.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(
                text = "Tread Depth",
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                color = Color.Gray
            )
            Text(
                text = position,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.White
            )
        }
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = depth,
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )
        Spacer(modifier = Modifier.height(8.dp))
        LinearProgressIndicator(
            progress = progress,
            modifier = Modifier
                .fillMaxWidth()
                .height(12.dp),
            color = color,
            trackColor = Color.Gray.copy(alpha = 0.3f)
        )
    }
}

@Composable
fun TireConditionBar(position: String, percentage: Int, color: Color) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Box(
            modifier = Modifier
                .width(26.dp)
                .height(80.dp),
            contentAlignment = Alignment.BottomCenter
        ) {
            Column(
                modifier = Modifier
                    .width(26.dp)
                    .height((80 * (percentage / 100f)).dp)
                    .background(color, RoundedCornerShape(6.dp)),
                verticalArrangement = Arrangement.Top,
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = "$percentage%",
                    fontSize = 10.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White,
                    modifier = Modifier.padding(top = 6.dp)
                )
            }
        }
        Text(
            text = position,
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
            color = Color.White
        )
    }
}
