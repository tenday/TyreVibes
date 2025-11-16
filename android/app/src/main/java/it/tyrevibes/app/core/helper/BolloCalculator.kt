package it.tyrevibes.app.core.helper

import it.tyrevibes.app.core.service.PlateData
import java.text.SimpleDateFormat
import java.util.*
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Bollo Calculation Result
 */
data class BolloCalculationResult(
    val taxablePowerKW: Double,
    val baseBollo: Double,
    val superBollo: Double,
    val total: Double,
    val emissionClass: EmissionClass,
    val appliedRates: Rate
) {
    val emissionClassDescription: String
        get() = emissionClass.description
}

/**
 * Emission Class
 */
enum class EmissionClass(val value: Int, val description: String) {
    EURO0(0, "Euro 0"),
    EURO1(1, "Euro 1"),
    EURO2(2, "Euro 2"),
    EURO3(3, "Euro 3"),
    EURO4(4, "Euro 4"),
    EURO5(5, "Euro 5"),
    EURO6(6, "Euro 6");

    companion object {
        fun from(raw: String?): EmissionClass? {
            if (raw == null) return null

            val normalized = raw.trim().lowercase()
                .replace("euro", "")
                .replace("eu", "")
                .replace("-", "")
                .replace("_", "")
                .trim()

            return when {
                normalized.contains("6") -> EURO6
                normalized.contains("5") -> EURO5
                normalized.contains("4") -> EURO4
                normalized.contains("3") -> EURO3
                normalized.contains("2") -> EURO2
                normalized.contains("1") -> EURO1
                else -> EURO0
            }
        }
    }
}

/**
 * Rate Table
 */
data class Rate(
    val upTo100kW: Double,
    val over100kW: Double
)

/**
 * Bollo Calculator - Italian car tax calculator
 */
object BolloCalculator {

    private val rateTable = mapOf(
        EmissionClass.EURO6 to Rate(upTo100kW = 2.58, over100kW = 3.87),
        EmissionClass.EURO5 to Rate(upTo100kW = 2.58, over100kW = 3.87),
        EmissionClass.EURO4 to Rate(upTo100kW = 2.58, over100kW = 3.87),
        EmissionClass.EURO3 to Rate(upTo100kW = 2.70, over100kW = 4.05),
        EmissionClass.EURO2 to Rate(upTo100kW = 2.80, over100kW = 4.20),
        EmissionClass.EURO1 to Rate(upTo100kW = 3.00, over100kW = 4.50),
        EmissionClass.EURO0 to Rate(upTo100kW = 3.40, over100kW = 4.70)
    )

    /**
     * Calculate bollo (and superbollo if applicable)
     */
    fun calculateBollo(
        powerKW: Double,
        emissionClassRaw: String?,
        firstRegistrationDate: Date? = null,
        referenceDate: Date = Date(),
        fuelType: String? = null,
        isHistoricVehicle: Boolean = false
    ): BolloCalculationResult {

        val sanitizedPower = max(0.0, powerKW)

        // Historic vehicles are exempt
        if (isHistoricVehicle) {
            return BolloCalculationResult(
                taxablePowerKW = sanitizedPower,
                baseBollo = 0.0,
                superBollo = 0.0,
                total = 0.0,
                emissionClass = EmissionClass.EURO0,
                appliedRates = Rate(upTo100kW = 0.0, over100kW = 0.0)
            )
        }

        // Electric vehicles are exempt
        val normalizedFuel = fuelType?.lowercase()
        if (normalizedFuel != null && (normalizedFuel.contains("electric") || normalizedFuel.contains("elettrico"))) {
            return BolloCalculationResult(
                taxablePowerKW = sanitizedPower,
                baseBollo = 0.0,
                superBollo = 0.0,
                total = 0.0,
                emissionClass = EmissionClass.EURO6,
                appliedRates = Rate(upTo100kW = 0.0, over100kW = 0.0)
            )
        }

        // Hybrid discount
        val hybridDiscount: Double = if (normalizedFuel != null) {
            val isHybrid = normalizedFuel.contains("ibrid") || normalizedFuel.contains("hybrid")
            if (isHybrid && firstRegistrationDate != null) {
                val years = calculateYearsDifference(firstRegistrationDate, referenceDate)
                if (years < 3) 0.5 else 0.0
            } else if (isHybrid) {
                0.5
            } else {
                0.0
            }
        } else {
            0.0
        }

        val emissionClass = EmissionClass.from(emissionClassRaw) ?: EmissionClass.EURO6
        val rates = rateTable[emissionClass] ?: rateTable[EmissionClass.EURO6]!!

        val basePower = min(sanitizedPower, 100.0)
        val extraPower = max(0.0, sanitizedPower - 100.0)

        var baseAmount = (basePower * rates.upTo100kW) + (extraPower * rates.over100kW)
        baseAmount = applyDiscount(baseAmount, hybridDiscount)

        val superBolloAmount = calculateSuperBollo(
            powerKW = sanitizedPower,
            firstRegistrationDate = firstRegistrationDate,
            referenceDate = referenceDate
        )

        val total = roundToCents(baseAmount + superBolloAmount)

        return BolloCalculationResult(
            taxablePowerKW = sanitizedPower,
            baseBollo = roundToCents(baseAmount),
            superBollo = roundToCents(superBolloAmount),
            total = total,
            emissionClass = emissionClass,
            appliedRates = rates
        )
    }

