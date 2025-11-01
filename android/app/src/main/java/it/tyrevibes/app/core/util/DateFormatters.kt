package it.tyrevibes.app.core.util

import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.TimeUnit

object DateFormatters {

    private val defaultLocale = Locale.ITALIAN

    val dateFormatter: SimpleDateFormat
        get() = SimpleDateFormat("dd MMM yyyy", defaultLocale)

    val timeFormatter: SimpleDateFormat
        get() = SimpleDateFormat("HH:mm", defaultLocale)

    val dateTimeFormatter: SimpleDateFormat
        get() = SimpleDateFormat("dd MMM yyyy HH:mm", defaultLocale)

    val shortDateFormatter: SimpleDateFormat
        get() = SimpleDateFormat("dd/MM/yyyy", defaultLocale)

    val isoFormatter: SimpleDateFormat
        get() = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }

    fun formatRelativeTime(timestamp: Long): String {
        val now = System.currentTimeMillis()
        val diff = now - timestamp
        val seconds = TimeUnit.MILLISECONDS.toSeconds(diff)
        val minutes = TimeUnit.MILLISECONDS.toMinutes(diff)
        val hours = TimeUnit.MILLISECONDS.toHours(diff)
        val days = TimeUnit.MILLISECONDS.toDays(diff)

        return when {
            seconds < 60 -> "Pochi secondi fa"
            minutes < 60 -> "$minutes minut${if (minutes > 1) "i" else "o"} fa"
            hours < 24 -> "$hours or${if (hours > 1) "e" else "a"} fa"
            days < 7 -> "$days giorn${if (days > 1) "i" else "o"} fa"
            else -> dateFormatter.format(Date(timestamp))
        }
    }

    fun formatDate(timestamp: Long): String {
        return dateFormatter.format(Date(timestamp))
    }

    fun formatDateTime(timestamp: Long): String {
        return dateTimeFormatter.format(Date(timestamp))
    }

    fun formatTime(timestamp: Long): String {
        return timeFormatter.format(Date(timestamp))
    }

    fun parseISODate(isoString: String): Date? {
        return try {
            isoFormatter.parse(isoString)
        } catch (e: Exception) {
            null
        }
    }
}
