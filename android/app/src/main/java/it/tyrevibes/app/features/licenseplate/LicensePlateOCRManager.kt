package it.tyrevibes.app.features.licenseplate

import android.content.Context
import android.graphics.Bitmap
import android.util.Log
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import java.util.regex.Pattern

/**
 * License Plate OCR Manager
 * Gestisce il riconoscimento OCR delle targhe usando ML Kit
 */
class LicensePlateOCRManager(private val context: Context) {

    private val textRecognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

    // Italian license plate patterns
    private val italianPlatePattern = Pattern.compile("^[A-Z]{2}[0-9]{3}[A-Z]{2}$") // AA123BB
    private val oldItalianPlatePattern = Pattern.compile("^[A-Z]{2}[0-9]{4,6}$") // AA1234

    /**
     * Recognize text from image
     */
    suspend fun recognizePlate(bitmap: Bitmap): LicensePlateResult = withContext(Dispatchers.IO) {
        try {
            val inputImage = InputImage.fromBitmap(bitmap, 0)
            val result = textRecognizer.process(inputImage).await()

            val detectedTexts = result.textBlocks.flatMap { block ->
                block.lines.map { line -> line.text }
            }

            Log.d(TAG, "Detected texts: $detectedTexts")

            // Try to find valid plate number
            val plateNumber = detectedTexts
                .map { cleanText(it) }
                .firstOrNull { isValidPlate(it) }

            if (plateNumber != null) {
                LicensePlateResult.Success(plateNumber)
            } else {
                LicensePlateResult.NotFound(detectedTexts)
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error recognizing plate", e)
            LicensePlateResult.Error(e.message ?: "Unknown error")
        }
    }

    /**
     * Clean OCR text (remove spaces, special chars)
     */
    private fun cleanText(text: String): String {
        return text
            .replace(" ", "")
            .replace("-", "")
            .replace(".", "")
            .uppercase()
            .filter { it.isLetterOrDigit() }
    }

    /**
     * Validate Italian license plate format
     */
    private fun isValidPlate(text: String): Boolean {
        return italianPlatePattern.matcher(text).matches() ||
                oldItalianPlatePattern.matcher(text).matches()
    }

    /**
     * Release resources
     */
    fun release() {
        textRecognizer.close()
    }

    companion object {
        private const val TAG = "LicensePlateOCR"
    }
}

/**
 * Result of license plate recognition
 */
sealed class LicensePlateResult {
    data class Success(val plateNumber: String) : LicensePlateResult()
    data class NotFound(val detectedTexts: List<String>) : LicensePlateResult()
    data class Error(val message: String) : LicensePlateResult()
}
