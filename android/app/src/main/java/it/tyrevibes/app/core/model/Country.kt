package it.tyrevibes.app.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Country model for phone number country selection
 */
@Serializable
data class Country(
    val id: Int? = null,
    val name: String,
    @SerialName("iso2_code")
    val iso2Code: String,
    @SerialName("dial_code")
    val dialCode: String,
    @SerialName("flag_emoji")
    val flagEmoji: String? = null
)

/**
 * Predefined list of common countries
 */
object Countries {
    val all = listOf(
        Country(1, "Italia", "IT", "+39", "🇮🇹"),
        Country(2, "Stati Uniti", "US", "+1", "🇺🇸"),
        Country(3, "Regno Unito", "GB", "+44", "🇬🇧"),
        Country(4, "Francia", "FR", "+33", "🇫🇷"),
        Country(5, "Germania", "DE", "+49", "🇩🇪"),
        Country(6, "Spagna", "ES", "+34", "🇪🇸"),
        Country(7, "Svizzera", "CH", "+41", "🇨🇭"),
        Country(8, "Austria", "AT", "+43", "🇦🇹"),
        Country(9, "Belgio", "BE", "+32", "🇧🇪"),
        Country(10, "Paesi Bassi", "NL", "+31", "🇳🇱"),
        Country(11, "Polonia", "PL", "+48", "🇵🇱"),
        Country(12, "Portogallo", "PT", "+351", "🇵🇹"),
        Country(13, "Grecia", "GR", "+30", "🇬🇷"),
        Country(14, "Svezia", "SE", "+46", "🇸🇪"),
        Country(15, "Norvegia", "NO", "+47", "🇳🇴"),
        Country(16, "Danimarca", "DK", "+45", "🇩🇰"),
        Country(17, "Finlandia", "FI", "+358", "🇫🇮"),
        Country(18, "Irlanda", "IE", "+353", "🇮🇪"),
        Country(19, "Canada", "CA", "+1", "🇨🇦"),
        Country(20, "Australia", "AU", "+61", "🇦🇺")
    )

    fun findByDialCode(dialCode: String): Country? {
        return all.find { it.dialCode == dialCode }
    }

    fun findByIso2Code(iso2Code: String): Country? {
        return all.find { it.iso2Code.equals(iso2Code, ignoreCase = true) }
    }
}
