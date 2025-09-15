package com.tyrevibes.android.features.licenseplate

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.*
import androidx.compose.ui.unit.sp
import com.tyrevibes.android.features.garage.VehicleResponse
import com.tyrevibes.android.ui.theme.CustomBackgroundColor

@Composable
fun CheckDetailsScreen(
    viewModel: PlateViewModel,
    vehicleData: VehicleResponse,
    onNavigateBack: () -> Unit,
    onConfirm: () -> Unit
) {
    var selectedColor by remember { mutableStateOf(Color.Black) }
    val uiState by viewModel.uiState.collectAsState()

    LaunchedEffect(uiState) {
        if (uiState is PlateUiState.Success) {
            // This will be triggered after saving is also a "Success"
            // The navigation is handled in MainScreen, but we could add a toast here.
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(CustomBackgroundColor)
            .padding(16.dp)
    ) {
        IconButton(onClick = onNavigateBack) {
            Icon(Icons.Default.ArrowBack, contentDescription = "Back", tint = Color.White)
        }
        Text(
            text = "Check Details",
            fontSize = 32.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )
        Spacer(modifier = Modifier.height(24.dp))

        // Display Vehicle Details
        DetailRow(label = "Make", value = vehicleData.vehicle.make)
        DetailRow(label = "Model", value = vehicleData.vehicle.model)
        DetailRow(label = "Plate", value = vehicleData.plate?.plateNumber)
        DetailRow(label = "Year", value = vehicleData.plate?.year?.toString())
        DetailRow(label = "Fuel Type", value = vehicleData.vehicle.fuelType)

        Spacer(modifier = Modifier.height(24.dp))

        // Color Picker
        Text("Select Color:", color = Color.White, fontWeight = FontWeight.Bold)
        Spacer(modifier = Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            val colors = listOf(Color.Black, Color.White, Color.Gray, Color.Red, Color.Blue)
            colors.forEach { color ->
                Box(
                    modifier = Modifier
                        .size(40.dp)
                        .background(color, CircleShape)
                        .clickable { selectedColor = color }
                        .border(
                            width = 2.dp,
                            color = if (selectedColor == color) Color.Yellow else Color.Transparent,
                            shape = CircleShape
                        )
                )
            }
        }

        Spacer(modifier = Modifier.weight(1f))

        Button(
            onClick = {
                // For simplicity, converting compose color to a string name.
                val colorName = when (selectedColor) {
                    Color.Black -> "Black"
                    Color.White -> "White"
                    Color.Gray -> "Gray"
                    Color.Red -> "Red"
                    Color.Blue -> "Blue"
                    else -> "Custom"
                }
                viewModel.saveVehicle(vehicleData, colorName)
                onConfirm() // Trigger navigation
            },
            modifier = Modifier.fillMaxWidth().height(60.dp),
            enabled = uiState !is PlateUiState.Loading
        ) {
            if (uiState is PlateUiState.Loading) {
                CircularProgressIndicator()
            } else {
                Text("Confirm and Add to Garage")
            }
        }
    }
}

@Composable
fun DetailRow(label: String, value: String?) {
    Row(modifier = Modifier.padding(vertical = 8.dp)) {
        Text(
            text = "$label:",
            fontWeight = FontWeight.Bold,
            color = Color.White,
            modifier = Modifier.width(120.dp)
        )
        Text(text = value ?: "N/A", color = Color.LightGray)
    }
}
