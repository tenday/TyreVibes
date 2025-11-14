package it.tyrevibes.app.core.helper

import it.tyrevibes.app.core.model.*
import kotlin.math.exp
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sqrt

/**
 * Dati storici per il calcolo della vita residua basato su misurazioni precedenti.
 */
data class HistoricalDataPoint(
    val timestamp: Long,  // Unix timestamp in milliseconds
    val depth: Double,    // mm
    val kilometers: Double
)

/**
 * Fattore che influenza la vita residua del pneumatico.
 */
data class LifeFactor(
    val name: String,
    val impact: Double,      // -1 to +1 (negative = riduzione vita, positive = incremento vita)
    val description: String
)

/**
 * Proiezione della profondità del battistrada nel tempo.
 */
data class DepthProjection(
    val kilometersFromNow: Double,
    val projectedDepth: Double,
    val confidence: Double
)

/**
 * Calcolatore avanzato della vita residua dei pneumatici.
 * Supporta 3 metodi di calcolo: Linear, Exponential, Historical.
 */
class RemainingLifeCalculator {

    companion object {
        // Costanti
        private const val LEGAL_MINIMUM_DEPTH = 1.6  // mm (limite legale in Italia/EU)
        private const val NEW_TYRE_DEPTH = 8.0       // mm (tipico per pneumatici nuovi)
        private const val AVERAGE_WEAR_RATE_PER_KM = 0.00015  // mm per km (tipico)
        private const val AVERAGE_KM_PER_MONTH = 1250.0  // 15,000 km/anno ÷ 12 mesi
    }

    /**
     * Calcola la vita residua stimata analizzando profondità e usura.
     *
     * @param depthAnalysis Analisi della profondità del battistrada
     * @param wearAnalysis Analisi del pattern di usura
     * @param vehicleInfo Informazioni opzionali sul veicolo
     * @param historicalData Dati storici opzionali per predizione più accurata
     * @return Stima della vita residua con metodo di calcolo e confidenza
     */
    fun calculateRemainingLife(
        depthAnalysis: DepthAnalysis,
        wearAnalysis: WearAnalysis,
        vehicleInfo: VehicleInfo? = null,
        historicalData: List<HistoricalDataPoint>? = null
    ): RemainingLifeEstimate {

        // Scelta del metodo di calcolo in base ai dati disponibili
        val (method, estimatedKm, confidence) = when {
            !historicalData.isNullOrEmpty() && historicalData.size >= 2 -> {
                // Metodo storico: usa dati di usura precedenti
                val result = calculateFromHistoricalData(historicalData, depthAnalysis.avgDepth)
                Triple(RemainingLifeEstimate.CalculationMethod.HISTORICAL, result.first, result.second)
            }
            depthAnalysis.measurementPoints.size > 20 -> {
                // Metodo esponenziale: per dataset dettagliati
                val result = calculateExponentialModel(depthAnalysis, wearAnalysis)
                Triple(RemainingLifeEstimate.CalculationMethod.EXPONENTIAL, result.first, result.second)
            }
            else -> {
                // Metodo lineare: fallback per dati limitati
                val result = calculateLinearModel(depthAnalysis, wearAnalysis)
                Triple(RemainingLifeEstimate.CalculationMethod.LINEAR, result.first, result.second)
            }
        }

        // Calcola mesi stimati
        val estimatedMonths = estimateMonths(estimatedKm, wearAnalysis)

        return RemainingLifeEstimate(
            estimatedKilometers = max(0.0, estimatedKm),
            estimatedMonths = max(0, estimatedMonths),
            confidence = confidence,
            calculationMethod = method
        )
    }

