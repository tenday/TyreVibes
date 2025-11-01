package it.tyrevibes.app.core.service

import it.tyrevibes.app.core.viewmodel.VehicleResponse
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Vehicle Service Errors
 */
sealed class VehicleServiceError : Exception() {
    object VehicleNotFound : VehicleServiceError()
    data class FetchFailed(override val message: String) : VehicleServiceError()
    data class DeleteFailed(override val message: String) : VehicleServiceError()
    data class AssociationFailed(override val message: String) : VehicleServiceError()
    object InvalidUserId : VehicleServiceError()

    override val message: String
        get() = when (this) {
            VehicleNotFound -> "Veicolo non trovato"
            is FetchFailed -> "Errore nel recupero dei veicoli: $message"
            is DeleteFailed -> "Errore nell'eliminazione del veicolo: $message"
            is AssociationFailed -> "Errore nell'associazione del veicolo: $message"
            InvalidUserId -> "ID utente non valido"
        }
}

/**
 * Vehicle Service
 * Gestisce tutte le operazioni sui veicoli
 */
object VehicleService {

    private val networkManager = NetworkManager

    /**
     * Fetch all vehicles for a user
     */
    suspend fun fetchVehicles(userId: String): List<VehicleResponse> = withContext(Dispatchers.IO) {
        try {
            val vehicles: List<VehicleResponse> = networkManager.get(
                endpoint = "/v1/vehicles/$userId"
            )
            println("✅ [VehicleService] Fetched ${vehicles.size} vehicles for user $userId")
            vehicles
        } catch (e: Exception) {
            println("❌ [VehicleService] Failed to fetch vehicles: ${e.message}")
            throw VehicleServiceError.FetchFailed(e.message ?: "Unknown error")
        }
    }

    /**
     * Delete vehicle association from user
     */
    suspend fun deleteVehicle(vehicleId: Int, userId: String): Unit = withContext(Dispatchers.IO) {
        try {
            networkManager.delete<Unit>(
                endpoint = "/v1/vehicles/$vehicleId/user/$userId"
            )
            println("✅ [VehicleService] Deleted vehicle $vehicleId for user $userId")
        } catch (e: Exception) {
            println("❌ [VehicleService] Failed to delete vehicle: ${e.message}")
            throw VehicleServiceError.DeleteFailed(e.message ?: "Unknown error")
        }
    }

    /**
     * Associate vehicle to user with color and image
     */
    suspend fun associateVehicleToUser(
        vehicleId: Int,
        userId: String,
        color: String,
        imageData: ByteArray? = null
    ): Pair<String, String> = withContext(Dispatchers.IO) {
        try {
            val requestBody = mapOf(
                "user_id" to userId,
                "color" to color,
                "image_data" to imageData?.let { android.util.Base64.encodeToString(it, android.util.Base64.NO_WRAP) }
            )

            val response: Map<String, String> = networkManager.post(
                endpoint = "/v1/vehicles/$vehicleId/associate",
                body = requestBody
            )

            val imageBase64 = response["image_base64"] ?: ""
            val mimeType = response["mime_type"] ?: "image/jpeg"

            println("✅ [VehicleService] Associated vehicle $vehicleId to user $userId")
            Pair(imageBase64, mimeType)
        } catch (e: Exception) {
            println("❌ [VehicleService] Failed to associate vehicle: ${e.message}")
            throw VehicleServiceError.AssociationFailed(e.message ?: "Unknown error")
        }
    }
}
