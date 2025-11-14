package it.tyrevibes.app.core.viewmodel

import android.graphics.Bitmap
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import it.tyrevibes.app.core.model.PlateData
import it.tyrevibes.app.core.service.AuthService
import it.tyrevibes.app.core.service.PlateAPIService
import it.tyrevibes.app.core.helper.BolloCalculator
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.UUID

data class AlertItem(
    val title: String,
    val message: String
)

data class ConfirmDetailsUiState(
    val isLoading: Boolean = false,
    val alertItem: AlertItem? = null,
    val didSavePlate: Boolean = false,
    val vehicleImage: Bitmap? = null,
    val vehicleImageColored: Bitmap? = null,
    val vehicleImageOriginal: Bitmap? = null
)

class ConfirmDetailsViewModel(
    private val plateAPIService: PlateAPIService,
    private val authService: AuthService
) : ViewModel() {

    private val _uiState = MutableStateFlow(ConfirmDetailsUiState())
    val uiState: StateFlow<ConfirmDetailsUiState> = _uiState.asStateFlow()

    private var activeImageRequestID = UUID.randomUUID()

    /**
     * Associa un veicolo esistente all'utente corrente.
     * Scarica le immagini del veicolo e le salva via API.
     */
    fun associateVehicleWithUser(
        vehicleId: Int,
        vehicleData: PlateData?,
        color: String = ""
    ) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)

            val userId = authService.currentUserId
            if (userId == null) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    alertItem = AlertItem("Errore", "ID utente non trovato")
                )
                return@launch
            }

            if (vehicleData == null) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    alertItem = AlertItem("Errore", "Dati del veicolo mancanti")
                )
                return@launch
            }

            // Scarica e associa le immagini del veicolo
            downloadAndAssociateVehicleImages(vehicleId, vehicleData, color, userId)
        }
    }

    /**
     * Salva una nuova targa con le immagini del veicolo.
     * Scarica immagini a diversi angoli (23°, 12°) con e senza colore.
     */
    fun savePlate(
        originalPlateData: PlateData,
        color: String,
        angle: Int = 23
    ) {
        viewModelScope.launch {
            val plateData = enrichPlateDataWithBollo(originalPlateData)
            _uiState.value = _uiState.value.copy(isLoading = true)
            activeImageRequestID = UUID.randomUUID()
            val requestID = activeImageRequestID

            try {
                // TODO: Implementare VehicleImageService per scaricare immagini del veicolo
                // Per ora usiamo placeholder

                // Scarica immagine colorata (angolo specificato)
                // val imgColored = VehicleImageService.fetchVehicleImage(...)

                // Scarica immagine originale (senza colore)
                // val imgOriginal = VehicleImageService.fetchVehicleImage(...)

                // Scarica immagine colorata (angolo 12)
                // val imgColored12 = VehicleImageService.fetchVehicleImage(...)

                // Scarica immagine originale (angolo 12)
                // val imgOriginal12 = VehicleImageService.fetchVehicleImage(...)

                val userId = authService.currentUserId ?: ""

                // Salva la targa con le immagini
                plateAPIService.savePlate(
                    plateData = plateData,
                    color = color,
                    userId = userId,
                    images = emptyList(), // TODO: sostituire con immagini scaricate
                    imagesColor = listOf(color, "", color, "")
                )

                if (activeImageRequestID == requestID) {
                    _uiState.value = _uiState.value.copy(
                        didSavePlate = true,
                        isLoading = false
                    )
                }
            } catch (e: Exception) {
                if (activeImageRequestID == requestID) {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        didSavePlate = false,
                        alertItem = AlertItem(
                            "Errore",
                            e.message ?: "Errore durante il salvataggio della targa"
                        )
                    )
                }
            }
        }
    }

    /**
     * Scarica le immagini del veicolo e le associa all'utente.
     * Usa diversi angoli (23°, 12°) e con/senza colore.
     */
    private fun downloadAndAssociateVehicleImages(
        vehicleId: Int,
        plateData: PlateData,
        color: String,
        userId: String
    ) {
        viewModelScope.launch {
            activeImageRequestID = UUID.randomUUID()
            val requestID = activeImageRequestID

            try {
                // TODO: Implementare VehicleImageService.clearCache()

                // TODO: Scaricare tutte le immagini necessarie:
                // - Colorata angolo 23
                // - Originale angolo 23
                // - Colorata angolo 12
                // - Originale angolo 12

                val userId = authService.currentUserId ?: ""

                // Salva la targa con le immagini
                plateAPIService.savePlate(
                    plateData = plateData,
                    color = color,
                    userId = userId,
                    images = emptyList(), // TODO: sostituire con immagini scaricate
                    imagesColor = listOf(color, color)
                )

                if (activeImageRequestID == requestID) {
                    _uiState.value = _uiState.value.copy(
                        didSavePlate = true,
                        isLoading = false
                    )
                }
            } catch (e: Exception) {
                if (activeImageRequestID == requestID) {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        didSavePlate = false,
                        alertItem = AlertItem(
                            "Errore",
                            e.message ?: "Errore durante il download delle immagini"
                        )
                    )
                }
            }
        }
    }

    /**
     * Arricchisce i dati della targa con il calcolo del bollo.
     */
    private fun enrichPlateDataWithBollo(plateData: PlateData): PlateData {
        if (plateData.bollo != null) return plateData

        val computed = BolloCalculator.calculateBollo(plateData) ?: return plateData

        return plateData.copy(bollo = computed)
    }

    /**
     * Cancella l'alert corrente.
     */
    fun clearAlert() {
        _uiState.value = _uiState.value.copy(alertItem = null)
    }

    /**
     * Reset dello stato "didSavePlate".
     */
    fun resetSaveState() {
        _uiState.value = _uiState.value.copy(didSavePlate = false)
    }
}
