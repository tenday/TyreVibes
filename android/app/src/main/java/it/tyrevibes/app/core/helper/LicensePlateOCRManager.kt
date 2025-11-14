package it.tyrevibes.app.core.helper

import android.graphics.Bitmap
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import kotlinx.coroutines.tasks.await
import kotlin.math.abs

/**
 * Risultato del riconoscimento OCR di una targa.
 */
data class LicensePlateOCRResult(
    val plateNumber: String,
    val confidence: Float,
    val boundingBox: android.graphics.Rect? = null,
    val allCandidates: List<String> = emptyList()
)

/**
 * Manager per il riconoscimento OCR delle targhe automobilistiche italiane.
 *
 * Supporta:
 * - Formato targhe italiane (AA123BB, AA123AA, AB123CD)
 * - ML Kit Text Recognition
 * - Validazione e pulizia del testo riconosciuto
 * - Scoring di confidenza basato su formato e caratteristiche
 */
class LicensePlateOCRManager {

    private val textRecognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

    companion object {
        // Pattern regex per targhe italiane
        // Formato standard: 2 lettere + 3 numeri + 2 lettere (es: AB123CD)
        private val ITALIAN_PLATE_PATTERN = Regex("^[A-Z]{2}\\d{3}[A-Z]{2}$")

        // Lettere vietate nelle targhe italiane (I, O, Q, U)
        private val FORBIDDEN_LETTERS = setOf('I', 'O', 'Q', 'U')

        // Mapping comuni per correggere errori OCR
        private val OCR_CORRECTIONS = mapOf(
            '0' to 'O',  // Zero -> O
            '1' to 'I',  // Uno -> I
            '5' to 'S',  // Cinque -> S
            '8' to 'B',  // Otto -> B
            'O' to '0',  // O -> Zero (se in posizione numerica)
            'I' to '1',  // I -> Uno (se in posizione numerica)
            'S' to '5',  // S -> Cinque (se in posizione numerica)
            'B' to '8',  // B -> Otto (se in posizione numerica)
            'Z' to '2',  // Z -> Due (se in posizione numerica)
            'G' to '6'   // G -> Sei (se in posizione numerica)
        )
    }

