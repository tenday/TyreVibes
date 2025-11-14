package it.tyrevibes.app.core.helper

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import android.text.TextPaint
import it.tyrevibes.app.core.model.*
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.*

/**
 * Generatore di report PDF per l'analisi dei pneumatici.
 *
 * Crea report multi-pagina con:
 * - Pagina di copertina con badge di sicurezza
 * - Riepilogo esecutivo con metriche chiave
 * - Mappa di calore della profondità
 * - Analisi dettagliata dell'usura
 * - Grafici e statistiche
 * - Raccomandazioni prioritizzate
 */
class PDFReportBuilder {

    companion object {
        // Dimensioni pagina A4 in punti (1 punto = 1/72 inch)
        private const val PAGE_WIDTH = 595
        private const val PAGE_HEIGHT = 842
        private const val MARGIN = 40f

        // Colori
        private val COLOR_PRIMARY = Color.parseColor("#FF6B6B")
        private val COLOR_GRAY = Color.parseColor("#F5F5F5")
        private val COLOR_DARK_GRAY = Color.parseColor("#666666")
    }

    private var currentY = MARGIN

    /**
     * Genera un PDF completo dal report di analisi.
     *
     * @param report Report completo dell'analisi pneumatico
     * @param outputFile File di destinazione per il PDF
     * @return true se generato con successo, false altrimenti
     */
    fun generatePDF(report: TyreAnalysisReport, outputFile: File): Boolean {
        return try {
            val pdfDocument = PdfDocument()

            // Pagina 1: Copertina
            drawCoverPage(pdfDocument, report)

            // Pagina 2: Riepilogo Esecutivo
            drawExecutiveSummary(pdfDocument, report)

            // Pagina 3: Mappa di Calore
            drawHeatMapPage(pdfDocument, report)

            // Pagina 4: Analisi Dettagliata
            drawDetailedAnalysis(pdfDocument, report)

            // Pagina 5: Grafici e Statistiche
            drawChartsPage(pdfDocument, report)

            // Pagina 6: Raccomandazioni
            drawRecommendationsPage(pdfDocument, report)

            // Salva il PDF
            pdfDocument.writeTo(FileOutputStream(outputFile))
            pdfDocument.close()

            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    /**
     * Pagina 1: Copertina con informazioni veicolo e pneumatico
     */
    private fun drawCoverPage(pdfDocument: PdfDocument, report: TyreAnalysisReport) {
        val pageInfo = PdfDocument.PageInfo.Builder(PAGE_WIDTH, PAGE_HEIGHT, 1).create()
        val page = pdfDocument.startPage(pageInfo)
        val canvas = page.canvas
        currentY = MARGIN

        // Titolo app
        val titlePaint = TextPaint().apply {
            color = COLOR_PRIMARY
            textSize = 48f
            isFakeBoldText = true
            textAlign = Paint.Align.CENTER
        }
        canvas.drawText("TYREVIBES", PAGE_WIDTH / 2f, 100f, titlePaint)

        // Titolo report
        val reportTitlePaint = TextPaint().apply {
            color = Color.BLACK
            textSize = 32f
            isFakeBoldText = true
            textAlign = Paint.Align.CENTER
        }
        canvas.drawText("Tyre Analysis Report", PAGE_WIDTH / 2f, 180f, reportTitlePaint)

        // Box informazioni veicolo
        currentY = 260f
        val boxPaint = Paint().apply {
            color = COLOR_GRAY
            style = Paint.Style.FILL
        }
        canvas.drawRect(MARGIN, currentY, PAGE_WIDTH - MARGIN, currentY + 120f, boxPaint)

        // Dettagli veicolo
        val infoPaint = TextPaint().apply {
            color = COLOR_DARK_GRAY
            textSize = 14f
        }
        currentY += 20f
        val vehicleInfo = """
            Vehicle: ${report.metadata.vehicle.make} ${report.metadata.vehicle.model}
            Plate: ${report.metadata.vehicle.plateNumber}
            Year: ${report.metadata.vehicle.year ?: "N/A"}

            Tyre: ${report.metadata.tyre.brand} ${report.metadata.tyre.model}
            Size: ${report.metadata.tyre.size}
            Position: ${report.metadata.tyre.position.displayName}
        """.trimIndent()

        vehicleInfo.lines().forEachIndexed { index, line ->
            canvas.drawText(line, MARGIN + 20f, currentY + (index * 20f), infoPaint)
        }

        currentY += 140f

        // Badge punteggio sicurezza (cerchio con score)
        val badgeX = PAGE_WIDTH / 2f
        val badgeY = currentY + 80f
        val radius = 60f

        val badgePaint = Paint().apply {
            color = getSafetyColor(report.safetyScore.overall)
            style = Paint.Style.FILL
        }
        canvas.drawCircle(badgeX, badgeY, radius, badgePaint)

        val scorePaint = TextPaint().apply {
            color = Color.WHITE
            textSize = 36f
            isFakeBoldText = true
            textAlign = Paint.Align.CENTER
        }
        canvas.drawText(
            String.format("%.0f", report.safetyScore.overall),
            badgeX,
            badgeY + 12f,
            scorePaint
        )

        currentY += 200f

        // Metadati report
        val dateFormatter = SimpleDateFormat("dd MMM yyyy, HH:mm", Locale.getDefault())
        val metadataPaint = TextPaint().apply {
            color = Color.GRAY
            textSize = 12f
        }
        val metadata = """
            Report ID: ${report.metadata.reportId}
            Generated: ${dateFormatter.format(Date(report.metadata.timestamp))}
            Analysis Type: ${report.metadata.analysisType.displayName}
        """.trimIndent()

        metadata.lines().forEachIndexed { index, line ->
            canvas.drawText(line, MARGIN, currentY + (index * 20f), metadataPaint)
        }

        // Footer
        drawFooter(canvas, 1, 6)

        pdfDocument.finishPage(page)
    }

    /**
     * Pagina 2: Riepilogo Esecutivo
     */
    private fun drawExecutiveSummary(pdfDocument: PdfDocument, report: TyreAnalysisReport) {
        val pageInfo = PdfDocument.PageInfo.Builder(PAGE_WIDTH, PAGE_HEIGHT, 2).create()
        val page = pdfDocument.startPage(pageInfo)
        val canvas = page.canvas
        currentY = MARGIN

        drawHeader(canvas, "Executive Summary")
        currentY += 20f

        // Stato di sicurezza
        val statusPaint = TextPaint().apply {
            color = Color.BLACK
            textSize = 16f
            isFakeBoldText = true
        }
        canvas.drawText("Safety Status", MARGIN, currentY, statusPaint)
        currentY += 30f

        val ratingPaint = TextPaint().apply {
            color = getSafetyColor(report.safetyScore.overall)
            textSize = 14f
        }
        canvas.drawText(report.safetyScore.rating.name, MARGIN + 20f, currentY, ratingPaint)
        currentY += 40f

        // Metriche chiave
        drawSectionTitle(canvas, "Key Metrics")

        val metrics = listOf(
            "Average Depth" to String.format("%.2f mm", report.depthAnalysis.avgDepth),
            "Minimum Depth" to String.format("%.2f mm", report.depthAnalysis.minDepth),
            "Wear Pattern" to report.wearAnalysis.wearPattern.displayName,
            "Wear Severity" to String.format("%.1f%%", report.wearAnalysis.severity * 100),
            "Est. Remaining Life" to report.remainingLife.formattedDistance,
            "Est. Time" to "${report.remainingLife.estimatedMonths} months"
        )

        metrics.forEach { (label, value) ->
            drawMetricRow(canvas, label, value)
            currentY += 30f
        }

        currentY += 20f

        // Testo riassuntivo
        val summaryText = generateSummaryText(report)
        val summaryPaint = TextPaint().apply {
            color = COLOR_DARK_GRAY
            textSize = 13f
        }

        var lineY = currentY
        summaryText.split("\n").forEach { line ->
            canvas.drawText(line, MARGIN, lineY, summaryPaint)
            lineY += 20f
        }

        drawFooter(canvas, 2, 6)
        pdfDocument.finishPage(page)
    }

    /**
     * Pagina 3: Mappa di Calore (placeholder - richiede rendering bitmap)
     */
    private fun drawHeatMapPage(pdfDocument: PdfDocument, report: TyreAnalysisReport) {
        val pageInfo = PdfDocument.PageInfo.Builder(PAGE_WIDTH, PAGE_HEIGHT, 3).create()
        val page = pdfDocument.startPage(pageInfo)
        val canvas = page.canvas
        currentY = MARGIN

        drawHeader(canvas, "Depth Heat Map")
        currentY += 20f

        // TODO: Implementare rendering heat map come bitmap
        val placeholderPaint = TextPaint().apply {
            color = COLOR_DARK_GRAY
            textSize = 14f
            textAlign = Paint.Align.CENTER
        }
        canvas.drawText(
            "[Heat Map Visualization - To be implemented]",
            PAGE_WIDTH / 2f,
            currentY + 150f,
            placeholderPaint
        )

        currentY += 320f

        // Legenda
        drawSectionTitle(canvas, "Depth Legend")
        currentY += 10f

        val legendPaint = TextPaint().apply {
            color = Color.BLACK
            textSize = 12f
        }
        canvas.drawText(
            "Min: ${String.format("%.2f", report.depthAnalysis.minDepth)} mm",
            MARGIN,
            currentY,
            legendPaint
        )
        canvas.drawText(
            "Max: ${String.format("%.2f", report.depthAnalysis.maxDepth)} mm",
            PAGE_WIDTH - MARGIN - 100f,
            currentY,
            legendPaint
        )

        drawFooter(canvas, 3, 6)
        pdfDocument.finishPage(page)
    }

    /**
     * Pagina 4: Analisi Dettagliata
     */
    private fun drawDetailedAnalysis(pdfDocument: PdfDocument, report: TyreAnalysisReport) {
        val pageInfo = PdfDocument.PageInfo.Builder(PAGE_WIDTH, PAGE_HEIGHT, 4).create()
        val page = pdfDocument.startPage(pageInfo)
        val canvas = page.canvas
        currentY = MARGIN

        drawHeader(canvas, "Detailed Analysis")
        currentY += 20f

        // Analisi usura
        drawSubHeader(canvas, "Wear Pattern Analysis")

        val wearInfo = """
            Pattern: ${report.wearAnalysis.wearPattern.displayName}
            Severity: ${String.format("%.1f%%", report.wearAnalysis.severity * 100)}
        """.trimIndent()

        val infoPaint = TextPaint().apply {
            color = COLOR_DARK_GRAY
            textSize = 13f
        }

        wearInfo.lines().forEachIndexed { index, line ->
            canvas.drawText(line, MARGIN, currentY + (index * 20f), infoPaint)
        }

        currentY += 60f

        // Cause probabili
        drawSubHeader(canvas, "Probable Causes")

        report.wearAnalysis.likelyCauses.forEach { cause ->
            val causePaint = TextPaint().apply {
                color = Color.BLACK
                textSize = 12f
            }
            canvas.drawText(
                "• ${cause.type.displayName} (${(cause.probability * 100).toInt()}%)",
                MARGIN + 10f,
                currentY,
                causePaint
            )
            currentY += 20f

            val descPaint = TextPaint().apply {
                color = Color.GRAY
                textSize = 11f
            }
            canvas.drawText(cause.description, MARGIN + 20f, currentY, descPaint)
            currentY += 25f
        }

        currentY += 20f

        // Vita residua
        drawSubHeader(canvas, "Remaining Life Estimate")

        val lifeInfo = """
            Estimated Distance: ${report.remainingLife.formattedDistance}
            Estimated Time: ${report.remainingLife.estimatedMonths} months
            Confidence: ${(report.remainingLife.confidence * 100).toInt()}%
            Method: ${report.remainingLife.calculationMethod.displayName}
        """.trimIndent()

        lifeInfo.lines().forEachIndexed { index, line ->
            canvas.drawText(line, MARGIN, currentY + (index * 20f), infoPaint)
        }

        drawFooter(canvas, 4, 6)
        pdfDocument.finishPage(page)
    }

    /**
     * Pagina 5: Grafici (placeholder - richiede rendering grafici)
     */
    private fun drawChartsPage(pdfDocument: PdfDocument, report: TyreAnalysisReport) {
        val pageInfo = PdfDocument.PageInfo.Builder(PAGE_WIDTH, PAGE_HEIGHT, 5).create()
        val page = pdfDocument.startPage(pageInfo)
        val canvas = page.canvas
        currentY = MARGIN

        drawHeader(canvas, "Statistics & Charts")
        currentY += 20f

        // TODO: Implementare grafici di distribuzione e componenti score
        val placeholderPaint = TextPaint().apply {
            color = COLOR_DARK_GRAY
            textSize = 14f
            textAlign = Paint.Align.CENTER
        }
        canvas.drawText(
            "[Charts & Statistics - To be implemented]",
            PAGE_WIDTH / 2f,
            PAGE_HEIGHT / 2f,
            placeholderPaint
        )

        drawFooter(canvas, 5, 6)
        pdfDocument.finishPage(page)
    }

    /**
     * Pagina 6: Raccomandazioni
     */
    private fun drawRecommendationsPage(pdfDocument: PdfDocument, report: TyreAnalysisReport) {
        val pageInfo = PdfDocument.PageInfo.Builder(PAGE_WIDTH, PAGE_HEIGHT, 6).create()
        val page = pdfDocument.startPage(pageInfo)
        val canvas = page.canvas
        currentY = MARGIN

        drawHeader(canvas, "Recommendations")
        currentY += 20f

        // Ordina per priorità
        val sorted = report.recommendations.sortedBy { it.priority.ordinal }

        sorted.forEach { recommendation ->
            // Badge priorità
            val badgePaint = Paint().apply {
                color = getPriorityColor(recommendation.priority.name)
                style = Paint.Style.FILL
            }
            canvas.drawRect(MARGIN, currentY, MARGIN + 80f, currentY + 25f, badgePaint)

            val priorityPaint = TextPaint().apply {
                color = Color.WHITE
                textSize = 11f
                isFakeBoldText = true
            }
            canvas.drawText(
                recommendation.priority.name,
                MARGIN + 10f,
                currentY + 18f,
                priorityPaint
            )

            currentY += 30f

            // Titolo
            val titlePaint = TextPaint().apply {
                color = Color.BLACK
                textSize = 14f
                isFakeBoldText = true
            }
            canvas.drawText(recommendation.title, MARGIN, currentY, titlePaint)

            currentY += 25f

            // Descrizione
            val descPaint = TextPaint().apply {
                color = COLOR_DARK_GRAY
                textSize = 12f
            }
            canvas.drawText(recommendation.description, MARGIN, currentY, descPaint)

            currentY += 25f

            // Azione
            val actionPaint = TextPaint().apply {
                color = COLOR_PRIMARY
                textSize = 12f
            }
            canvas.drawText("Action: ${recommendation.action}", MARGIN, currentY, actionPaint)

            currentY += 40f
        }

        drawFooter(canvas, 6, 6)
        pdfDocument.finishPage(page)
    }

    // MARK: - Helper Methods

    private fun drawHeader(canvas: Canvas, title: String) {
        val headerPaint = TextPaint().apply {
            color = COLOR_PRIMARY
            textSize = 24f
            isFakeBoldText = true
        }
        canvas.drawText(title, MARGIN, currentY, headerPaint)
        currentY += 35f

        // Underline
        val linePaint = Paint().apply {
            color = COLOR_PRIMARY
            strokeWidth = 2f
        }
        canvas.drawLine(MARGIN, currentY, PAGE_WIDTH - MARGIN, currentY, linePaint)
        currentY += 10f
    }

    private fun drawSubHeader(canvas: Canvas, title: String) {
        val subHeaderPaint = TextPaint().apply {
            color = Color.BLACK
            textSize = 16f
            isFakeBoldText = true
        }
        canvas.drawText(title, MARGIN, currentY, subHeaderPaint)
        currentY += 30f
    }

    private fun drawSectionTitle(canvas: Canvas, title: String) {
        val titlePaint = TextPaint().apply {
            color = COLOR_DARK_GRAY
            textSize = 14f
            isFakeBoldText = true
        }
        canvas.drawText(title, MARGIN, currentY, titlePaint)
        currentY += 25f
    }

    private fun drawMetricRow(canvas: Canvas, label: String, value: String) {
        val labelPaint = TextPaint().apply {
            color = COLOR_DARK_GRAY
            textSize = 13f
        }
        canvas.drawText(label, MARGIN, currentY, labelPaint)

        val valuePaint = TextPaint().apply {
            color = Color.BLACK
            textSize = 13f
            isFakeBoldText = true
            textAlign = Paint.Align.RIGHT
        }
        canvas.drawText(value, PAGE_WIDTH - MARGIN, currentY, valuePaint)
    }

    private fun drawFooter(canvas: Canvas, pageNumber: Int, totalPages: Int) {
        val footerY = PAGE_HEIGHT - 30f
        val footerPaint = TextPaint().apply {
            color = Color.GRAY
            textSize = 10f
            textAlign = Paint.Align.CENTER
        }
        canvas.drawText(
            "Page $pageNumber of $totalPages • Generated by TyreVibes",
            PAGE_WIDTH / 2f,
            footerY,
            footerPaint
        )
    }

    private fun generateSummaryText(report: TyreAnalysisReport): String {
        return """
            This comprehensive tyre analysis report provides detailed insights into the condition
            and remaining life of your tyre. The analysis reveals that your tyre has an average
            depth of ${String.format("%.2f", report.depthAnalysis.avgDepth)}mm, with a
            ${report.wearAnalysis.wearPattern.displayName.lowercase()} wear pattern.

            Based on current wear rates and driving conditions, the estimated remaining life is
            approximately ${report.remainingLife.formattedDistance} or
            ${report.remainingLife.estimatedMonths} months.
        """.trimIndent()
    }

    private fun getSafetyColor(score: Double): Int {
        return when {
            score >= 80 -> Color.parseColor("#4CAF50")  // Green
            score >= 60 -> Color.parseColor("#2196F3")  // Blue
            score >= 40 -> Color.parseColor("#FFEB3B")  // Yellow
            score >= 20 -> Color.parseColor("#FF9800")  // Orange
            else -> Color.parseColor("#F44336")         // Red
        }
    }

    private fun getPriorityColor(priority: String): Int {
        return when (priority.lowercase()) {
            "urgent", "high" -> Color.parseColor("#F44336")    // Red
            "medium" -> Color.parseColor("#FF9800")           // Orange
            "low" -> Color.parseColor("#4CAF50")              // Green
            else -> Color.GRAY
        }
    }
}
