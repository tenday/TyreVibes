package it.tyrevibes.app.core.service

import android.util.Log
import io.ktor.client.*
import io.ktor.client.call.*
import io.ktor.client.engine.android.*
import io.ktor.client.plugins.*
import io.ktor.client.plugins.contentnegotiation.*
import io.ktor.client.plugins.logging.*
import io.ktor.client.request.*
import io.ktor.client.statement.*
import io.ktor.http.*
import io.ktor.serialization.kotlinx.json.*
import it.tyrevibes.app.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json

/**
 * Network Errors
 */
sealed class NetworkError : Exception() {
    object InvalidURL : NetworkError()
    object InvalidResponse : NetworkError()
    data class HttpError(val statusCode: Int, override val message: String?) : NetworkError()
    data class DecodingError(val error: Throwable) : NetworkError()
    data class EncodingError(val error: Throwable) : NetworkError()
    data class NetworkException(val error: Throwable) : NetworkError()
    object Unauthorized : NetworkError()
    object Forbidden : NetworkError()
    object NotFound : NetworkError()
    object ServerError : NetworkError()
    object Timeout : NetworkError()

    override val message: String
        get() = when (this) {
            InvalidURL -> "URL non valido"
            InvalidResponse -> "Risposta dal server non valida"
            is HttpError -> "Errore HTTP $statusCode: ${message ?: "Errore sconosciuto"}"
            is DecodingError -> "Errore decodifica dati: ${error.message}"
            is EncodingError -> "Errore codifica dati: ${error.message}"
            is NetworkException -> "Errore di rete: ${error.message}"
            Unauthorized -> "Non autorizzato - Effettua il login"
            Forbidden -> "Accesso negato"
            NotFound -> "Risorsa non trovata"
            ServerError -> "Errore del server - Riprova più tardi"
            Timeout -> "Timeout della richiesta"
        }
}

/**
 * Network Manager Singleton
 * Gestisce tutte le richieste HTTP con autenticazione JWT automatica
 */
object NetworkManager {

    private const val TAG = "NetworkManager"
    private const val TIMEOUT_MILLIS = 30_000L

    private val baseUrl = BuildConfig.BASE_URL

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        encodeDefaults = true
    }

    private val client = HttpClient(Android) {
        install(ContentNegotiation) {
            json(json)
        }

        install(Logging) {
            logger = object : Logger {
                override fun log(message: String) {
                    Log.d(TAG, message)
                }
            }
            level = LogLevel.INFO
        }

        install(HttpTimeout) {
            requestTimeoutMillis = TIMEOUT_MILLIS
            connectTimeoutMillis = TIMEOUT_MILLIS
            socketTimeoutMillis = TIMEOUT_MILLIS
        }

        defaultRequest {
            contentType(ContentType.Application.Json)
            accept(ContentType.Application.Json)
        }
    }

    /**
     * Get JWT token from Supabase
     */
    private suspend fun getAuthToken(): String? {
        return SupabaseManager.getAccessToken()
    }

    /**
     * Generic GET request
     */
    suspend inline fun <reified T> get(
        endpoint: String,
        parameters: Map<String, Any>? = null,
        headers: Map<String, String>? = null
    ): T = withContext(Dispatchers.IO) {
        try {
            val response: HttpResponse = client.get(baseUrl + endpoint) {
                // Add query parameters
                parameters?.forEach { (key, value) ->
                    parameter(key, value.toString())
                }

                // Add JWT token
                getAuthToken()?.let { token ->
                    header("Authorization", "Bearer $token")
                }

                // Add custom headers
                headers?.forEach { (key, value) ->
                    header(key, value)
                }
            }

            handleResponse(response)
        } catch (e: Exception) {
            throw mapException(e)
        }
    }

    /**
     * Generic POST request
     */
    suspend inline fun <reified T, reified R> post(
        endpoint: String,
        body: R,
        headers: Map<String, String>? = null
    ): T = withContext(Dispatchers.IO) {
        try {
            val response: HttpResponse = client.post(baseUrl + endpoint) {
                // Add JWT token
                getAuthToken()?.let { token ->
                    header("Authorization", "Bearer $token")
                }

                // Add custom headers
                headers?.forEach { (key, value) ->
                    header(key, value)
                }

                // Set body
                setBody(body)
            }

            handleResponse(response)
        } catch (e: Exception) {
            throw mapException(e)
        }
    }

    /**
     * Generic PUT request
     */
    suspend inline fun <reified T, reified R> put(
        endpoint: String,
        body: R,
        headers: Map<String, String>? = null
    ): T = withContext(Dispatchers.IO) {
        try {
            val response: HttpResponse = client.put(baseUrl + endpoint) {
                // Add JWT token
                getAuthToken()?.let { token ->
                    header("Authorization", "Bearer $token")
                }

                // Add custom headers
                headers?.forEach { (key, value) ->
                    header(key, value)
                }

                // Set body
                setBody(body)
            }

            handleResponse(response)
        } catch (e: Exception) {
            throw mapException(e)
        }
    }

    /**
     * Generic DELETE request
     */
    suspend inline fun <reified T> delete(
        endpoint: String,
        headers: Map<String, String>? = null
    ): T = withContext(Dispatchers.IO) {
        try {
            val response: HttpResponse = client.delete(baseUrl + endpoint) {
                // Add JWT token
                getAuthToken()?.let { token ->
                    header("Authorization", "Bearer $token")
                }

                // Add custom headers
                headers?.forEach { (key, value) ->
                    header(key, value)
                }
            }

            handleResponse(response)
        } catch (e: Exception) {
            throw mapException(e)
        }
    }

    /**
     * Handle HTTP response and map errors
     */
    private suspend inline fun <reified T> handleResponse(response: HttpResponse): T {
        return when (response.status.value) {
            in 200..299 -> {
                try {
                    response.body<T>()
                } catch (e: Exception) {
                    throw NetworkError.DecodingError(e)
                }
            }
            401 -> throw NetworkError.Unauthorized
            403 -> throw NetworkError.Forbidden
            404 -> throw NetworkError.NotFound
            in 500..599 -> throw NetworkError.ServerError
            else -> throw NetworkError.HttpError(
                response.status.value,
                response.bodyAsText()
            )
        }
    }

    /**
     * Map exceptions to NetworkError
     */
    private fun mapException(e: Exception): NetworkError {
        return when (e) {
            is NetworkError -> e
            is HttpRequestTimeoutException -> NetworkError.Timeout
            else -> NetworkError.NetworkException(e)
        }
    }
}
