package it.tyrevibes.app.features.garage

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import it.tyrevibes.app.core.viewmodel.GarageViewModel
import it.tyrevibes.app.core.viewmodel.VehicleResponse
import it.tyrevibes.app.ui.components.LoadingScreen

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GarageScreen(
    viewModel: GarageViewModel = GarageViewModel(LocalContext.current),
    onNavigateToAddVehicle: () -> Unit = {},
    onNavigateToVehicleDetails: (Int) -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("I Miei Veicoli") },
                actions = {
                    IconButton(onClick = { viewModel.fetchCars() }) {
                        Icon(Icons.Default.Add, contentDescription = "Aggiungi veicolo")
                    }
                }
            )
        },
        floatingActionButton = {
            FloatingActionButton(onClick = onNavigateToAddVehicle) {
                Icon(Icons.Default.Add, contentDescription = "Aggiungi veicolo")
            }
        }
    ) { paddingValues ->
        when {
            uiState.isLoading -> LoadingScreen()
            uiState.vehicles.isEmpty() -> EmptyGarageView(onNavigateToAddVehicle)
            else -> VehicleList(
                vehicles = uiState.vehicles,
                onVehicleClick = { vehicle ->
                    onNavigateToVehicleDetails(vehicle.vehicle.id)
                },
                onDeleteVehicle = viewModel::deleteCar,
                modifier = Modifier.padding(paddingValues)
            )
        }

        // Error Snackbar
        uiState.errorMessage?.let { error ->
            LaunchedEffect(error) {
                // TODO: Show Snackbar
                viewModel.clearError()
            }
        }
    }
}

@Composable
fun VehicleList(
    vehicles: List<VehicleResponse>,
    onVehicleClick: (VehicleResponse) -> Unit,
    onDeleteVehicle: (it.tyrevibes.app.core.model.Vehicle) -> Unit,
    modifier: Modifier = Modifier
) {
    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
        contentPadding = PaddingValues(vertical = 16.dp)
    ) {
        items(vehicles) { vehicleResponse ->
            VehicleCard(
                vehicleResponse = vehicleResponse,
                onClick = { onVehicleClick(vehicleResponse) },
                onDelete = { onDeleteVehicle(vehicleResponse.vehicle) }
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VehicleCard(
    vehicleResponse: VehicleResponse,
    onClick: () -> Unit,
    onDelete: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() },
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                Icons.Default.DirectionsCar,
                contentDescription = null,
                modifier = Modifier.size(48.dp),
                tint = MaterialTheme.colorScheme.primary
            )

            Spacer(modifier = Modifier.width(16.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "${vehicleResponse.vehicle.make ?: ""} ${vehicleResponse.vehicle.model ?: ""}",
                    style = MaterialTheme.typography.titleMedium
                )
                vehicleResponse.plate?.plateNumber?.let {
                    Text(
                        text = it,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}

@Composable
fun EmptyGarageView(onAddVehicle: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            Icons.Default.DirectionsCar,
            contentDescription = null,
            modifier = Modifier.size(120.dp),
            tint = MaterialTheme.colorScheme.primary.copy(alpha = 0.5f)
        )

        Spacer(modifier = Modifier.height(24.dp))

        Text(
            text = "Nessun Veicolo",
            style = MaterialTheme.typography.headlineSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = "Aggiungi il tuo primo veicolo per iniziare",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Spacer(modifier = Modifier.height(32.dp))

        Button(onClick = onAddVehicle) {
            Icon(Icons.Default.Add, contentDescription = null)
            Spacer(modifier = Modifier.width(8.dp))
            Text("Aggiungi Veicolo")
        }
    }
}
