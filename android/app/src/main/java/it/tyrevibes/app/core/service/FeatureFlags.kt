package it.tyrevibes.app.core.service

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.featureFlagsDataStore by preferencesDataStore(name = "feature_flags")

/**
 * Feature Flags Manager - Controls app features and experiments
 */
class FeatureFlags private constructor(private val context: Context) {

    companion object {
        @Volatile
        private var instance: FeatureFlags? = null

        fun getInstance(context: Context): FeatureFlags {
            return instance ?: synchronized(this) {
                instance ?: FeatureFlags(context.applicationContext).also { instance = it }
            }
        }

        // Keys
        private val PAYWALL_ENABLED = booleanPreferencesKey("feature_paywall_enabled")
        private val NOTIFICATIONS_ENABLED = booleanPreferencesKey("feature_notifications_enabled")
        private val CLOUD_SYNC_ENABLED = booleanPreferencesKey("feature_cloud_sync_enabled")
        private val ANALYTICS_ENABLED = booleanPreferencesKey("feature_analytics_enabled")
        private val DEBUG_MODE = booleanPreferencesKey("feature_debug_mode")
    }

    // Flows for observing feature flags
    val isPaywallEnabled: Flow<Boolean> = context.featureFlagsDataStore.data.map { preferences ->
        preferences[PAYWALL_ENABLED] ?: false
    }

    val isNotificationsEnabled: Flow<Boolean> = context.featureFlagsDataStore.data.map { preferences ->
        preferences[NOTIFICATIONS_ENABLED] ?: true
    }

    val isCloudSyncEnabled: Flow<Boolean> = context.featureFlagsDataStore.data.map { preferences ->
        preferences[CLOUD_SYNC_ENABLED] ?: true
    }

    val isAnalyticsEnabled: Flow<Boolean> = context.featureFlagsDataStore.data.map { preferences ->
        preferences[ANALYTICS_ENABLED] ?: true
    }

    val isDebugMode: Flow<Boolean> = context.featureFlagsDataStore.data.map { preferences ->
        preferences[DEBUG_MODE] ?: false
    }

    // Setter functions
    suspend fun setPaywallEnabled(enabled: Boolean) {
        context.featureFlagsDataStore.edit { preferences ->
            preferences[PAYWALL_ENABLED] = enabled
        }
    }

    suspend fun setNotificationsEnabled(enabled: Boolean) {
        context.featureFlagsDataStore.edit { preferences ->
            preferences[NOTIFICATIONS_ENABLED] = enabled
        }
    }

    suspend fun setCloudSyncEnabled(enabled: Boolean) {
        context.featureFlagsDataStore.edit { preferences ->
            preferences[CLOUD_SYNC_ENABLED] = enabled
        }
    }

    suspend fun setAnalyticsEnabled(enabled: Boolean) {
        context.featureFlagsDataStore.edit { preferences ->
            preferences[ANALYTICS_ENABLED] = enabled
        }
    }

    suspend fun setDebugMode(enabled: Boolean) {
        context.featureFlagsDataStore.edit { preferences ->
            preferences[DEBUG_MODE] = enabled
        }
    }

    /**
     * Reset all feature flags to default values
     */
    suspend fun resetToDefaults() {
        context.featureFlagsDataStore.edit { preferences ->
            preferences[PAYWALL_ENABLED] = false
            preferences[NOTIFICATIONS_ENABLED] = true
            preferences[CLOUD_SYNC_ENABLED] = true
            preferences[ANALYTICS_ENABLED] = true
            preferences[DEBUG_MODE] = false
        }
    }

    /**
     * Get all feature flags as a map
     */
    suspend fun getAllFlags(): Map<String, Boolean> {
        val data = context.featureFlagsDataStore.data.map { preferences ->
            mapOf(
                "Paywall System" to (preferences[PAYWALL_ENABLED] ?: false),
                "Push Notifications" to (preferences[NOTIFICATIONS_ENABLED] ?: true),
                "Cloud Sync" to (preferences[CLOUD_SYNC_ENABLED] ?: true),
                "Analytics" to (preferences[ANALYTICS_ENABLED] ?: true),
                "Debug Mode" to (preferences[DEBUG_MODE] ?: false)
            )
        }
        return data.first()
    }
}
