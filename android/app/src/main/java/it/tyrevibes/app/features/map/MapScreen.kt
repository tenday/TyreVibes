package it.tyrevibes.app.features.map

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.*
import it.tyrevibes.app.core.service.LocationManager
import kotlinx.coroutines.launch

data class TyreShop(
    val id: String,
    val name: String,
    val address: String,
    val position: LatLng,
    val rating: Float,
    val distance: Float, // in meters
    val phone: String? = null,
    val isOpen: Boolean = true
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MapScreen(
    onNavigateBack: () -> Unit = {}
) {
    val context = LocalContext.current
    val locationManager = remember { LocationManager(context) }
    val scope = rememberCoroutineScope()

    var currentLocation by remember { mutableStateOf<LatLng?>(null) }
    var nearbyShops by remember { mutableStateOf<List<TyreShop>>(emptyList()) }
    var selectedShop by remember { mutableStateOf<TyreShop?>(null) }
    var isLoadingLocation by remember { mutableStateOf(false) }

    val cameraPositionState = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(
            LatLng(41.9028, 12.4964), // Rome default
            12f
        )
    }

    LaunchedEffect(Unit) {
        if (locationManager.hasLocationPermission()) {
            isLoadingLocation = true
            locationManager.getCurrentLocation()?.let { location ->
                val latLng = LatLng(location.latitude, location.longitude)
                currentLocation = latLng
                cameraPositionState.position = CameraPosition.fromLatLngZoom(latLng, 14f)

                // TODO: Fetch nearby shops from API
                nearbyShops = getMockShops(latLng)
            }
            isLoadingLocation = false
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Trova Officine") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Indietro")
                    }
                }
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            // Google Map
            GoogleMap(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                cameraPositionState = cameraPositionState,
                properties = MapProperties(
                    isMyLocationEnabled = locationManager.hasLocationPermission()
                ),
                uiSettings = MapUiSettings(
                    zoomControlsEnabled = false,
                    myLocationButtonEnabled = true
                )
            ) {
                // Current Location Marker
                currentLocation?.let {
                    Marker(
                        state = MarkerState(position = it),
                        title = "La tua posizione"
                    )
                }

                // Shop Markers
                nearbyShops.forEach { shop ->
                    Marker(
                        state = MarkerState(position = shop.position),
                        title = shop.name,
                        snippet = shop.address,
                        onClick = {
                            selectedShop = shop
                            true
                        }
                    )
                }
            }

            // Shop List
            LazyColumn(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                items(nearbyShops) { shop ->
                    ShopCard(
                        shop = shop,
                        onClick = {
                            selectedShop = shop
                            scope.launch {
                                cameraPositionState.animate(
                                    com.google.android.gms.maps.CameraUpdateFactory.newLatLngZoom(
                                        shop.position,
                                        16f
                                    )
                                )
                            }
                        }
                    )
                }
            }
        }

        // Shop Details Bottom Sheet
        selectedShop?.let { shop ->
            ModalBottomSheet(
                onDismissRequest = { selectedShop = null }
            ) {
                ShopDetailsContent(
                    shop = shop,
                    onClose = { selectedShop = null }
                )
            }
        }
    }
}

@Composable
fun ShopCard(
    shop: TyreShop,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        onClick = onClick
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = shop.name,
                    style = MaterialTheme.typography.titleMedium
                )
                Text(
                    text = shop.address,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.height(4.dp))
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Rating
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            Icons.Default.Star,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(16.dp)
                        )
                        Text(
                            text = shop.rating.toString(),
                            style = MaterialTheme.typography.bodySmall
                        )
                    }
                    // Distance
                    Text(
                        text = formatDistance(shop.distance),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    // Open/Closed
                    Text(
                        text = if (shop.isOpen) "Aperto" else "Chiuso",
                        style = MaterialTheme.typography.bodySmall,
                        color = if (shop.isOpen) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error
                    )
                }
            }

            Icon(
                Icons.Default.ChevronRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
fun ShopDetailsContent(
    shop: TyreShop,
    onClose: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            text = shop.name,
            style = MaterialTheme.typography.headlineSmall
        )

        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                Icons.Default.Star,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary
            )
            Text("${shop.rating}/5.0")
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = if (shop.isOpen) "Aperto" else "Chiuso",
                color = if (shop.isOpen) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error
            )
        }

        HorizontalDivider()

        // Address
        Row(verticalAlignment = Alignment.Top) {
            Icon(
                Icons.Default.LocationOn,
                contentDescription = null,
                modifier = Modifier.padding(top = 4.dp)
            )
            Spacer(modifier = Modifier.width(8.dp))
            Column {
                Text("Indirizzo", style = MaterialTheme.typography.labelSmall)
                Text(shop.address, style = MaterialTheme.typography.bodyMedium)
                Text(
                    formatDistance(shop.distance),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        // Phone
        shop.phone?.let { phone ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.Phone, contentDescription = null)
                Spacer(modifier = Modifier.width(8.dp))
                Column {
                    Text("Telefono", style = MaterialTheme.typography.labelSmall)
                    Text(phone, style = MaterialTheme.typography.bodyMedium)
                }
            }
        }

        HorizontalDivider()

        // Actions
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            OutlinedButton(
                onClick = { /* TODO: Navigate */ },
                modifier = Modifier.weight(1f)
            ) {
                Icon(Icons.Default.Directions, contentDescription = null)
                Spacer(modifier = Modifier.width(4.dp))
                Text("Indicazioni")
            }

            shop.phone?.let {
                OutlinedButton(
                    onClick = { /* TODO: Call */ },
                    modifier = Modifier.weight(1f)
                ) {
                    Icon(Icons.Default.Call, contentDescription = null)
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Chiama")
                }
            }
        }
    }
}

private fun formatDistance(meters: Float): String {
    return if (meters < 1000) {
        "${meters.toInt()} m"
    } else {
        String.format("%.1f km", meters / 1000)
    }
}

private fun getMockShops(center: LatLng): List<TyreShop> {
    return listOf(
        TyreShop(
            id = "1",
            name = "Gomme & Service",
            address = "Via Roma 123, Roma",
            position = LatLng(center.latitude + 0.01, center.longitude + 0.01),
            rating = 4.5f,
            distance = 500f,
            phone = "+39 06 1234567",
            isOpen = true
        ),
        TyreShop(
            id = "2",
            name = "AutoPneus Center",
            address = "Via Milano 45, Roma",
            position = LatLng(center.latitude - 0.01, center.longitude + 0.01),
            rating = 4.8f,
            distance = 800f,
            phone = "+39 06 7654321",
            isOpen = true
        ),
        TyreShop(
            id = "3",
            name = "TyrePro",
            address = "Corso Vittorio 89, Roma",
            position = LatLng(center.latitude + 0.01, center.longitude - 0.01),
            rating = 4.2f,
            distance = 1200f,
            phone = "+39 06 9876543",
            isOpen = false
        )
    )
}