    /**
     * Convenience for PlateData
     */
    fun calculateBollo(
        plateData: PlateData,
        referenceDate: Date = Date(),
        isHistoricVehicle: Boolean = false
    ): BolloCalculationResult? {
        val powerKW = extractPowerKW(plateData = plateData) ?: return null

        val emission = plateData.emissionClass
        val firstRegistrationDate = plateData.registrationDate?.toDate()

        return calculateBollo(
            powerKW = powerKW,
            emissionClassRaw = emission,
            firstRegistrationDate = firstRegistrationDate,
            referenceDate = referenceDate,
            fuelType = plateData.fuelType,
            isHistoricVehicle = isHistoricVehicle
        )
    }

    // MARK: - Helpers

    private fun applyDiscount(amount: Double, discount: Double): Double {
        if (discount <= 0) return amount
        val bounded = min(max(discount, 0.0), 1.0)
        return amount * (1 - bounded)
    }

    private fun extractPowerKW(from: PlateData): Double? {
        // Try powerKW field
        from.powerKW?.let { kwString ->
            parseNumericValue(kwString)?.let { return it }
        }

        // Try powerCV field (convert CV to kW)
        from.powerCV?.let { cvString ->
            parseNumericValue(cvString)?.let { cv ->
                return cv * 0.735499
            }
        }

        return null
    }

    private fun parseNumericValue(raw: String): Double? {
        val sanitized = raw.replace(",", ".")
            .split(Regex("[^0-9.]"))
            .filter { it.isNotEmpty() }

        return sanitized.lastOrNull()?.toDoubleOrNull()
    }

    private fun calculateSuperBollo(
        powerKW: Double,
        firstRegistrationDate: Date?,
        referenceDate: Date
    ): Double {
        val taxableKW = max(0.0, powerKW - 185)
        if (taxableKW <= 0) return 0.0

        val baseRate = 20.0 // €/kW oltre i 185
        var multiplier = 1.0

        if (firstRegistrationDate != null) {
            val years = calculateYearsDifference(firstRegistrationDate, referenceDate)
            multiplier = when (years) {
                in 0 until 5 -> 1.0
                in 5 until 10 -> 0.6
                in 10 until 15 -> 0.4
                in 15 until 20 -> 0.15
                else -> 0.0
            }
        }

        return roundToCents(taxableKW * baseRate * multiplier)
    }

    private fun roundToCents(value: Double): Double {
        return (value * 100).roundToInt() / 100.0
    }

    private fun calculateYearsDifference(from: Date, to: Date): Int {
        val calendar = Calendar.getInstance()
        calendar.time = from
        val fromYear = calendar.get(Calendar.YEAR)

        calendar.time = to
        val toYear = calendar.get(Calendar.YEAR)

        return toYear - fromYear
    }

    private fun String.toDate(format: String = "yyyy-MM-dd"): Date? {
        val formatter = SimpleDateFormat(format, Locale.US)
        formatter.timeZone = TimeZone.getTimeZone("UTC")

        return try {
            formatter.parse(this)
        } catch (e: Exception) {
            // Try alternative formats
            val alternativeFormats = listOf("dd/MM/yyyy", "yyyy-MM", "MM/yyyy", "yyyy")
            for (altFormat in alternativeFormats) {
                try {
                    formatter.applyPattern(altFormat)
                    return formatter.parse(this)
                } catch (e: Exception) {
                    continue
                }
            }
            null
        }
    }
}
