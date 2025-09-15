package com.tyrevibes.android.features.licenseplate

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.tyrevibes.android.features.garage.VehicleResponse
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

sealed interface PlateUiState {
    object Idle : PlateUiState
    object Loading : PlateUiState
    data class Success(val vehicleData: VehicleResponse) : PlateUiState
    data class Error(val message: String) : PlateUiState
}

class PlateViewModel : ViewModel() {

    private val repository = PlateRepository()

    private val _uiState = MutableStateFlow<PlateUiState>(PlateUiState.Idle)
    val uiState = _uiState.asStateFlow()

    private val _plateInput = MutableStateFlow("")
    val plateInput = _plateInput.asStateFlow()

    fun onPlateInputChange(value: String) {
        _plateInput.value = value.uppercase().filter { it.isLetterOrDigit() }.take(8)
    }

    fun checkPlate(plate: String) {
        viewModelScope.launch {
            _uiState.value = PlateUiState.Loading
            try {
                val vehicleData = repository.checkPlate(plate)
                _uiState.value = PlateUiState.Success(vehicleData)
            } catch (e: Exception) {
                _uiState.value = PlateUiState.Error(e.message ?: "An unknown error occurred")
            }
        }
    }

    fun resetState() {
        _uiState.value = PlateUiState.Idle
    }

    fun saveVehicle(vehicleData: VehicleResponse, color: String) {
        viewModelScope.launch {
            _uiState.value = PlateUiState.Loading // Reuse loading state
            try {
                repository.saveVehicle(vehicleData, color)
                // We can create a new success state for this if needed,
                // but for now, we'll just navigate back from the UI.
                _uiState.value = PlateUiState.Success(vehicleData) // Re-emit success to trigger navigation
            } catch (e: Exception) {
                _uiState.value = PlateUiState.Error(e.message ?: "An unknown error occurred")
            }
        }
    }
}
