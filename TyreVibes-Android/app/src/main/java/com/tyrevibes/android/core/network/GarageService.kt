package com.tyrevibes.android.core.network

import com.tyrevibes.android.features.garage.VehicleResponse
import io.ktor.client.*
import io.ktor.client.call.*
import io.ktor.client.engine.android.*
import io.ktor.client.plugins.contentnegotiation.*
import com.tyrevibes.android.BuildConfig
import io.ktor.client.request.*
import io.ktor.http.*
import io.ktor.serialization.kotlinx.json.*
import kotlinx.serialization.json.Json

class GarageService {

    private val client = HttpClient(Android) {
        install(ContentNegotiation) {
            json(Json {
                ignoreUnknownKeys = true
                isLenient = true
            })
        }
    }

    suspend fun getVehicles(userId: String, token: String): List<VehicleResponse> {
        val url = "${BuildConfig.API_BASE_URL}/vehicles/$userId"
        return client.get(url) {
            header(HttpHeaders.Authorization, "Bearer $token")
        }.body()
    }
}
