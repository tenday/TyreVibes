package it.tyrevibes.app.features.analysis

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import it.tyrevibes.app.core.viewmodel.SurfaceAnalysisData

/**
 * Schermata analisi superficie pneumatico.
 *
 * Features:
 * - Visualizzazione dati analisi (veicolo, misura, marca, DOT, modello)
 * - Immagine pneumatico con overlay dati
 * - Descrizione condizione con icona warning/info
 * - Export PDF con PDFReportBuilder
 * - Misurazione battistrada con camera
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SurfaceAnalysisScreen(
    analysisData: SurfaceAnalysisData,
    onNavigateBack: () -> Unit,
    onExportPDF: () -> Unit,
    onMeasureTread: () -> Unit
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Surface Analysis",
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold,
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
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color(0xFF1E1E1E)
                )
            )
        },
        containerColor = Color(0xFF1E1E1E)
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .verticalScroll(rememberScrollState())
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            // Vehicle name header
            Text(
                text = analysisData.vehicleName,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                color = Color(0xFFF26440)
            )

            // Tire image with overlay data
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(250.dp)
                    .background(
                        color = Color(0xFF2C2C2E),
                        shape = RoundedCornerShape(10.dp)
                    )
            ) {
                // TODO: Immagine reale pneumatico
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "[Tire Image]",
                        color = Color.Gray,
                        fontSize = 14.sp
                    )
                }

                // Overlay with tire details
                Column(
                    modifier = Modifier
                        .align(Alignment.BottomStart)
                        .background(
                            color = Color.Black.copy(alpha = 0.6f),
                            shape = RoundedCornerShape(10.dp)
                        )
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    InfoRow(label = "Tire Size:", value = analysisData.tireSize)
                    InfoRow(label = "Tire Make:", value = analysisData.tireMake)
                    InfoRow(label = "Manufacture Date:", value = analysisData.manufactureDate)
                    InfoRow(label = "Model:", value = analysisData.model)
                }
            }

            // Condition Card
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = Color(0xFF2C2C2E)
                ),
                shape = RoundedCornerShape(10.dp)
            ) {
                Row(
                    modifier = Modifier.padding(16.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Condition icon
                    Icon(
                        painter = painterResource(
                            id = android.R.drawable.ic_dialog_alert
                        ),
                        contentDescription = "Condition",
                        tint = Color(0xFFFFA500),
                        modifier = Modifier.size(32.dp)
                    )

                    Column {
                        Text(
                            text = "Condition",
                            fontSize = 14.sp,
                            color = Color.Gray
                        )
                        Text(
                            text = analysisData.conditionDescription,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = Color.White
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(10.dp))

            // Action Buttons
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                // Export PDF
                Button(
                    onClick = onExportPDF,
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color(0xFF2C2C2E)
                    ),
                    shape = RoundedCornerShape(10.dp)
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.padding(vertical = 12.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Download,
                            contentDescription = "Export",
                            tint = Color.White
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text("Export PDF", fontSize = 12.sp)
                    }
                }

                // Measure Tread
                Button(
                    onClick = onMeasureTread,
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color(0xFFFF6B6B)
                    ),
                    shape = RoundedCornerShape(10.dp)
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.padding(vertical = 12.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.PhotoCamera,
                            contentDescription = "Measure",
                            tint = Color.White
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text("Measure Tread", fontSize = 12.sp)
                    }
                }
            }
        }
    }
}

@Composable
private fun InfoRow(label: String, value: String) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text(
            text = label,
            fontSize = 14.sp,
            color = Color.Gray
        )
        Text(
            text = value,
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium,
            color = Color.White
        )
    }
}
