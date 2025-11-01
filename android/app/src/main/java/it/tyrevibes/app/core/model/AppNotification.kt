package it.tyrevibes.app.core.model

import androidx.compose.ui.graphics.Color
import kotlinx.serialization.Serializable
import java.text.SimpleDateFormat
import java.util.*

@Serializable
data class AppNotification(
    val id: String = UUID.randomUUID().toString(),
    val type: NotificationType,
    val title: String,
    val message: String,
    val timestamp: Long = System.currentTimeMillis(),
    var isRead: Boolean = false,
    val vehicleId: String? = null,
    val tyreId: String? = null,
    val priority: Priority = Priority.MEDIUM,
    val actionRequired: Boolean = false,
    val scheduledDate: Long? = null,
    val predictedDate: Long? = null,
    val metadata: NotificationMetadata? = null
) {
    @Serializable
    enum class Priority(val sortOrder: Int) {
        LOW(3),
        MEDIUM(2),
        HIGH(1),
        CRITICAL(0)
    }

    @Serializable
    data class NotificationMetadata(
        val treadDepth: Double? = null,
        val pressurePSI: Double? = null,
        val mileage: Int? = null,
        val lastServiceDate: Long? = null,
        val nextServiceDate: Long? = null,
        val estimatedCost: Double? = null,
        val warrantyExpiryDate: Long? = null,
        val seasonalChangeDate: Long? = null,
        val rotationDueKm: Int? = null,
        val replacementDueMonths: Int? = null
    )

    @Serializable
    enum class NotificationType(val icon: String, val localizedKey: String) {
        PRESSURE_ALERT("warning", "notification.type.pressureAlert"),
        SEASONAL_REMINDER("check_circle", "notification.type.seasonalReminder"),
        MAINTENANCE_REMINDER("notifications", "notification.type.maintenanceReminder"),
        SPECIAL_OFFER("local_offer", "notification.type.specialOffer"),
        TYRE_REPLACEMENT("autorenew", "notification.type.tyreReplacement"),
        ROTATION("rotate_right", "notification.type.rotation"),
        ALIGNMENT("align_horizontal_left", "notification.type.alignment"),
        INSPECTION("search", "notification.type.inspection"),
        WARRANTY("shield", "notification.type.warranty");

        fun getColor(): Color {
            return when (this) {
                PRESSURE_ALERT -> Color(0xFFFF453A)
                SEASONAL_REMINDER -> Color(0xFF00C7BE)
                MAINTENANCE_REMINDER -> Color(0xFF8E8E93)
                SPECIAL_OFFER -> Color(0xFF34C759)
                TYRE_REPLACEMENT -> Color(0xFFFF9500)
                ROTATION -> Color(0xFF007AFF)
                ALIGNMENT -> Color(0xFF5856D6)
                INSPECTION -> Color(0xFFFFCC00)
                WARRANTY -> Color(0xFF8C4511)
            }
        }
    }

    val relativeTime: String
        get() {
            val now = System.currentTimeMillis()
            val diff = now - timestamp
            val seconds = diff / 1000
            val minutes = seconds / 60
            val hours = minutes / 60
            val days = hours / 24

            return when {
                seconds < 60 -> "Pochi secondi fa"
                minutes < 60 -> "$minutes minut${if (minutes > 1) "i" else "o"} fa"
                hours < 24 -> "$hours or${if (hours > 1) "e" else "a"} fa"
                days < 7 -> "$days giorn${if (days > 1) "i" else "o"} fa"
                else -> {
                    val sdf = SimpleDateFormat("dd MMM", Locale.getDefault())
                    sdf.format(Date(timestamp))
                }
            }
        }
}
