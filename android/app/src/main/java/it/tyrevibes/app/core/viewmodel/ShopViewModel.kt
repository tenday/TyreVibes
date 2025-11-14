package it.tyrevibes.app.core.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import it.tyrevibes.app.core.service.LocationManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class Shop(
    val id: String,
    val name: String,
    val address: String,
    val lat: Double,
    val lng: Double,
    val rating: Float? = null,
    val phoneNumber: String? = null,
    val website: String? = null,
    val distance: Double? = null
)

data class ShopUiState(
    val shops: List<Shop> = emptyList(),
    val selectedShop: Shop? = null,
    val userLocation: Pair<Double, Double>? = null,
    val isLoading: Boolean = false,
    val error: String? = null,
    val searchQuery: String = ""
)

class ShopViewModel(
    private val locationManager: LocationManager
) : ViewModel() {

    private val _uiState = MutableStateFlow(ShopUiState())
    val uiState: StateFlow<ShopUiState> = _uiState.asStateFlow()

    init {
        loadUserLocation()
    }

    private fun loadUserLocation() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)

            try {
                locationManager.getCurrentLocation { location ->
                    _uiState.value = _uiState.value.copy(
                        userLocation = Pair(location.latitude, location.longitude),
                        isLoading = false
                    )
                    loadNearbyShops()
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = e.message ?: "Failed to get location"
                )
            }
        }
    }

    private fun loadNearbyShops() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)

            try {
                // TODO: Load shops from API or database
                // For now, mock data
                val mockShops = listOf(
                    Shop("1", "AutoService Pro", "Via Roma 123, Milano", 45.4642, 9.1900, 4.5f, "+39 02 1234567"),
                    Shop("2", "Pneumatici Expert", "Corso Buenos Aires 45, Milano", 45.4786, 9.2019, 4.2f, "+39 02 7654321"),
                    Shop("3", "Tyre Center", "Via Torino 89, Milano", 45.4614, 9.1859, 4.8f, "+39 02 9876543")
                )

                _uiState.value = _uiState.value.copy(
                    shops = mockShops,
                    isLoading = false
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = e.message ?: "Failed to load shops"
                )
            }
        }
    }

    fun selectShop(shop: Shop) {
        _uiState.value = _uiState.value.copy(selectedShop = shop)
    }

    fun updateSearchQuery(query: String) {
        _uiState.value = _uiState.value.copy(searchQuery = query)
        if (query.isNotEmpty()) {
            searchShops(query)
        } else {
            loadNearbyShops()
        }
    }

    private fun searchShops(query: String) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)

            try {
                // TODO: Search shops by query
                val filteredShops = _uiState.value.shops.filter {
                    it.name.contains(query, ignoreCase = true) ||
                            it.address.contains(query, ignoreCase = true)
                }

                _uiState.value = _uiState.value.copy(
                    shops = filteredShops,
                    isLoading = false
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = e.message ?: "Failed to search shops"
                )
            }
        }
    }
}
