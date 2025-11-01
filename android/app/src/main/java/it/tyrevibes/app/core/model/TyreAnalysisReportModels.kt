package it.tyrevibes.app.core.model

import androidx.compose.ui.graphics.Color
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.Transient
import java.util.UUID
import java.util.Date

// MARK: - Main Report Model
@Serializable
data class TyreAnalysisReport(
    val id: String = UUID.randomUUID().toString(),
    val metadata: ReportMetadata,
    @SerialName("depth_analysis") val depthAnalysis: DepthAnalysis,
    @SerialName("wear_analysis") val wearAnalysis: WearAnalysis,
    @SerialName("heat_map") val heatMap: DepthHeatMap,
    @SerialName("remaining_life") val remainingLife: RemainingLifeEstimate,
    val recommendations: List<Recommendation> = emptyList(),
    @SerialName("safety_score") val safetyScore: SafetyScore,
    val comparison: ComparisonData? = null
) {
    @Transient
    val createdAt: Long = metadata.timestamp
}

// MARK: - Report Metadata
@Serializable
data class ReportMetadata(
    @SerialName("report_id") val reportId: String,
    val timestamp: Long, // Unix timestamp in milliseconds
    val vehicle: VehicleInfo,
    val tyre: TyreInfo,
    val location: LocationInfo? = null,
    val weather: WeatherInfo? = null,
    @SerialName("analysis_type") val analysisType: AnalysisType
) {
    @Serializable
    enum class AnalysisType(val displayName: String) {
        @SerialName("quick") QUICK("Quick Scan"),
        @SerialName("standard") STANDARD("Standard Analysis"),
        @SerialName("comprehensive") COMPREHENSIVE("Comprehensive Analysis"),
        @SerialName("comparison") COMPARISON("Comparison Analysis")
    }
}

@Serializable
data class VehicleInfo(
    val make: String,
    val model: String,
    val year: Int? = null,
    @SerialName("plate_number") val plateNumber: String,
    val vin: String? = null
)

@Serializable
data class TyreInfo(
    val brand: String,
    val model: String,
    val size: String,
    val dot: String,
    val position: TyrePosition,
    val season: String,
    @SerialName("load_index") val loadIndex: String,
    @SerialName("speed_rating") val speedRating: String
) {
    @Serializable
    enum class TyrePosition(val displayName: String, val shortCode: String) {
        @SerialName("front_left") FRONT_LEFT("Front Left", "FL"),
        @SerialName("front_right") FRONT_RIGHT("Front Right", "FR"),
        @SerialName("rear_left") REAR_LEFT("Rear Left", "RL"),
        @SerialName("rear_right") REAR_RIGHT("Rear Right", "RR")
    }
}

@Serializable
data class LocationInfo(
    val latitude: Double,
    val longitude: Double,
    val address: String? = null
)

@Serializable
data class WeatherInfo(
    val temperature: Double,
    val humidity: Double,
    val conditions: String
)

@Serializable
data class DepthAnalysis(
    @SerialName("min_depth") val minDepth: Double,
    @SerialName("max_depth") val maxDepth: Double,
    @SerialName("avg_depth") val avgDepth: Double,
    @SerialName("measurement_points") val measurementPoints: List<DepthMeasurementPoint>
)

@Serializable
data class DepthMeasurementPoint(
    val id: String = UUID.randomUUID().toString(),
    val x: Double,  // Normalized 0-1
    val y: Double,  // Normalized 0-1
    val depth: Double,  // mm
    val confidence: Double,  // 0-1
    val zone: TyreZone
) {
    @Serializable
    enum class TyreZone(val displayName: String) {
        @SerialName("center") CENTER("Center"),
        @SerialName("inner_edge") INNER_EDGE("Inner Edge"),
        @SerialName("outer_edge") OUTER_EDGE("Outer Edge"),
        @SerialName("shoulder") SHOULDER("Shoulder")
    }
}

