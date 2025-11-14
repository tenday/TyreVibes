package it.tyrevibes.app.core.service

import android.content.Context
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.ui.graphics.vector.ImageVector
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first

/**
 * Premium Feature enum
 */
enum class PremiumFeatureType(
    val id: String,
    val title: String,
    val icon: ImageVector
) {
    UNLIMITED_VEHICLES("unlimited_vehicles", "Veicoli Illimitati", Icons.Default.DirectionsCar),
    UNLIMITED_TIRES("unlimited_tires", "Pneumatici Illimitati", Icons.Default.AutoAwesome),
    ADVANCED_OCR("advanced_ocr", "OCR Avanzato", Icons.Default.CameraAlt),
    SMART_NOTIFICATIONS("smart_notifications", "Notifiche Smart", Icons.Default.Notifications),
    DETAILED_ANALYTICS("detailed_analytics", "Analisi Dettagliate", Icons.Default.Analytics),
    CLOUD_SYNC("cloud_sync", "Sincronizzazione Cloud", Icons.Default.Cloud),
    PRIORITY_SUPPORT("priority_support", "Supporto Prioritario", Icons.Default.HeadsetMic),
    AD_FREE("ad_free", "Senza Pubblicità", Icons.Default.Block);

    fun getLimitMessage(): String {
        return when (this) {
            UNLIMITED_VEHICLES ->
                "Gli utenti gratuiti possono aggiungere fino a ${FreeLimits.MAX_VEHICLES} veicoli. Passa a Premium per veicoli illimitati."
            UNLIMITED_TIRES ->
                "Gli utenti gratuiti possono aggiungere fino a ${FreeLimits.MAX_TIRES_PER_VEHICLE} pneumatici per veicolo. Passa a Premium per pneumatici illimitati."
            ADVANCED_OCR ->
                "La scansione OCR avanzata è una funzionalità Premium. Passa a Premium per sbloccare il riconoscimento AI dei pneumatici."
            SMART_NOTIFICATIONS ->
                "Le notifiche intelligenti sono una funzionalità Premium. Passa a Premium per ricevere promemoria tempestivi per manutenzione e cambi pneumatici."
            DETAILED_ANALYTICS ->
                "Le analisi dettagliate sono una funzionalità Premium. Passa a Premium per tracciare i costi di manutenzione e la cronologia del veicolo."
            CLOUD_SYNC ->
                "La sincronizzazione cloud è una funzionalità Premium. Passa a Premium per accedere ai tuoi dati su tutti i dispositivi."
            PRIORITY_SUPPORT ->
                "Il supporto prioritario è una funzionalità Premium. Passa a Premium per ottenere aiuto dal nostro team quando ne hai bisogno."
            AD_FREE ->
                "Rimuovi gli annunci con Premium. Passa a Premium per un'esperienza senza pubblicità."
        }
    }
}

/**
 * Free tier limits
 */
object FreeLimits {
    const val MAX_VEHICLES = 2
    const val MAX_TIRES_PER_VEHICLE = 4
    const val MAX_MONTHLY_SCANS = 10
}

/**
 * Paywall Manager - Manages premium features and paywalls
 */
class PaywallManager private constructor(
    private val context: Context
) {
    companion object {
        @Volatile
        private var instance: PaywallManager? = null

        fun getInstance(context: Context): PaywallManager {
            return instance ?: synchronized(this) {
                instance ?: PaywallManager(context.applicationContext).also { instance = it }
            }
        }
    }

    private val featureFlags = FeatureFlags.getInstance(context)

    // State flows
    private val _isPremium = MutableStateFlow(false)
    val isPremium: StateFlow<Boolean> = _isPremium.asStateFlow()

    private val _showPaywall = MutableStateFlow(false)
    val showPaywall: StateFlow<Boolean> = _showPaywall.asStateFlow()

    private val _paywallFeature = MutableStateFlow<PremiumFeatureType?>(null)
    val paywallFeature: StateFlow<PremiumFeatureType?> = _paywallFeature.asStateFlow()

    /**
     * Update premium status
     * TODO: Integrate with Google Play Billing Library
     */
    suspend fun updatePremiumStatus() {
        // TODO: Check subscription status from Google Play Billing
        // For now, check a shared preference or local flag
        _isPremium.value = false // Placeholder
    }

    /**
     * Check if user can use a premium feature
     */
    suspend fun canUseFeature(feature: PremiumFeatureType): Boolean {
        return _isPremium.value
    }

    /**
     * Show paywall for a specific feature
     */
    suspend fun showPaywall(feature: PremiumFeatureType) {
        // Check if paywall is enabled in feature flags
        val paywallEnabled = featureFlags.isPaywallEnabled.first()
        if (!paywallEnabled) return

        _paywallFeature.value = feature
        _showPaywall.value = true
    }

    /**
     * Dismiss paywall
     */
    fun dismissPaywall() {
        _showPaywall.value = false
        _paywallFeature.value = null
    }

    /**
     * Check if user can add another vehicle
     */
    suspend fun canAddVehicle(currentCount: Int): Boolean {
        val paywallEnabled = featureFlags.isPaywallEnabled.first()
        if (!paywallEnabled) return true

        if (_isPremium.value) return true

        return currentCount < FreeLimits.MAX_VEHICLES
    }

    /**
     * Check if user can add another tire
     */
    suspend fun canAddTire(currentCount: Int): Boolean {
        val paywallEnabled = featureFlags.isPaywallEnabled.first()
        if (!paywallEnabled) return true

        if (_isPremium.value) return true

        return currentCount < FreeLimits.MAX_TIRES_PER_VEHICLE
    }

    /**
     * Check if user can perform another scan this month
     */
    suspend fun canPerformScan(currentMonthlyScans: Int): Boolean {
        val paywallEnabled = featureFlags.isPaywallEnabled.first()
        if (!paywallEnabled) return true

        if (_isPremium.value) return true

        return currentMonthlyScans < FreeLimits.MAX_MONTHLY_SCANS
    }

    /**
     * Get limit message for a feature
     */
    fun getLimitMessage(feature: PremiumFeatureType): String {
        return feature.getLimitMessage()
    }

    /**
     * Set premium status (for testing or after purchase)
     */
    fun setPremiumStatus(isPremium: Boolean) {
        _isPremium.value = isPremium
    }
}
