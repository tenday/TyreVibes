package it.tyrevibes.app.features.garage

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Tipo di set pneumatici.
 */
enum class TyreSetType(val displayName: String, val description: String, val icon: String) {
    FRONT_REAR("Anteriore/Posteriore", "Per veicoli con misure diverse davanti e dietro", "directions_car"),
    SUMMER("Set Estivo", "Pneumatici estivi ad alte prestazioni", "wb_sunny"),
    WINTER("Set Invernale", "Pneumatici invernali per sicurezza", "ac_unit"),
    TRACK("Set Pista", "Pneumatici specifici per uso in pista", "flag"),
    CUSTOM("Personalizzato", "Configura un set personalizzato", "edit")
}

/**
 * Schermata aggiunta set pneumatici.
 *
 * Features:
 * - Selezione tipo set (Estivo, Invernale, Anteriore/Posteriore, Pista, Custom)
 * - Nome set personalizzabile
 * - Configurazione pneumatici anteriori/posteriori
 * - Integrazione OCR per scansione
 * - Preview set consigliati dal veicolo
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddTyreSetView(
    vehicleId: Int,
    onDismiss: () -> Unit,
    onSaveSet: (String, TyreSetType, Boolean) -> Unit
) {
    var selectedType by remember { mutableStateOf(TyreSetType.FRONT_REAR) }
    var setName by remember { mutableStateOf("") }
    var includeRearTyre by remember { mutableStateOf(true) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Add Tyre Set",
                        fontSize = 18.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color(0xFF1C1C1E),
                    titleContentColor = Color.White
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
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            // Set Type Selection
            Text(
                text = "Select Set Type",
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.White
            )

            TyreSetType.values().forEach { type ->
                TyreSetTypeCard(
                    type = type,
                    isSelected = selectedType == type,
                    onClick = { selectedType = type }
                )
            }

            Spacer(modifier = Modifier.height(10.dp))

            // Set Name
            Text(
                text = "Set Name",
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.White
            )

            OutlinedTextField(
                value = setName,
                onValueChange = { setName = it },
                modifier = Modifier.fillMaxWidth(),
                placeholder = {
                    Text("e.g. ${selectedType.displayName}", color = Color.Gray)
                },
                colors = TextFieldDefaults.outlinedTextFieldColors(
                    focusedTextColor = Color.White,
                    unfocusedTextColor = Color.White,
                    focusedBorderColor = Color(0xFFFF6B6B),
                    unfocusedBorderColor = Color.Gray
                )
            )

            // Include Rear Tyre Toggle
            if (selectedType == TyreSetType.FRONT_REAR) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(
                            color = Color(0xFF2C2C2E),
                            shape = RoundedCornerShape(14.dp)
                        )
                        .padding(16.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(
                            text = "Include Rear Tyre",
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Medium,
                            color = Color.White
                        )
                        Text(
                            text = "Different size for rear axle",
                            fontSize = 14.sp,
                            color = Color.Gray
                        )
                    }
                    Switch(
                        checked = includeRearTyre,
                        onCheckedChange = { includeRearTyre = it },
                        colors = SwitchDefaults.colors(
                            checkedThumbColor = Color.White,
                            checkedTrackColor = Color(0xFFFF6B6B)
                        )
                    )
                }
            }

            // TODO: Scan Tyre Button (OCR Integration)
            Button(
                onClick = { /* Navigate to TireRegistrationScreen */ },
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color(0xFF2C2C2E)
                ),
                shape = RoundedCornerShape(14.dp)
            ) {
                Text(
                    text = "Scan Tyre with Camera",
                    modifier = Modifier.padding(vertical = 12.dp)
                )
            }

            Spacer(modifier = Modifier.weight(1f))

            // Save Button
            Button(
                onClick = {
                    val finalName = setName.ifEmpty { selectedType.displayName }
                    onSaveSet(finalName, selectedType, includeRearTyre)
                    onDismiss()
                },
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color(0xFFFF6B6B)
                ),
                shape = RoundedCornerShape(25.dp)
            ) {
                Text(
                    text = "Save Set",
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(vertical = 12.dp)
                )
            }
        }
    }
}

@Composable
fun TyreSetTypeCard(
    type: TyreSetType,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                color = if (isSelected) Color(0xFFFF6B6B).copy(alpha = 0.2f) else Color(0xFF2C2C2E),
                shape = RoundedCornerShape(14.dp)
            )
            .clickable(onClick = onClick)
            .padding(16.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = type.displayName,
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.White
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = type.description,
                fontSize = 14.sp,
                color = Color.Gray
            )
        }

        if (isSelected) {
            Icon(
                imageVector = Icons.Default.Check,
                contentDescription = "Selected",
                tint = Color(0xFFFF6B6B),
                modifier = Modifier.size(24.dp)
            )
        }
    }
}
