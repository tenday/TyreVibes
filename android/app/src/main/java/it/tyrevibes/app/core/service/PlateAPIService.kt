package it.tyrevibes.app.core.service

import android.content.Context
import android.graphics.Bitmap
import android.util.Base64
import io.ktor.client.*
import io.ktor.client.call.*
import io.ktor.client.request.*
import io.ktor.client.statement.*
import io.ktor.http.*
import it.tyrevibes.app.core.model.Revisione
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.io.ByteArrayOutputStream
import java.text.SimpleDateFormat
import java.util.*

/**
 * Plate Data - Data for plate registration
 */
data class PlateData(
    val plate: String,
    val make: String? = null,
    val model: String? = null,
    val color: String? = null,
    val fuelType: String? = null,
    val powerKW: String? = null,
    val powerCV: String? = null,
    val modelDetails: String? = null,
    val displacementCC: String? = null,
    val registrationDate: String? = null,
    val vin: String? = null,
    val insuranceCompany: String? = null,
    val insurancePolicyNumber: String? = null,
    val insuranceExpiry: Date? = null,
    val insurancePresent: Boolean? = null,
    val emissionClass: String? = null,
    val tyres: List<Map<String, String>>? = null,
    val view: String? = null,
    val saleStart: String? = null,
    val saleEnd: String? = null,
    val gearbox: String? = null,
    val maxSpeed: String? = null,
    val bodyType: String? = null,
    val doors: String? = null,
    val seats: String? = null,
    val consumption: String? = null,
    val traction: String? = null,
    val revisioni: List<Revisione>? = null,
    val bollo: BolloInfo? = null
)

data class BolloInfo(
    val baseBollo: Double?,
    val superBollo: Double?,
    val total: Double?,
    val emissionClassDescription: String?
)

/**
 * Plate API Request model
 */
@Serializable
data class PlateAPIRequest(
    val plate: String,
    val make: String?,
    val model: String?,
    val color: String?,
    val fuelType: String?,
    val powerKW: String?,
    val powerCV: String?,
    val modelDetails: String?,
    val displacementCC: String?,
    val registrationDate: String?,
    val year: Int?,
    val month: Int?,
    val vin: String?,
    val userId: String,
    val imagesBase64: List<String>?,
    val imagesMime: List<String>?,
    val imagesAngle: List<Int>?,
    val imagesColor: List<String>,
    val insuranceCompany: String?,
    val insurancePolicyNumber: String?,
    val insuranceExpiry: String?,
    val insurancePresent: Boolean?,
    val emissionClass: String?,
    val tyres: List<Map<String, String>>?,
    val view: String?,
    val saleStart: String?,
    val saleEnd: String?,
    val gearbox: String?,
    val maxSpeed: String?,
    val bodyType: String?,
    val doors: String?,
    val seats: String?,
    val consumption: String?,
    val traction: String?,
    val revisioni: List<Revisione>?,
    val bolloAmount: Double?,
    val bolloSuper: Double?,
    val bolloTotal: Double?,
    val bolloEmissionClass: String?
)

/**
 * Plate API Response model
 */
@Serializable
data class PlateAPIResponse(
    @SerialName("plate_id") val plateId: Int,
    val plate: String,
    val make: String?,
    val model: String?,
    val modelDetail: String?,
    @SerialName("fuel_type") val fuelType: String?,
    @SerialName("power_kw") val powerKw: String?,
    val cilindrata: String?,
    val color: String?,
    val vin: String?,
    @SerialName("created_at") val createdAt: String,
    @SerialName("user_id") val userId: String?,
    @SerialName("registration_date") val registrationDate: String?,
    @SerialName("image_base64") val imageBase64: String?,
    val rcaCompany: String?,
    val rcaPolicyNumber: String?,
    val rcaExpiry: String?,
    val rcaInsurancePresent: Boolean?,
    val classeAmbientale: String?
)

/**
 * Manual Plate Response
 */
@Serializable
data class ManualPlateResponse(
    @SerialName("vehicle_id") val vehicleId: Int,
    @SerialName("plate_id") val plateId: Int,
    val message: String
)

/**
 * Association Response
 */
