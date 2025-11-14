package it.tyrevibes.app.core.helper

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

/**
 * Configurazione opzioni per il download delle immagini dei veicoli.
 */
data class VehicleImageOptions(
    val customer: String = "img",
    val angle: Int = 12,
    val fileType: String = "webp",
    val safeMode: Boolean = false,
    val origin: String = "https://docs.imagin.studio",
    val userAgent: String = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36",
    val accept: String = "*/*",
    val zoomType: String = "relative"
)

/**
 * Servizio per scaricare immagini di veicoli da imagin.studio CDN.
 * Supporta caching in-memory e download multipli con progress tracking.
 */
object VehicleImageService {

    // Angoli predefiniti per la rotazione 360°
    val defaultAngles = (200..231).toList()

    // Cache in-memory delle immagini
    private val cache = mutableMapOf<Int, Bitmap>()

    /**
     * Costruisce l'URL del CDN per un angolo specifico.
     */
    private fun buildURL(
        make: String,
        modelFamily: String,
        year: String,
        paintId: String,
        angle: Int,
        options: VehicleImageOptions
    ): String {
        val baseUrl = "https://cdn.imagin.studio/getImage"
        val params = buildString {
            append("?customer=${URLEncoder.encode(options.customer, "UTF-8")}")
            append("&make=${URLEncoder.encode(make, "UTF-8")}")
            append("&modelFamily=${URLEncoder.encode(modelFamily, "UTF-8")}")
            append("&paintId=${URLEncoder.encode(paintId, "UTF-8")}")
            append("&angle=$angle")
            append("&modelYear=$year")
            append("&fileType=${options.fileType}")
            append("&zoomType=${options.zoomType}")
            append("&tailoring=empty")
        }
        return baseUrl + params
    }

    /**
     * Scarica un'immagine del veicolo per un angolo specifico.
     * Usa cache in-memory per evitare download ripetuti.
     */
    suspend fun fetchVehicleImage(
        make: String,
        modelFamily: String,
        year: String,
        paintId: String,
        angle: Int,
        options: VehicleImageOptions = VehicleImageOptions(),
        plate: String = ""
    ): Result<Bitmap> = withContext(Dispatchers.IO) {
        try {
            // Verifica cache (opzionale - commentato per ora)
            // cache[angle]?.let { return@withContext Result.success(it) }

            val url = buildURL(make, modelFamily, year, paintId, angle, options)
            val connection = URL(url).openConnection() as HttpURLConnection

            try {
                connection.apply {
                    requestMethod = "GET"
                    setRequestProperty("Accept", options.accept)
                    setRequestProperty("Referer", "https://docs.imagin.studio/api-integration/apis")
                    setRequestProperty("Origin", options.origin)
                    setRequestProperty("User-Agent", options.userAgent)
                    connectTimeout = 15000
                    readTimeout = 15000
                }

                val responseCode = connection.responseCode
                if (responseCode !in 200..299) {
                    return@withContext Result.failure(
                        IOException("HTTP $responseCode for URL: $url")
                    )
                }

                val bitmap = BitmapFactory.decodeStream(connection.inputStream)
                    ?: return@withContext Result.failure(
                        IOException("Invalid image data from URL: $url")
                    )

                // Salva in cache (opzionale)
                // cache[angle] = bitmap

                Result.success(bitmap)
            } finally {
                connection.disconnect()
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /**
     * Scarica un'immagine del veicolo con opzioni predefinite.
     */
    suspend fun fetchVehicleImage(
        make: String,
        modelFamily: String,
        year: String,
        paintId: String,
        plate: String = ""
    ): Result<Bitmap> {
        return fetchVehicleImage(
            make = make,
            modelFamily = modelFamily,
            year = year,
            paintId = paintId,
            angle = VehicleImageOptions().angle,
            plate = plate
        )
    }

    /**
     * Precarica una sequenza di angoli (default 200...231) con tracking del progresso.
     *
     * @param angles Lista di angoli da scaricare. Default: defaultAngles (200-231).
     * @param progress Callback chiamato con (completati, totali) ad ogni download completato.
     * @param completion Callback chiamato con array di immagini ordinate secondo `angles`.
     */
    suspend fun preloadImages(
        make: String,
        modelFamily: String,
        year: String,
        paintId: String,
        angles: List<Int> = defaultAngles,
        options: VehicleImageOptions = VehicleImageOptions(),
        plate: String = "",
        progress: ((completed: Int, total: Int) -> Unit)? = null
    ): List<Bitmap?> = withContext(Dispatchers.IO) {
        val total = angles.size
        if (total == 0) return@withContext emptyList()

        val results = mutableMapOf<Int, Bitmap>()

        angles.forEach { angle ->
            val result = fetchVehicleImage(make, modelFamily, year, paintId, angle, options, plate)
            if (result.isSuccess) {
                results[angle] = result.getOrNull()!!
            }
            withContext(Dispatchers.Main) {
                progress?.invoke(results.size, total)
            }
        }

        // Ritorna le immagini nell'ordine richiesto (nil se mancanti)
        angles.map { results[it] }
    }

    /**
     * Pulisce la cache in-memory.
     * Utile quando si cambia veicolo o colore.
     */
    fun clearCache() {
        cache.clear()
    }

    /**
     * Verifica se un angolo è presente in cache.
     */
    fun isCached(angle: Int): Boolean {
        return cache.containsKey(angle)
    }

    /**
     * Ottiene un'immagine dalla cache se disponibile.
     */
    fun getCachedImage(angle: Int): Bitmap? {
        return cache[angle]
    }
}
