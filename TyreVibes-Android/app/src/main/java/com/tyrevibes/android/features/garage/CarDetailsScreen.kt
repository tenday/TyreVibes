package com.tyrevibes.android.features.garage

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.tyrevibes.android.features.licenseplate.DetailRow
import com.tyrevibes.android.ui.theme.CustomBackgroundColor

@Composable
fun CarDetailsScreen(
    vehicle: VehicleResponse,
    onNavigateBack: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(CustomBackgroundColor)
            .padding(16.dp)
    ) {
        // Header
        Row {
            IconButton(onClick = onNavigateBack) {
                Icon(Icons.Default.ArrowBack, contentDescription = "Back", tint = Color.White)
            }
            Text(
                text = "${vehicle.vehicle.make} ${vehicle.vehicle.model}",
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Details List
        LazyColumn {
            item { DetailRow(label = "Plate", value = vehicle.plate?.plateNumber) }
            item { DetailRow(label = "Year", value = vehicle.plate?.year?.toString()) }
            item { DetailRow(label = "Model Detail", value = vehicle.vehicle.modelDetail) }
            item { DetailRow(label = "Engine", value = vehicle.vehicle.engine) }
            item { DetailRow(label = "Fuel Type", value = vehicle.vehicle.fuelType) }
            item { DetailRow(label = "Power (CV)", value = vehicle.vehicle.powerCV?.toString()) }
            item { DetailRow(label = "Power (KW)", value = vehicle.vehicle.powerKW) }
            item { DetailRow(label = "Gearbox", value = vehicle.vehicle.gearbox) }
            item { DetailRow(label = "Color", value = vehicle.vehicle.color) }
            item { DetailRow(label = "VIN", value = vehicle.vehicle.vin) }
        }
    }
}