@Serializable
data class AssociationResponse(
    val message: String,
    @SerialName("image_base64") val imageBase64: String?
)

/**
 * Plate API Errors
 */
sealed class PlateAPIError : Exception() {
    object InvalidURL : PlateAPIError()
    data class RequestFailed(val error: Throwable) : PlateAPIError()
    object InvalidResponse : PlateAPIError()
    data class ServerError(val statusCode: Int, val message: String) : PlateAPIError()
    object PlateNotFound : PlateAPIError()
    object AlreadyInGarage : PlateAPIError()
}

/**
 * Plate API Service - Handles external plate API calls
 */
class PlateAPIService(
    private val context: Context,
    private val httpClient: HttpClient,
    private val supabaseManager: SupabaseManager
) {
    // TODO: Load from configuration file or BuildConfig
    private val savePlateURL = "https://your-api-url/save-plate" // Replace with actual URL
    private val checkPlateBaseURL = "https://your-api-url/check-plate" // Replace with actual URL
    private val manualPlateURL = "https://your-api-url/manual-plate" // Replace with actual URL
    private val baseURL = "https://your-api-url" // Replace with actual URL

    /**
     * Get auth token from Supabase
     */
    private suspend fun getAuthToken(): String? {
        return try {
            supabaseManager.getAccessToken()
        } catch (e: Exception) {
            println("⚠️ [PlateAPIService] Failed to get auth token: ${e.message}")
            null
        }
    }

    /**
     * Check if plate exists in database
     */
    suspend fun checkPlate(plateNumber: String): Int? {
        return try {
            val token = getAuthToken() ?: throw PlateAPIError.InvalidResponse

            val response: HttpResponse = httpClient.get(checkPlateBaseURL) {
                parameter("plate", plateNumber)
                header(HttpHeaders.Authorization, "Bearer $token")
            }

            when (response.status.value) {
                404 -> null // Plate not found
                in 200..299 -> {
                    val apiResponse = response.body<PlateAPIResponse>()
                    apiResponse.plateId
                }
                else -> {
                    val errorMessage = response.bodyAsText()
                    throw PlateAPIError.ServerError(response.status.value, errorMessage)
                }
            }
        } catch (e: Exception) {
            when (e) {
                is PlateAPIError -> throw e
                else -> throw PlateAPIError.RequestFailed(e)
            }
        }
    }

    /**
     * Convert registration date MM/yyyy to yyyy-MM-dd
     */
    private fun convertRegistrationDate(dateStr: String?): String {
        dateStr ?: return "-"
        val parts = dateStr.split("/")
        return if (parts.size == 2) {
            "${parts[1]}-${parts[0]}-01"
        } else {
            "-"
        }
    }

    /**
     * Extract year from MM/yyyy format
     */
    private fun extractYear(dateStr: String?): Int? {
        dateStr ?: return null
        return try {
            val formatter = SimpleDateFormat("MM/yyyy", Locale.ITALIAN)
            val date = formatter.parse(dateStr)
            val calendar = Calendar.getInstance()
            calendar.time = date!!
            calendar.get(Calendar.YEAR)
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Extract month from MM/yyyy format
     */
    private fun extractMonth(dateStr: String?): Int? {
        dateStr ?: return null
        return try {
            val formatter = SimpleDateFormat("MM/yyyy", Locale.ITALIAN)
            val date = formatter.parse(dateStr)
            val calendar = Calendar.getInstance()
            calendar.time = date!!
            calendar.get(Calendar.MONTH) + 1 // Calendar.MONTH is 0-based
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Convert Bitmap to Base64
     */
    private fun bitmapToBase64(bitmap: Bitmap): Pair<String, String> {
        val byteArrayOutputStream = ByteArrayOutputStream()

        // Check if bitmap has alpha channel
        val hasAlpha = bitmap.hasAlpha()

        return if (hasAlpha) {
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, byteArrayOutputStream)
            val byteArray = byteArrayOutputStream.toByteArray()
            Pair(Base64.encodeToString(byteArray, Base64.NO_WRAP), "image/png")
        } else {
            bitmap.compress(Bitmap.CompressFormat.JPEG, 90, byteArrayOutputStream)
            val byteArray = byteArrayOutputStream.toByteArray()
            Pair(Base64.encodeToString(byteArray, Base64.NO_WRAP), "image/jpeg")
        }
    }

    /**
     * Save plate with images
     */
    suspend fun savePlate(
        plateData: PlateData,
        color: String,
        userId: String,
        images: List<Bitmap?>,
        imagesColor: List<String>
    ) {
        val token = getAuthToken() ?: throw PlateAPIError.InvalidResponse

        val imagesBase64 = mutableListOf<String>()
        val imagesMime = mutableListOf<String>()

        images.filterNotNull().forEach { bitmap ->
            val (base64, mime) = bitmapToBase64(bitmap)
            imagesBase64.add(base64)
            imagesMime.add(mime)
        }

        val angles = if (imagesBase64.size == 2) {
            listOf(23, 12)
        } else {
            listOf(23, 23, 12, 12)
        }

        val requestBody = PlateAPIRequest(
            plate = plateData.plate.uppercase(),
            make = plateData.make ?: "-",
            model = plateData.model ?: "-",
            color = color.lowercase(),
            fuelType = plateData.fuelType ?: "-",
            powerKW = plateData.powerKW ?: "-",
            powerCV = plateData.powerCV ?: "-",
            modelDetails = plateData.modelDetails ?: "-",
            displacementCC = plateData.displacementCC ?: "-",
            registrationDate = convertRegistrationDate(plateData.registrationDate),
            year = extractYear(plateData.registrationDate),
            month = extractMonth(plateData.registrationDate),
            vin = plateData.vin ?: "-",
            userId = userId,
            imagesBase64 = imagesBase64,
            imagesMime = imagesMime,
            imagesAngle = angles,
            imagesColor = imagesColor,
            insuranceCompany = plateData.insuranceCompany,
            insurancePolicyNumber = plateData.insurancePolicyNumber,
            insuranceExpiry = plateData.insuranceExpiry?.toString(),
            insurancePresent = plateData.insurancePresent,
            emissionClass = plateData.emissionClass,
            tyres = plateData.tyres,
            view = plateData.view,
            saleStart = plateData.saleStart,
            saleEnd = plateData.saleEnd,
            gearbox = plateData.gearbox,
            maxSpeed = plateData.maxSpeed,
            bodyType = plateData.bodyType,
            doors = plateData.doors,
            seats = plateData.seats,
            consumption = plateData.consumption,
            traction = plateData.traction,
            revisioni = plateData.revisioni,
            bolloAmount = plateData.bollo?.baseBollo,
            bolloSuper = plateData.bollo?.superBollo,
            bolloTotal = plateData.bollo?.total,
            bolloEmissionClass = plateData.bollo?.emissionClassDescription
        )

        try {
            val response: HttpResponse = httpClient.post(savePlateURL) {
                header(HttpHeaders.Authorization, "Bearer $token")
                contentType(ContentType.Application.Json)
                setBody(requestBody)
            }

            if (response.status.value !in 200..299) {
                val errorMessage = response.bodyAsText()
                throw PlateAPIError.ServerError(response.status.value, errorMessage)
            }
        } catch (e: Exception) {
            when (e) {
                is PlateAPIError -> throw e
                else -> throw PlateAPIError.RequestFailed(e)
            }
        }
    }

    /**
     * Save plate manually (without images)
     */
    suspend fun savePlateManually(
        plate: String,
        make: String = "",
        model: String = "",
        modelDetails: String = "",
        registrationDate: String = "",
        fuelType: String = "",
        powerKW: String = "",
        powerCV: String = "",
        displacementCC: String = "",
        emissionClass: String = "",
        gearbox: String = "",
        maxSpeed: String = "",
        bodyType: String = "",
        doors: String = "",
        seats: String = "",
        consumption: String = "",
        traction: String = "",
        saleStart: String = "",
        saleEnd: String = "",
        color: String = "",
        vin: String = "",
        insuranceCompany: String? = null,
        insurancePolicyNumber: String? = null,
        insuranceExpiry: Date? = null,
        insurancePresent: Boolean? = null,
        userId: String
    ): Pair<Int, Int> {
        val token = getAuthToken() ?: throw PlateAPIError.InvalidResponse

        val requestBody = mapOf(
            "plate" to plate.uppercase(),
            "make" to make.ifEmpty { "" },
            "model" to model.ifEmpty { "" },
            "modelDetails" to modelDetails.ifEmpty { "" },
            "registrationDate" to registrationDate.ifEmpty { "" },
            "fuelType" to fuelType.ifEmpty { "" },
            "powerKW" to powerKW.ifEmpty { "" },
            "powerCV" to powerCV.ifEmpty { "" },
            "displacementCC" to displacementCC.ifEmpty { "" },
            "emissionClass" to emissionClass.ifEmpty { "" },
            "gearbox" to gearbox.ifEmpty { "" },
            "maxSpeed" to maxSpeed.ifEmpty { "" },
            "bodyType" to bodyType.ifEmpty { "" },
            "doors" to doors.ifEmpty { "" },
            "seats" to seats.ifEmpty { "" },
            "consumption" to consumption.ifEmpty { "" },
            "traction" to traction.ifEmpty { "" },
            "saleStart" to saleStart.ifEmpty { "" },
            "saleEnd" to saleEnd.ifEmpty { "" },
            "color" to color.ifEmpty { "" },
            "vin" to vin.ifEmpty { "" },
            "insuranceCompany" to (insuranceCompany ?: ""),
            "insurancePolicyNumber" to (insurancePolicyNumber ?: ""),
            "insuranceExpiry" to (insuranceExpiry?.toString() ?: ""),
            "insurancePresent" to (insurancePresent ?: false),
            "userId" to userId
        )

        return try {
            val response: HttpResponse = httpClient.post(manualPlateURL) {
                header(HttpHeaders.Authorization, "Bearer $token")
                contentType(ContentType.Application.Json)
                setBody(requestBody)
            }

            if (response.status.value in 200..299) {
                val decoded = response.body<ManualPlateResponse>()
                Pair(decoded.vehicleId, decoded.plateId)
            } else {
                val errorMessage = response.bodyAsText()
                throw PlateAPIError.ServerError(response.status.value, errorMessage)
            }
        } catch (e: Exception) {
            when (e) {
                is PlateAPIError -> throw e
                else -> throw PlateAPIError.RequestFailed(e)
            }
        }
    }

    /**
     * Associate vehicle to user
     */
    suspend fun associateVehicle2User(
        vehicleId: Int,
        userId: String,
        color: String = "",
        images: List<Bitmap>? = null
    ): Pair<String, String?> {
        val token = getAuthToken() ?: throw PlateAPIError.InvalidResponse
        val url = "$baseURL/v1/vehicles/$vehicleId/user/$userId"

        var imagesBase64: List<String>? = null
        var imagesMime: List<String>? = null
        var imagesAngle: List<Int>? = null

        images?.let { bitmaps ->
            val base64List = mutableListOf<String>()
            val mimeList = mutableListOf<String>()

            bitmaps.forEach { bitmap ->
                val (base64, mime) = bitmapToBase64(bitmap)
                base64List.add(base64)
                mimeList.add(mime)
            }

            imagesBase64 = base64List
            imagesMime = mimeList
            imagesAngle = listOf(23, 23, 12, 12)
        }

        val requestBody = mapOf(
            "color" to color,
            "imagesBase64" to imagesBase64,
            "imagesMime" to imagesMime,
            "imagesAngle" to imagesAngle
        )

        return try {
            val response: HttpResponse = httpClient.post(url) {
                header(HttpHeaders.Authorization, "Bearer $token")
                contentType(ContentType.Application.Json)
                setBody(requestBody)
            }

            if (response.status.value in 200..299) {
                val decoded = response.body<AssociationResponse>()
                Pair(decoded.message, decoded.imageBase64)
            } else {
                val errorMessage = response.bodyAsText()
                throw PlateAPIError.ServerError(response.status.value, errorMessage)
            }
        } catch (e: Exception) {
            when (e) {
                is PlateAPIError -> throw e
                else -> throw PlateAPIError.RequestFailed(e)
            }
        }
    }
}
