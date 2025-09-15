package com.tyrevibes.android.features.garage

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.tyrevibes.android.core.data.SupabaseClient
import com.tyrevibes.android.core.network.GarageService
import io.supabase.gotrue.auth.session
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class GarageUiState(
    val vehicles: List<VehicleResponse> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null
)

class GarageViewModel : ViewModel() {

    private val _uiState = MutableStateFlow(GarageUiState())
    val uiState = _uiState.asStateFlow()

    private val _selectedVehicle = MutableStateFlow<VehicleResponse?>(null)
    val selectedVehicle = _selectedVehicle.asStateFlow()

    private val garageService = GarageService()

    init {
        fetchVehicles()
    }

    fun fetchVehicles() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            try {
                val session = SupabaseClient.client.auth.session()
                if (session == null) {
                    _uiState.value = _uiState.value.copy(isLoading = false, error = "User not logged in")
                    return@launch
                }
                val userId = session.user.id
                val token = session.accessToken

                val vehicles = garageService.getVehicles(userId, token)
                _uiState.value = _uiState.value.copy(isLoading = false, vehicles = vehicles)

            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(isLoading = false, error = e.message ?: "An unknown error occurred")
            }
        }
    }

    fun selectVehicle(vehicle: VehicleResponse) {
        _selectedVehicle.value = vehicle
    }
}
