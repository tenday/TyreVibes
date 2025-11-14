package it.tyrevibes.app.core.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import it.tyrevibes.app.core.model.VehicleTyre
import it.tyrevibes.app.core.service.TyreService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class TyreUiState(
    val tyres: List<VehicleTyre> = emptyList(),
    val selectedTyre: VehicleTyre? = null,
    val isLoading: Boolean = false,
    val error: String? = null
)

class TyreViewModel(
    private val tyreService: TyreService
) : ViewModel() {

    private val _uiState = MutableStateFlow(TyreUiState())
    val uiState: StateFlow<TyreUiState> = _uiState.asStateFlow()

    fun loadTyres(vehicleId: Int) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)

            try {
                val tyres = tyreService.getTyresForVehicle(vehicleId)
                _uiState.value = _uiState.value.copy(
                    tyres = tyres,
                    isLoading = false
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = e.message ?: "Failed to load tyres"
                )
            }
        }
    }

    fun selectTyre(tyre: VehicleTyre) {
        _uiState.value = _uiState.value.copy(selectedTyre = tyre)
    }

    fun addTyre(tyre: VehicleTyre) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)

            try {
                tyreService.addTyre(tyre)
                loadTyres(tyre.vehicleId)
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = e.message ?: "Failed to add tyre"
                )
            }
        }
    }

    fun deleteTyre(tyreId: Int, vehicleId: Int) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)

            try {
                tyreService.deleteTyre(tyreId)
                loadTyres(vehicleId)
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = e.message ?: "Failed to delete tyre"
                )
            }
        }
    }
}
