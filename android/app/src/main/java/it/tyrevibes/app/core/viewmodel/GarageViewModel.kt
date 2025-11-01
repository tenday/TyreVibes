package it.tyrevibes.app.core.viewmodel

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import it.tyrevibes.app.BuildConfig
import it.tyrevibes.app.core.model.*
import it.tyrevibes.app.core.service.SupabaseManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import okhttp3.OkHttpClient
import okhttp3.Request

private val Context.garageDataStore by preferencesDataStore(name = "garage_cache")

@Serializable
data class VehicleResponse(
    val vehicle: Vehicle,
    val plate: Plate? = null,
    val image: VehicleImage? = null,
    val tyres: List<VehicleTyre>? = null,
    val revisions: List<VehicleRevision>? = null,
    val insurances: List<VehicleInsurance>? = null
)

data class GarageUiState(
    val vehicles: List<VehicleResponse> = emptyList(),
    val isLoading: Boolean = true,
    val showCarDetails: Boolean = false,
    val selectedVehicle: VehicleResponse? = null,
    val errorMessage: String? = null
)

class GarageViewModel(private val context: Context) : ViewModel() {

    private val _uiState = MutableStateFlow(GarageUiState())
    val uiState: StateFlow<GarageUiState> = _uiState.asStateFlow()

    private val json = Json { ignoreUnknownKeys = true }
    private val client = OkHttpClient()
    private val cachedVehiclesKey = stringPreferencesKey("cachedVehicles")

    init {
        loadCachedVehicles()
        fetchCars()
    }

    private fun loadCachedVehicles() {
        viewModelScope.launch {
            try {
                val prefs = context.garageDataStore.data.first()
                val cachedJson = prefs[cachedVehiclesKey]
                if (cachedJson != null) {
                    val vehicles = json.decodeFromString<List<VehicleResponse>>(cachedJson)
                    _uiState.value = _uiState.value.copy(vehicles = vehicles)
                }
            } catch (e: Exception) {
                // Ignore cache errors
            }
        }
    }

    private suspend fun getAuthToken(): String? {
        return SupabaseManager.getAccessToken()
    }

    fun fetchCars() {
        viewModelScope.launch {
            try {
                val userId = SupabaseManager.getCurrentUserId() ?: ""
                val baseURL = BuildConfig.BASE_URL
                val url = "$baseURL/v1/vehicles/$userId"

                val requestBuilder = Request.Builder()
                    .url(url)
                    .get()

                // Add JWT token
                getAuthToken()?.let { token ->
                    requestBuilder.addHeader("Authorization", "Bearer $token")
                }

                val request = requestBuilder.build()
                val response = client.newCall(request).execute()

                if (response.isSuccessful) {
                    val responseBody = response.body?.string() ?: ""

                    // Cache response
                    context.garageDataStore.edit { prefs ->
                        prefs[cachedVehiclesKey] = responseBody
                    }

                    val vehicles = json.decodeFromString<List<VehicleResponse>>(responseBody)
                    _uiState.value = _uiState.value.copy(
                        vehicles = vehicles,
                        isLoading = false
                    )
                } else {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        errorMessage = "Error fetching vehicles: ${response.code}"
                    )
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    vehicles = emptyList(),
                    isLoading = false,
                    errorMessage = e.message
                )
            }
        }
    }

    fun showDetails(vehicle: VehicleResponse) {
        _uiState.value = _uiState.value.copy(
            selectedVehicle = vehicle,
            showCarDetails = true
        )
    }

    fun hideDetails() {
        _uiState.value = _uiState.value.copy(
            showCarDetails = false,
            selectedVehicle = null
        )
    }

    fun deleteCar(vehicle: Vehicle) {
        viewModelScope.launch {
            try {
                val userId = SupabaseManager.getCurrentUserId() ?: return@launch
                val baseURL = BuildConfig.BASE_URL
                val url = "$baseURL/v1/vehicles/${vehicle.id}/user/$userId"

                val requestBuilder = Request.Builder()
                    .url(url)
                    .delete()

                // Add JWT token
                getAuthToken()?.let { token ->
                    requestBuilder.addHeader("Authorization", "Bearer $token")
                }

                val request = requestBuilder.build()
                val response = client.newCall(request).execute()

                if (response.isSuccessful) {
                    // Remove from local list
                    val updatedVehicles = _uiState.value.vehicles.filter {
                        it.vehicle.id != vehicle.id
                    }
                    _uiState.value = _uiState.value.copy(vehicles = updatedVehicles)

                    // Update cache
                    context.garageDataStore.edit { prefs ->
                        prefs[cachedVehiclesKey] = json.encodeToString(updatedVehicles)
                    }
                } else {
                    _uiState.value = _uiState.value.copy(
                        errorMessage = "Failed to delete vehicle: ${response.code}"
                    )
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    errorMessage = "Error deleting vehicle: ${e.message}"
                )
            }
        }
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(errorMessage = null)
    }
}