    /**
     * Metodo di calcolo lineare.
     * Usa un tasso di usura costante adattato al pattern di usura.
     */
    private fun calculateLinearModel(
        depthAnalysis: DepthAnalysis,
        wearAnalysis: WearAnalysis
    ): Pair<Double, Double> {

        val currentDepth = depthAnalysis.avgDepth
        val depthRemaining = currentDepth - LEGAL_MINIMUM_DEPTH

        if (depthRemaining <= 0) {
            return Pair(0.0, 1.0)
        }

        // Tasso di usura base
        var wearRate = AVERAGE_WEAR_RATE_PER_KM

        // Adatta il tasso in base al pattern di usura
        wearRate *= when (wearAnalysis.wearPattern) {
            WearAnalysis.WearPattern.EVEN -> 1.0
            WearAnalysis.WearPattern.CENTER -> 1.3
            WearAnalysis.WearPattern.EDGE -> 1.4
            WearAnalysis.WearPattern.ONE_SIDE -> 1.35
            WearAnalysis.WearPattern.CUPPING -> 1.6
            WearAnalysis.WearPattern.FEATHERING -> 1.4
        }

        // Adatta in base alla severità
        wearRate *= when {
            wearAnalysis.severity < 0.2 -> 0.9   // Minimal
            wearAnalysis.severity < 0.4 -> 1.0   // Moderate
            wearAnalysis.severity < 0.6 -> 1.2   // Significant
            wearAnalysis.severity < 0.8 -> 1.4   // Severe
            else -> 1.6                          // Critical
        }

        val estimatedKm = depthRemaining / wearRate

        // La confidenza diminuisce con usura irregolare
        val confidence = (1.0 - (wearAnalysis.severity * 0.5)).coerceIn(0.3, 1.0)

        return Pair(estimatedKm, confidence)
    }

    /**
     * Metodo di calcolo esponenziale.
     * Modella l'usura come decadimento esponenziale: depth(t) = initial * e^(-k*t)
     */
    private fun calculateExponentialModel(
        depthAnalysis: DepthAnalysis,
        wearAnalysis: WearAnalysis
    ): Pair<Double, Double> {

        val currentDepth = depthAnalysis.avgDepth
        val depthRemaining = currentDepth - LEGAL_MINIMUM_DEPTH

        if (depthRemaining <= 0) {
            return Pair(0.0, 1.0)
        }

        // Risolvi per t quando depth = legal minimum
        val depthRatio = LEGAL_MINIMUM_DEPTH / currentDepth
        var k = 0.00005  // Costante di decadimento (tipica)

        // Adatta k in base alla severità
        k *= when {
            wearAnalysis.severity < 0.2 -> 0.8   // Minimal
            wearAnalysis.severity < 0.4 -> 1.0   // Moderate
            wearAnalysis.severity < 0.6 -> 1.3   // Significant
            wearAnalysis.severity < 0.8 -> 1.6   // Severe
            else -> 2.0                          // Critical
        }

        val estimatedKm = -ln(depthRatio) / k

        val confidence = (0.75 - (wearAnalysis.severity * 0.3)).coerceIn(0.4, 1.0)

        return Pair(estimatedKm, confidence)
    }

    /**
     * Metodo di calcolo storico.
     * Usa dati di misurazioni precedenti per calcolare il tasso di usura reale.
     */
    private fun calculateFromHistoricalData(
        historicalData: List<HistoricalDataPoint>,
        currentDepth: Double
    ): Pair<Double, Double> {

        if (historicalData.size < 2) {
            return Pair(0.0, 0.3)
        }

        // Ordina per timestamp
        val sorted = historicalData.sortedBy { it.timestamp }

        // Calcola i tassi di usura da coppie consecutive
        val wearRates = mutableListOf<Double>()

        for (i in 1 until sorted.size) {
            val kmDiff = sorted[i].kilometers - sorted[i - 1].kilometers
            val depthDiff = sorted[i - 1].depth - sorted[i].depth  // La profondità diminuisce

            if (kmDiff > 0 && depthDiff > 0) {
                val rate = depthDiff / kmDiff
                wearRates.add(rate)
            }
        }

        if (wearRates.isEmpty()) {
            return Pair(0.0, 0.3)
        }

        // Tasso medio di usura
        val avgWearRate = wearRates.average()

        // Calcola deviazione standard per la confidenza
        val mean = avgWearRate
        val variance = wearRates.map { (it - mean).pow(2) }.average()
        val stdDev = sqrt(variance)
        val coefficientOfVariation = if (mean != 0.0) stdDev / mean else 1.0

        val depthRemaining = currentDepth - LEGAL_MINIMUM_DEPTH
        val estimatedKm = if (avgWearRate > 0) depthRemaining / avgWearRate else 0.0

        // Confidenza basata sulla consistenza dei dati
        val confidence = max(0.5, 1.0 - coefficientOfVariation).coerceAtMost(0.95)

        return Pair(estimatedKm, confidence)
    }

