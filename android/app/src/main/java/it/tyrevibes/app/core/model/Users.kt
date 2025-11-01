package it.tyrevibes.app.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Modello per la tabella 'profiles'
 */
@Serializable
data class Users(
    val id: String, // UUID as String in Kotlin
    @SerialName("full_name") val fullName: String,
    val username: String,
    @SerialName("phone_number") val phoneNumber: String? = null,
    @SerialName("country_dial_code") val countryDialCode: String? = null,
    @SerialName("agreed_to_terms") val agreedToTerms: Boolean
)