@Serializable
data class WearAnalysis(
    @SerialName("wear_pattern") val wearPattern: WearPattern,
    val severity: Double, // 0-1
    @SerialName("likely_causes") val likelyCauses: List<WearCause>
) {
    @Serializable
    enum class WearPattern(val displayName: String) {
        @SerialName("even") EVEN("Even Wear"),
        @SerialName("center") CENTER("Center Wear"),
        @SerialName("edge") EDGE("Edge Wear"),
        @SerialName("one_side") ONE_SIDE("One-Sided Wear"),
        @SerialName("cupping") CUPPING("Cupping"),
        @SerialName("feathering") FEATHERING("Feathering")
    }
}

@Serializable
data class WearCause(
    val id: String = UUID.randomUUID().toString(),
    val type: CauseType,
    val probability: Double,  // 0-1
    val description: String
) {
    @Serializable
    enum class CauseType(val displayName: String) {
        @SerialName("over_inflation") OVER_INFLATION("Sovra-gonfiaggio"),
        @SerialName("under_inflation") UNDER_INFLATION("Sotto-gonfiaggio"),
        @SerialName("misalignment") MISALIGNMENT("Disallineamento"),
        @SerialName("improper_rotation") IMPROPER_ROTATION("Mancata rotazione"),
        @SerialName("suspension") SUSPENSION("Problemi sospensioni"),
        @SerialName("driving_style") DRIVING_STYLE("Stile di guida aggressivo"),
        @SerialName("braking") BRAKING("Frenate brusche"),
        @SerialName("loading") LOADING("Carico eccessivo")
    }
}

// MARK: - Heat Map
@Serializable
data class DepthHeatMap(
    @SerialName("grid_size") val gridSize: GridSize,
    @SerialName("data_points") val dataPoints: List<List<Double>>,  // 2D array of depth values
    @SerialName("color_scheme") val colorScheme: HeatMapColorScheme,
    val interpolated: Boolean
) {
    @Serializable
    data class GridSize(
        val rows: Int,
        val columns: Int
    )

    @Serializable
    enum class HeatMapColorScheme {
        @SerialName("rainbow") RAINBOW,
        @SerialName("thermal") THERMAL,
        @SerialName("grayscale") GRAYSCALE,
        @SerialName("custom") CUSTOM;

        fun getColors(): List<Color> {
            return when (this) {
                RAINBOW -> listOf(
                    Color.Red, Color(0xFFFFA500), Color.Yellow,
                    Color.Green, Color.Blue, Color(0xFF800080)
                )
                THERMAL -> listOf(
                    Color.Blue, Color.Cyan, Color.Green,
                    Color.Yellow, Color(0xFFFFA500), Color.Red
                )
                GRAYSCALE -> listOf(Color.Black, Color.Gray, Color.White)
                CUSTOM -> listOf(Color(0xFFFF0000), Color(0xFFFFFF00), Color(0xFF00FF00))
            }
        }
    }

    fun colorForDepth(depth: Double, minDepth: Double = 0.0, maxDepth: Double = 8.0): Color {
        val normalized = (depth - minDepth) / (maxDepth - minDepth)
        val clampedValue = normalized.coerceIn(0.0, 1.0)

        val colors = colorScheme.getColors()
        val index = (clampedValue * (colors.size - 1)).toInt()
        return colors[index.coerceIn(0, colors.size - 1)]
    }
}

// MARK: - Remaining Life Estimate
@Serializable
data class RemainingLifeEstimate(
    @SerialName("estimated_kilometers") val estimatedKilometers: Double,
    @SerialName("estimated_months") val estimatedMonths: Int,
    val confidence: Double,  // 0-1
    @SerialName("calculation_method") val calculationMethod: CalculationMethod
) {
    @Transient
    val factors: List<LifeFactor> = emptyList()

    @Transient
    val projectedDepthCurve: List<DepthProjection> = emptyList()

    @Serializable
    enum class CalculationMethod(val displayName: String) {
        @SerialName("linear") LINEAR("Linear Regression"),
        @SerialName("exponential") EXPONENTIAL("Exponential Model"),
        @SerialName("ml") MACHINE_LEARNING("ML Prediction"),
        @SerialName("historical") HISTORICAL("Historical Data")
    }

    val formattedDistance: String
        get() = if (estimatedKilometers > 1000) {
            String.format("%.1f,000 km", estimatedKilometers / 1000)
        } else {
            String.format("%.0f km", estimatedKilometers)
        }

    val status: LifeStatus
        get() = when {
            estimatedKilometers > 20000 -> LifeStatus.EXCELLENT
            estimatedKilometers > 10000 -> LifeStatus.GOOD
            estimatedKilometers > 5000 -> LifeStatus.FAIR
            estimatedKilometers > 2000 -> LifeStatus.WARNING
            else -> LifeStatus.CRITICAL
        }

    enum class LifeStatus(val color: Color) {
        EXCELLENT(Color.Green),
        GOOD(Color.Blue),
        FAIR(Color.Yellow),
        WARNING(Color(0xFFFFA500)),
        CRITICAL(Color.Red)
    }
}

