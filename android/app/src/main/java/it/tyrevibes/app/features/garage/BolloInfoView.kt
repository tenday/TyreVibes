package it.tyrevibes.app.features.garage

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import it.tyrevibes.app.core.helper.BolloCalculator
import it.tyrevibes.app.core.model.PlateData

/**
 * Vista informazioni bollo auto (tassa di circolazione italiana).
 *
 * Features:
 * - Calcolo automatico con BolloCalculator
 * - Breakdown: Base + Superbollo
 * - Classe emissione e tariffa applicata
 * - Autenticazione SPID per info ufficiali (TODO)
 * - Data scadenza e stato pagamento (TODO)
 */
@Composable
fun BolloInfoView(
    plateData: PlateData?,
    isHistoricVehicle: Boolean = false,
    onAuthenticateSPID: (() -> Unit)? = null
) {
    var isAuthenticated by remember { mutableStateOf(false) }
    var isLoading by remember { mutableStateOf(false) }

    // Calcola bollo se abbiamo i dati
    val bolloResult = remember(plateData) {
        plateData?.let {
            BolloCalculator.calculateBollo(it, isHistoricVehicle = isHistoricVehicle)
        }
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                color = Color(0xFF2C2C2E),
                shape = RoundedCornerShape(14.dp)
            )
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Header
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(
                imageVector = Icons.Default.Info,
                contentDescription = "Info",
                tint = Color(0xFF0066FF),
                modifier = Modifier.size(18.dp)
            )
            Text(
                text = "Bollo Auto Information",
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.White
            )
        }

        if (bolloResult != null) {
            // Calculated bollo info
            Column(
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                // Total amount (prominent)
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(
                        containerColor = Color(0xFFFF6B6B).copy(alpha = 0.2f)
                    ),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(
                            text = "Total Amount",
                            fontSize = 14.sp,
                            color = Color.Gray
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = "€ ${String.format("%.2f", bolloResult.total)}",
                            fontSize = 32.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                    }
                }

                // Breakdown
                BolloInfoRow(label = "Base Bollo", value = "€ ${String.format("%.2f", bolloResult.baseBollo)}")
                BolloInfoRow(label = "Superbollo", value = "€ ${String.format("%.2f", bolloResult.superBollo)}")
                Divider(color = Color.Gray.copy(alpha = 0.3f))
                BolloInfoRow(label = "Emission Class", value = bolloResult.emissionClassDescription)
                BolloInfoRow(label = "Taxable Power", value = "${String.format("%.1f", bolloResult.taxablePowerKW)} kW")

                Spacer(modifier = Modifier.height(8.dp))

                // Rate info
                Text(
                    text = "Applied Rate",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White
                )
                BolloInfoRow(label = "Up to 100 kW", value = "€ ${String.format("%.2f", bolloResult.appliedRates.upTo100kW)}/kW")
                BolloInfoRow(label = "Over 100 kW", value = "€ ${String.format("%.2f", bolloResult.appliedRates.over100kW)}/kW")
            }

            // SPID authentication prompt
            if (!isAuthenticated) {
                Spacer(modifier = Modifier.height(8.dp))
                Button(
                    onClick = { onAuthenticateSPID?.invoke() },
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color(0xFF0066FF)
                    ),
                    shape = RoundedCornerShape(10.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Shield,
                        contentDescription = "SPID",
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "Accedi con SPID per info ufficiali",
                        fontSize = 14.sp
                    )
                }
            }
        } else {
            // No data available
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Info,
                    contentDescription = "No data",
                    tint = Color.Gray,
                    modifier = Modifier.size(40.dp)
                )
                Text(
                    text = "No vehicle data available",
                    fontSize = 14.sp,
                    color = Color.Gray
                )
                Text(
                    text = "Add vehicle plate information to calculate bollo",
                    fontSize = 12.sp,
                    color = Color.Gray.copy(alpha = 0.7f)
                )
            }
        }

        // Historic vehicle exemption
        if (isHistoricVehicle) {
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = Color.Green.copy(alpha = 0.2f)
                ),
                shape = RoundedCornerShape(10.dp)
            ) {
                Row(
                    modifier = Modifier.padding(12.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(text = "✓", fontSize = 20.sp, color = Color.Green)
                    Text(
                        text = "Veicolo storico - Esente da bollo",
                        fontSize = 14.sp,
                        color = Color.White
                    )
                }
            }
        }
    }
}

@Composable
fun BolloInfoRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = label,
            fontSize = 14.sp,
            color = Color.Gray
        )
        Text(
            text = value,
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
            color = Color.White
        )
    }
}
