package it.tyrevibes.app.core.service

import it.tyrevibes.app.core.model.VehicleTyre
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Tyre Service Errors
 */
sealed class TyreServiceError : Exception() {
    object TyreNotFound : TyreServiceError()
    data class FetchFailed(override val message: String) : TyreServiceError()
    data class SaveFailed(override val message: String) : TyreServiceError()
    data class DeleteFailed(override val message: String) : TyreServiceError()
    object InvalidData : TyreServiceError()

    override val message: String
        get() = when (this) {
            TyreNotFound -> "Pneumatico non trovato"
            is FetchFailed -> "Errore nel recupero dei pneumatici: $message"
            is SaveFailed -> "Errore nel salvataggio del pneumatico: $message"
            is DeleteFailed -> "Errore nell'eliminazione del pneumatico: $message"
            InvalidData -> "Dati pneumatico non validi"
        }
}

/**
 * Tyre Data Models
 */
@Serializable
data class TyreSetRequest(
    @SerialName("vehicle_id") val vehicleId: Int,
    val tyres: List<TyreData>,
    @SerialName("set_name") val setName: String? = null,
    val season: String? = null
)

@Serializable
data class TyreData(
    @SerialName("size_label") val sizeLabel: String,
    val brand: String? = null,
    val model: String? = null,
    val season: String? = null,
    val dot: String? = null,
    @SerialName("load_index") val loadIndex: String? = null,
    @SerialName("speed_index") val speedIndex: String? = null,
    val width: Int? = null,
    val ratio: Int? = null,
    val diameter: Int? = null
)

@Serializable
data class TyreSetInfo(
    @SerialName("set_id") val id: Int,
    @SerialName("set_name") val name: String,
    val season: String? = null,
    val position: String? = null,
    @SerialName("tyre_count") val tyreCount: Int
)

/**
 * Tyre Service
 * Gestisce tutte le operazioni sui pneumatici
 */
object TyreService {

    private val networkManager = NetworkManager

    /**
     * Fetch tyres for a vehicle
     */
    suspend fun fetchTyres(vehicleId: Int): List<VehicleTyre> = withContext(Dispatchers.IO) {
        try {
            val tyres: List<VehicleTyre> = networkManager.get(
                endpoint = "/v1/tyres/vehicle/$vehicleId"
            )
            println("✅ [TyreService] Fetched ${tyres.size} tyres for vehicle $vehicleId")
            tyres
        } catch (e: Exception) {
            println("❌ [TyreService] Failed to fetch tyres: ${e.message}")
            throw TyreServiceError.FetchFailed(e.message ?: "Unknown error")
        }
    }

    /**
     * Save tyre set
     */
    suspend fun saveTyreSet(request: TyreSetRequest): List<VehicleTyre> = withContext(Dispatchers.IO) {
        try {
            val tyres: List<VehicleTyre> = networkManager.post(
                endpoint = "/v1/tyres/set",
                body = request
            )
            println("✅ [TyreService] Saved tyre set for vehicle ${request.vehicleId}")
            tyres
        } catch (e: Exception) {
            println("❌ [TyreService] Failed to save tyre set: ${e.message}")
            throw TyreServiceError.SaveFailed(e.message ?: "Unknown error")
        }
    }

    /**
     * Delete tyre
     */
    suspend fun deleteTyre(tyreId: Int): Unit = withContext(Dispatchers.IO) {
        try {
            networkManager.delete<Unit>(
                endpoint = "/v1/tyres/$tyreId"
            )
            println("✅ [TyreService] Deleted tyre $tyreId")
        } catch (e: Exception) {
            println("❌ [TyreService] Failed to delete tyre: ${e.message}")
            throw TyreServiceError.DeleteFailed(e.message ?: "Unknown error")
        }
    }

    /**
     * Get tyre sets info
     */
    suspend fun getTyreSets(vehicleId: Int): List<TyreSetInfo> = withContext(Dispatchers.IO) {
        try {
            val sets: List<TyreSetInfo> = networkManager.get(
                endpoint = "/v1/tyres/vehicle/$vehicleId/sets"
            )
            println("✅ [TyreService] Fetched ${sets.size} tyre sets for vehicle $vehicleId")
            sets
        } catch (e: Exception) {
            println("❌ [TyreService] Failed to fetch tyre sets: ${e.message}")
            throw TyreServiceError.FetchFailed(e.message ?: "Unknown error")
        }
    }
}
