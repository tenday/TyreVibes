package it.tyrevibes.app.core.model

import androidx.compose.ui.graphics.Color
import kotlinx.serialization.Serializable
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.TimeUnit

@Serializable
data class MaintenanceSchedule(
    val id: String = UUID.randomUUID().toString(),
    val type: MaintenanceType,
    val title: String,
    val description: String,
    val scheduledDate: Long, // Timestamp in milliseconds
    val estimatedCost: Double? = null,
    val priority: Priority = Priority.MEDIUM,
    val vehicleId: String,
    val tyreId: String? = null,
    val metadata: MaintenanceMetadata? = null
) {
    @Serializable
    enum class MaintenanceType(val icon: String, val localizedKey: String) {
        ROTATION("rotate_right", "maintenance.type.rotation"),
        REPLACEMENT("autorenew", "maintenance.type.replacement"),
        PRESSURE_CHECK("speed", "maintenance.type.pressureCheck"),
        ALIGNMENT("align_horizontal_left", "maintenance.type.alignment"),
        SEASONAL_CHANGE("ac_unit", "maintenance.type.seasonalChange"),
        INSPECTION("search", "maintenance.type.inspection"),
        BALANCING("scale", "maintenance.type.balancing");

        fun getColor(): Color {
            return when (this) {
                ROTATION -> Color(0xFF007AFF)
                REPLACEMENT -> Color(0xFFFF9500)
                PRESSURE_CHECK -> Color(0xFF00C7BE)
                ALIGNMENT -> Color(0xFF5856D6)
                SEASONAL_CHANGE -> Color(0xFF87CEEB)
                INSPECTION -> Color(0xFFFFCC00)
                BALANCING -> Color(0xFF8E8E93)
            }
        }
    }

    @Serializable
    enum class Priority(val label: String) {
        LOW("Low"),
        MEDIUM("Medium"),
        HIGH("High"),
        CRITICAL("Critical");

        fun getColor(): Color {
            return when (this) {
                LOW -> Color.Gray
                MEDIUM -> Color.Blue
                HIGH -> Color(0xFFFFA500)
                CRITICAL -> Color.Red
            }
        }
    }

    @Serializable
    data class MaintenanceMetadata(
        val currentTreadDepth: Double? = null,
        val targetTreadDepth: Double? = null,
        val currentMileage: Int? = null,
        val targetMileage: Int? = null,
        val lastServiceDate: Long? = null,
        val dueInDays: Int? = null,
        val dueInKm: Int? = null
    )

    val daysUntil: Int
        get() {
            val diff = scheduledDate - System.currentTimeMillis()
            return TimeUnit.MILLISECONDS.toDays(diff).toInt()
        }

    val monthsUntil: Int
        get() = daysUntil / 30

    val isOverdue: Boolean
        get() = scheduledDate < System.currentTimeMillis()

    val formattedDate: String
        get() {
            val sdf = SimpleDateFormat("MMM dd, yyyy", Locale.getDefault())
            return sdf.format(Date(scheduledDate))
        }

    val relativeTimeString: String
        get() {
            if (isOverdue) {
                return "Scaduto" // TODO: localize
            }

            val days = daysUntil
            return when {
                days == 0 -> "Oggi"
                days == 1 -> "Domani"
                days <= 7 -> "Tra $days giorni"
                days <= 30 -> {
                    val weeks = days / 7
                    "Tra $weeks settiman${if (weeks > 1) "e" else "a"}"
                }
                else -> {
                    val months = monthsUntil
                    "Tra $months mes${if (months > 1) "i" else "e"}"
                }
            }
        }
}
