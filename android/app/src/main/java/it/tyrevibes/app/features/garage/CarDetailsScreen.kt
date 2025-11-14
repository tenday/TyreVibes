package it.tyrevibes.app.features.garage

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import it.tyrevibes.app.core.model.Vehicle
import it.tyrevibes.app.ui.components.LicensePlateComponent
import it.tyrevibes.app.ui.theme.SoraFontFamily

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CarDetailsScreen(
    vehicle: Vehicle,
    onNavigateBack: () -> Unit,
    onEditVehicle: () -> Unit,
    onDeleteVehicle: () -> Unit,
    onViewTyres: () -> Unit,
    onViewReports: () -> Unit
) {
    var showDeleteDialog by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Dettagli Veicolo") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Indietro")
                    }
                },
                actions = {
                    IconButton(onClick = onEditVehicle) {
                        Icon(Icons.Default.Edit, contentDescription = "Modifica")
                    }
                    IconButton(onClick = { showDeleteDialog = true }) {
                        Icon(
                            Icons.Default.Delete,
                            contentDescription = "Elimina",
                            tint = Color(0xFFFF3B30)
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Transparent
                )
            )
        },
        containerColor = Color(0xFF121212)
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
        ) {
            Spacer(modifier = Modifier.height(20.dp))

            // Vehicle Image Placeholder
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(200.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(
                        brush = Brush.verticalGradient(
                            colors = listOf(
                                Color(0xFF007AFF).copy(alpha = 0.3f),
                                Color(0xFF007AFF).copy(alpha = 0.1f)
                            )
                        )
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.DirectionsCar,
                    contentDescription = null,
                    tint = Color.White.copy(alpha = 0.5f),
                    modifier = Modifier.size(100.dp)
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Vehicle Title
            Text(
                text = "${vehicle.make ?: ""} ${vehicle.model ?: ""}",
                fontFamily = SoraFontFamily,
                fontWeight = FontWeight.Bold,
                fontSize = 24.sp,
                color = Color.White
            )

            vehicle.modelDetail?.let { detail ->
                Text(
                    text = detail,
                    fontFamily = SoraFontFamily,
                    fontSize = 16.sp,
                    color = Color.White.copy(alpha = 0.7f)
                )
            }

            Spacer(modifier = Modifier.height(16.dp))

            // License Plate
            vehicle.plate?.plateNumber?.let { plateNumber ->
                LicensePlateComponent(
                    text = plateNumber,
                    modifier = Modifier.align(Alignment.CenterHorizontally)
                )
            }

            Spacer(modifier = Modifier.height(32.dp))

            // Quick Actions
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                QuickActionButton(
                    icon = Icons.Default.SportsSoccer,
                    label = "Pneumatici",
                    onClick = onViewTyres,
                    modifier = Modifier.weight(1f)
                )

                QuickActionButton(
                    icon = Icons.Default.Assessment,
                    label = "Report",
                    onClick = onViewReports,
                    modifier = Modifier.weight(1f)
                )
            }

            Spacer(modifier = Modifier.height(32.dp))

            // Vehicle Specs Section
            SectionTitle("Specifiche Tecniche")

            Spacer(modifier = Modifier.height(16.dp))

            vehicle.fuelType?.let { fuel ->
                SpecRow("Alimentazione", fuel)
            }

            vehicle.powerKW?.let { power ->
                SpecRow("Potenza", "$power kW")
            }

            vehicle.displacementCC?.let { displacement ->
                SpecRow("Cilindrata", "$displacement cc")
            }

            vehicle.emissionClass?.let { emission ->
                SpecRow("Classe Emissioni", emission)
            }

            vehicle.registrationDate?.let { date ->
                SpecRow("Data Immatricolazione", date)
            }

            vehicle.vin?.let { vin ->
                SpecRow("VIN", vin)
            }

            Spacer(modifier = Modifier.height(32.dp))

            // Insurance Section (if present)
            vehicle.insurance?.let { insurance ->
                if (insurance.rcaInsurancePresent == 1) {
                    SectionTitle("Assicurazione")
                    Spacer(modifier = Modifier.height(16.dp))

                    insurance.rcaCompany?.let { company ->
                        SpecRow("Compagnia", company)
                    }

                    insurance.rcaExpiry?.let { expiry ->
                        SpecRow("Scadenza", expiry)
                    }

                    Spacer(modifier = Modifier.height(32.dp))
                }
            }

            Spacer(modifier = Modifier.height(20.dp))
        }
    }

    // Delete confirmation dialog
    if (showDeleteDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteDialog = false },
            title = {
                Text(
                    text = "Elimina Veicolo",
                    fontFamily = SoraFontFamily,
                    fontWeight = FontWeight.Bold
                )
            },
            text = {
                Text(
                    text = "Sei sicuro di voler eliminare questo veicolo? Questa azione non può essere annullata.",
                    fontFamily = SoraFontFamily
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        showDeleteDialog = false
                        onDeleteVehicle()
                    }
                ) {
                    Text("Elimina", color = Color(0xFFFF3B30))
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteDialog = false }) {
                    Text("Annulla")
                }
            }
        )
    }
}

@Composable
private fun QuickActionButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Button(
        onClick = onClick,
        modifier = modifier.height(80.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = Color(0xFF1F1F1F)
        ),
        shape = RoundedCornerShape(12.dp)
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = Color(0xFF007AFF),
                modifier = Modifier.size(32.dp)
            )
            Text(
                text = label,
                fontFamily = SoraFontFamily,
                fontSize = 14.sp,
                color = Color.White
            )
        }
    }
}

@Composable
private fun SectionTitle(title: String) {
    Text(
        text = title,
        fontFamily = SoraFontFamily,
        fontWeight = FontWeight.Bold,
        fontSize = 18.sp,
        color = Color.White
    )
}

@Composable
private fun SpecRow(label: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = label,
            fontFamily = SoraFontFamily,
            fontSize = 14.sp,
            color = Color.White.copy(alpha = 0.6f)
        )
        Text(
            text = value,
            fontFamily = SoraFontFamily,
            fontWeight = FontWeight.Medium,
            fontSize = 14.sp,
            color = Color.White
        )
    }
}
