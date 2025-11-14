package it.tyrevibes.app.core.viewmodel

import android.graphics.Bitmap
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import it.tyrevibes.app.core.model.Vehicle
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class TireAnalysisScreenUiState(
    val carImage: Bitmap? = null,
    val isLoading: Boolean = false,
    val errorMessage: String? = null
)

/**
 * ViewModel per lo schermo di analisi dei pneumatici.
 * Gestisce il caricamento dell'immagine del veicolo in vista dall'alto (angolo 1).
 */
class TireAnalysisScreenViewModel(
    private val vehicle: Vehicle
) : ViewModel() {

    private val _uiState = MutableStateFlow(TireAnalysisScreenUiState())
    val uiState: StateFlow<TireAnalysisScreenUiState> = _uiState.asStateFlow()

    /**
     * Scarica l'immagine del veicolo in vista dall'alto.
     * Usa angolo 1 per top-down view secondo documentazione imagin.studio.
     */
    fun fetchImage() {
        viewModelScope.launch {
            // Verifica che i dati del veicolo siano completi
            if (vehicle.make == null || vehicle.model == null ||
                vehicle.saleStart == null || vehicle.color == null) {
                _uiState.value = _uiState.value.copy(
                    errorMessage = "Dati del veicolo incompleti."
                )
                return@launch
            }

            _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = null)

            try {
                // TODO: Implementare VehicleImageService.fetchVehicleImage
                // Usando angolo 1 per vista dall'alto (top-down view)

                /*
                val image = VehicleImageService.fetchVehicleImage(
                    make = vehicle.make!!,
                    modelFamily = vehicle.model!!,
                    year = vehicle.saleStart!!,
                    paintId = vehicle.color!!,
                    angle = 1, // Top-down view
                    plate = ""
                )
                */

                // Placeholder - rimuovere quando VehicleImageService è implementato
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    carImage = null // Sarà sostituito con l'immagine reale
                )

            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    errorMessage = e.message ?: "Errore durante il caricamento dell'immagine"
                )
            }
        }
    }

    /**
     * Pulisce il messaggio di errore.
     */
    fun clearError() {
        _uiState.value = _uiState.value.copy(errorMessage = null)
    }

    /**
     * Ricarica l'immagine del veicolo.
     */
    fun reloadImage() {
        fetchImage()
    }
}