    /**
     * Stima i mesi rimanenti in base ai km stimati.
     * Assume una guida media di 15.000 km/anno.
     */
    private fun estimateMonths(kilometers: Double, wearAnalysis: WearAnalysis): Int {
        val months = kilometers / AVERAGE_KM_PER_MONTH
        return months.toInt()
    }

    /**
     * Identifica i fattori che influenzano la vita residua.
     * Restituisce una lista di fattori con impatto positivo/negativo.
     */
    fun identifyLifeFactors(
        depthAnalysis: DepthAnalysis,
        wearAnalysis: WearAnalysis,
        vehicleInfo: VehicleInfo? = null
    ): List<LifeFactor> {

        val factors = mutableListOf<LifeFactor>()

        // Fattore pattern di usura
        when (wearAnalysis.wearPattern) {
            WearAnalysis.WearPattern.EVEN -> {
                factors.add(LifeFactor(
                    name = "Usura Uniforme",
                    impact = 0.15,
                    description = "L'usura uniforme indica buone pratiche di manutenzione"
                ))
            }
            WearAnalysis.WearPattern.CENTER -> {
                factors.add(LifeFactor(
                    name = "Usura Centrale",
                    impact = -0.25,
                    description = "Sovra-gonfiaggio riduce la vita del pneumatico"
                ))
            }
            WearAnalysis.WearPattern.EDGE, WearAnalysis.WearPattern.ONE_SIDE -> {
                factors.add(LifeFactor(
                    name = "Usura Laterale",
                    impact = -0.30,
                    description = "Sotto-gonfiaggio o disallineamento accelera l'usura"
                ))
            }
            WearAnalysis.WearPattern.CUPPING -> {
                factors.add(LifeFactor(
                    name = "Usura a Coppa",
                    impact = -0.50,
                    description = "Ammortizzatori difettosi causano usura prematura"
                ))
            }
            WearAnalysis.WearPattern.FEATHERING -> {
                factors.add(LifeFactor(
                    name = "Usura a Piuma",
                    impact = -0.35,
                    description = "Convergenza errata riduce la durata"
                ))
            }
        }

        // Fattore profondità corrente
        when {
            depthAnalysis.avgDepth > 6.0 -> {
                factors.add(LifeFactor(
                    name = "Battistrada Profondo",
                    impact = 0.20,
                    description = "Profondità elevata garantisce lunga durata residua"
                ))
            }
            depthAnalysis.avgDepth < 3.0 -> {
                factors.add(LifeFactor(
                    name = "Battistrada Ridotto",
                    impact = -0.15,
                    description = "Profondità limitata richiede attenzione"
                ))
            }
        }

        return factors
    }

    /**
     * Genera proiezioni della profondità del battistrada a intervalli futuri.
     */
    fun generateDepthProjections(
        currentDepth: Double,
        estimatedKm: Double,
        wearAnalysis: WearAnalysis
    ): List<DepthProjection> {

        val projections = mutableListOf<DepthProjection>()

        // Stato corrente
        projections.add(DepthProjection(
            kilometersFromNow = 0.0,
            projectedDepth = currentDepth,
            confidence = 1.0
        ))

        // Proiezioni a intervalli
        val intervals = listOf(1000.0, 2500.0, 5000.0, 10000.0, 15000.0, 20000.0, estimatedKm)

        for (km in intervals) {
            if (km > estimatedKm) continue

            val wearRate = (currentDepth - LEGAL_MINIMUM_DEPTH) / estimatedKm
            val projectedDepth = currentDepth - (wearRate * km)

            // La confidenza diminuisce con la distanza della proiezione
            val confidenceLoss = (km / estimatedKm) * 0.5
            val confidence = max(0.3, 1.0 - confidenceLoss)

            projections.add(DepthProjection(
                kilometersFromNow = km,
                projectedDepth = max(LEGAL_MINIMUM_DEPTH, projectedDepth),
                confidence = confidence
            ))
        }

        return projections
    }
}