    /**
     * Riconosce una targa da un'immagine bitmap.
     *
     * @param bitmap Immagine contenente la targa
     * @return Risultato OCR con targa riconosciuta e confidenza
     */
    suspend fun recognizePlate(bitmap: Bitmap): LicensePlateOCRResult? {
        return try {
            val inputImage = InputImage.fromBitmap(bitmap, 0)
            val result = textRecognizer.process(inputImage).await()

            // Analizza tutti i blocchi di testo riconosciuti
            val candidates = mutableListOf<Pair<String, Float>>()

            for (block in result.textBlocks) {
                for (line in block.lines) {
                    val text = line.text.trim()
                        .replace(" ", "")
                        .replace("-", "")
                        .uppercase()

                    // Valida e pulisce il testo
                    val cleaned = cleanAndValidate(text)
                    if (cleaned != null) {
                        val confidence = calculateConfidence(cleaned, line.confidence ?: 0.5f)
                        candidates.add(Pair(cleaned, confidence))
                    }
                }
            }

            // Ordina per confidenza e ritorna il migliore
            if (candidates.isEmpty()) {
                return null
            }

            val sorted = candidates.sortedByDescending { it.second }
            val bestCandidate = sorted.first()

            LicensePlateOCRResult(
                plateNumber = bestCandidate.first,
                confidence = bestCandidate.second,
                boundingBox = null,  // TODO: estrai bounding box se necessario
                allCandidates = sorted.map { it.first }
            )
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    /**
     * Riconosce una targa da un'immagine con path.
     */
    suspend fun recognizePlate(imagePath: String): LicensePlateOCRResult? {
        return try {
            val inputImage = InputImage.fromFilePath(
                null!!,  // TODO: serve Context per fromFilePath
                android.net.Uri.parse(imagePath)
            )
            val result = textRecognizer.process(inputImage).await()

            // Stesso processo di sopra
            // TODO: implementare o riusare la logica
            null
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    /**
     * Pulisce e valida il testo riconosciuto.
     * Corregge errori comuni di OCR e verifica il formato.
     */
    private fun cleanAndValidate(text: String): String? {
        if (text.length < 7 || text.length > 9) {
            return null
        }

        // Rimuovi caratteri non alfanumerici
        val cleaned = text.filter { it.isLetterOrDigit() }.uppercase()

        // Tenta di correggere il formato
        val corrected = tryCorrectFormat(cleaned)

        // Valida formato italiano
        return if (isValidItalianPlate(corrected)) {
            corrected
        } else {
            null
        }
    }

    /**
     * Tenta di correggere il formato della targa applicando regole euristiche.
     */
    private fun tryCorrectFormat(text: String): String {
        if (text.length != 7) {
            // Se troppo corto/lungo, non possiamo correggere
            return text
        }

        val corrected = text.toCharArray()

        // Posizioni 0-1: devono essere lettere
        for (i in 0..1) {
            if (corrected[i].isDigit()) {
                // Cerca una sostituzione lettera
                OCR_CORRECTIONS[corrected[i]]?.let { corrected[i] = it }
            }
        }

        // Posizioni 2-4: devono essere numeri
        for (i in 2..4) {
            if (corrected[i].isLetter()) {
                // Cerca una sostituzione numero
                OCR_CORRECTIONS[corrected[i]]?.let { corrected[i] = it }
            }
        }

        // Posizioni 5-6: devono essere lettere
        for (i in 5..6) {
            if (corrected[i].isDigit()) {
                // Cerca una sostituzione lettera
                OCR_CORRECTIONS[corrected[i]]?.let { corrected[i] = it }
            }
        }

        return String(corrected)
    }

    /**
     * Verifica se la targa è valida secondo il formato italiano.
     */
    private fun isValidItalianPlate(plate: String): Boolean {
        if (!ITALIAN_PLATE_PATTERN.matches(plate)) {
            return false
        }

        // Verifica lettere vietate
        for (i in listOf(0, 1, 5, 6)) {
            if (plate[i] in FORBIDDEN_LETTERS) {
                return false
            }
        }

        return true
    }

    /**
     * Calcola la confidenza del riconoscimento.
     * Combina la confidenza ML Kit con validazioni euristiche.
     */
    private fun calculateConfidence(plate: String, mlConfidence: Float): Float {
        var confidence = mlConfidence

        // Bonus se rispetta perfettamente il pattern
        if (ITALIAN_PLATE_PATTERN.matches(plate)) {
            confidence += 0.1f
        }

        // Penalità se contiene lettere vietate
        for (i in listOf(0, 1, 5, 6)) {
            if (plate.getOrNull(i) in FORBIDDEN_LETTERS) {
                confidence -= 0.2f
            }
        }

        // Bonus se la lunghezza è esatta
        if (plate.length == 7) {
            confidence += 0.05f
        }

        return confidence.coerceIn(0f, 1f)
    }

    /**
     * Valida manualmente una targa inserita dall'utente.
     */
    fun validateManualPlate(plate: String): Boolean {
        val cleaned = plate
            .trim()
            .replace(" ", "")
            .replace("-", "")
            .uppercase()

        return isValidItalianPlate(cleaned)
    }

    /**
     * Formatta una targa per la visualizzazione.
     * Es: AB123CD -> AB 123 CD
     */
    fun formatPlate(plate: String): String {
        if (plate.length != 7) {
            return plate
        }

        return "${plate.substring(0, 2)} ${plate.substring(2, 5)} ${plate.substring(5, 7)}"
    }

    /**
     * Rimuove la formattazione da una targa.
     * Es: AB 123 CD -> AB123CD
     */
    fun unformatPlate(plate: String): String {
        return plate
            .replace(" ", "")
            .replace("-", "")
            .uppercase()
    }

    /**
     * Rilascia le risorse del text recognizer.
     */
    fun release() {
        textRecognizer.close()
    }
}
