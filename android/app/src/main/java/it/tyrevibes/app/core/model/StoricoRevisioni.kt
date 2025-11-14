package it.tyrevibes.app.core.model

import kotlinx.serialization.Serializable
import java.util.Date

/**
 * Storico Revisioni - Vehicle revision history model
 */
@Serializable
data class Revisione(
    val kmRevisione: String,
    val dataRevisione: Long? = null, // Timestamp in milliseconds
    val esitoRevisione: String
) {
    companion object {
        fun fromVehicleRevision(revision: VehicleRevision): Revisione {
            return Revisione(
                kmRevisione = revision.kmRevisione ?: "",
                dataRevisione = parseDate(revision.dataRevisione),
                esitoRevisione = revision.esitoRevisione ?: ""
            )
        }

        private fun parseDate(dateString: String?): Long? {
            dateString ?: return null
            return try {
                // Parse ISO date format
                val formatter = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.getDefault())
                formatter.parse(dateString)?.time
            } catch (e: Exception) {
                null
            }
        }
    }

    fun toVehicleRevision(vehicleId: Int): VehicleRevision {
        return VehicleRevision(
            id = 0,
            vehicleId = vehicleId,
            kmRevisione = kmRevisione,
            dataRevisione = formatDate(dataRevisione),
            esitoRevisione = esitoRevisione,
            note = null
        )
    }

    private fun formatDate(timestamp: Long?): String? {
        timestamp ?: return null
        val formatter = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.getDefault())
        return formatter.format(Date(timestamp))
    }
}
