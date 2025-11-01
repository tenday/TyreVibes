package it.tyrevibes.app.core.model

import kotlinx.serialization.Serializable

@Serializable
data class AddressResponse(
    val status: String,
    val resp: List<AddressSuggestion>,
    val time: Int
)

@Serializable
data class AddressSuggestion(
    val iso3: String,
    val level: String,
    val id: Int,
    val score: Double,
    val country: String,
    val region: String,
    val province: String,
    val city: String,
    val district1: String? = null,
    val zipcode: String,
    val street: String,
    val chk: String
)
