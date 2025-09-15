package com.tyrevibes.android.features.licenseplate

import com.tyrevibes.android.core.data.SupabaseClient
import com.tyrevibes.android.features.garage.VehicleResponse
import io.ktor.client.*
import io.ktor.client.call.*
import io.ktor.client.engine.android.*
import io.ktor.client.plugins.contentnegotiation.*
import com.tyrevibes.android.BuildConfig
import io.ktor.client.request.*
import io.ktor.http.*
import io.ktor.serialization.kotlinx.json.*
import io.supabase.gotrue.auth.session
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

@Serializable
data class CheckPlateRequest(val plate: String, val userId: String)

@Serializable
data class SaveVehicleRequest(
    val plateData: VehicleResponse,
    val color: String,
    val userId: String
)

class PlateRepository {

    private val client = HttpClient(Android) {
        install(ContentNegotiation) {
            json(Json {
                ignoreUnknownKeys = true
                isLenient = true
            })
        }
    }

    suspend fun checkPlate(plate: String): VehicleResponse {
        val session = SupabaseClient.client.auth.session()
            ?: throw IllegalStateException("User not logged in")

        val requestBody = CheckPlateRequest(plate = plate, userId = session.user.id)
        val token = session.accessToken

        val url = "${BuildConfig.API_BASE_URL}/v1/check_plate"

        return client.post(url) {
            header(HttpHeaders.Authorization, "Bearer $token")
            contentType(ContentType.Application.Json)
            setBody(requestBody)
        }.body()
    }

    suspend fun saveVehicle(vehicleData: VehicleResponse, color: String) {
        val session = SupabaseClient.client.auth.session()
            ?: throw IllegalStateException("User not logged in")

        val requestBody = SaveVehicleRequest(
            plateData = vehicleData,
            color = color,
            userId = session.user.id
        )
        val token = session.accessToken

        val url = "${BuildConfig.API_BASE_URL}/v1/save_plate"

        client.post(url) {
            header(HttpHeaders.Authorization, "Bearer $token")
            contentType(ContentType.Application.Json)
            setBody(requestBody)
        }
    }
}
