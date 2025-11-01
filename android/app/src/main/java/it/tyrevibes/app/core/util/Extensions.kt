package it.tyrevibes.app.core.util

import android.content.Context
import android.widget.Toast
import androidx.compose.ui.graphics.Color

/**
 * Extensions utility file
 * Contains useful extension functions for Android
 */

// Context extensions
fun Context.showToast(message: String, duration: Int = Toast.LENGTH_SHORT) {
    Toast.makeText(this, message, duration).show()
}

// String extensions
fun String.isValidEmail(): Boolean {
    val emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    return this.matches(emailRegex.toRegex())
}

fun String.capitalizeWords(): String {
    return this.split(" ").joinToString(" ") { word ->
        word.lowercase().replaceFirstChar { it.uppercase() }
    }
}

// Color extensions
fun Color.Companion.fromHex(hex: String): Color {
    val cleanHex = hex.removePrefix("#")
    val color = cleanHex.toLongOrNull(16) ?: 0x000000
    return Color(
        red = ((color shr 16) and 0xFF) / 255f,
        green = ((color shr 8) and 0xFF) / 255f,
        blue = (color and 0xFF) / 255f,
        alpha = if (cleanHex.length == 8) ((color shr 24) and 0xFF) / 255f else 1f
    )
}

// Number extensions
fun Double.formatKm(): String {
    return if (this > 1000) {
        String.format("%.1f km", this / 1000)
    } else {
        String.format("%.0f m", this)
    }
}

fun Double.formatPrice(): String {
    return String.format("%.2f €", this)
}

fun Int.formatWithSeparator(): String {
    return String.format("%,d", this)
}

// List extensions
fun <T> List<T>.secondOrNull(): T? {
    return if (this.size >= 2) this[1] else null
}