// Non-serializable supporting types
data class LifeFactor(
    val name: String,
    val impact: Double,
    val description: String
)

data class DepthProjection(
    val kilometers: Double,
    val expectedDepth: Double,
    val confidenceRange: DepthRange
)

data class DepthRange(
    val min: Double,
    val max: Double
)

@Serializable
data class SafetyScore(
    val overall: Double, // 0-100
    @SerialName("wet_performance") val wetPerformance: Double,
    @SerialName("dry_performance") val dryPerformance: Double,
    @SerialName("legal_compliance") val legalCompliance: Boolean,
    val grade: SafetyGrade
) {
    @Serializable
    enum class SafetyGrade(val displayName: String) {
        @SerialName("A") A("A - Excellent"),
        @SerialName("B") B("B - Good"),
        @SerialName("C") C("C - Fair"),
        @SerialName("D") D("D - Poor"),
        @SerialName("F") F("F - Dangerous")
    }
}

@Serializable
data class ComparisonData(
    @SerialName("previous_report_id") val previousReportId: String,
    @SerialName("days_elapsed") val daysElapsed: Int,
    @SerialName("depth_change") val depthChange: Double,
    @SerialName("wear_rate") val wearRate: Double
)

// MARK: - Recommendations
@Serializable
data class Recommendation(
    val id: String = UUID.randomUUID().toString(),
    val priority: Priority,
    val category: Category,
    val title: String,
    val description: String,
    val action: String,
    val urgency: Urgency
) {
    @Serializable
    enum class Priority(val displayName: String, val icon: String) {
        @SerialName("critical") CRITICAL("Critical", "warning"),
        @SerialName("high") HIGH("High", "error"),
        @SerialName("medium") MEDIUM("Medium", "info"),
        @SerialName("low") LOW("Low", "check_circle");

        fun getColor(): Color {
            return when (this) {
                CRITICAL -> Color.Red
                HIGH -> Color(0xFFFFA500)
                MEDIUM -> Color.Yellow
                LOW -> Color.Blue
            }
        }
    }

    @Serializable
    enum class Category(val displayName: String) {
        @SerialName("safety") SAFETY("Safety"),
        @SerialName("maintenance") MAINTENANCE("Maintenance"),
        @SerialName("performance") PERFORMANCE("Performance"),
        @SerialName("cost") COST("Cost Optimization"),
        @SerialName("legal") LEGAL("Legal Compliance")
    }

    @Serializable
    enum class Urgency(val displayName: String) {
        @SerialName("immediate") IMMEDIATE("Immediate"),
        @SerialName("within_week") WITHIN_WEEK("Within a Week"),
        @SerialName("within_month") WITHIN_MONTH("Within a Month"),
        @SerialName("routine") ROUTINE("Routine Check")
    }
}

// MARK: - Export Format
sealed class ReportExportFormat {
    object PDF : ReportExportFormat()
    data class Image(val format: ImageFormat) : ReportExportFormat()
    object JSON : ReportExportFormat()
    object HTML : ReportExportFormat()

    sealed class ImageFormat {
        object PNG : ImageFormat()
        data class JPEG(val quality: Double) : ImageFormat()
    }

    val fileExtension: String
        get() = when (this) {
            is PDF -> "pdf"
            is Image -> when (format) {
                is ImageFormat.PNG -> "png"
                is ImageFormat.JPEG -> "jpg"
            }
            is JSON -> "json"
            is HTML -> "html"
        }
}
