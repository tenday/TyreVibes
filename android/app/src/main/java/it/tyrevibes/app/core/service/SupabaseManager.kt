package it.tyrevibes.app.core.service

import android.content.Context
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.functions.Functions
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.realtime.Realtime
import io.github.jan.supabase.storage.Storage
import it.tyrevibes.app.BuildConfig

/**
 * Supabase Manager Singleton
 * Gestisce la connessione al backend Supabase con JWT authentication
 */
object SupabaseManager {

    private var _client: SupabaseClient? = null

    val client: SupabaseClient
        get() = _client ?: throw IllegalStateException(
            "SupabaseManager not initialized. Call initialize(context) first."
        )

    fun initialize(context: Context) {
        if (_client != null) return

        _client = createSupabaseClient(
            supabaseUrl = BuildConfig.SUPABASE_URL,
            supabaseKey = BuildConfig.SUPABASE_KEY
        ) {
            install(Auth)
            install(Postgrest)
            install(Realtime)
            install(Storage)
            install(Functions)
        }
    }

    /**
     * Get current user ID from session
     */
    suspend fun getCurrentUserId(): String? {
        return try {
            client.auth.currentUserOrNull()?.id
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Get current JWT access token
     */
    suspend fun getAccessToken(): String? {
        return try {
            client.auth.currentAccessTokenOrNull()
        } catch (e: Exception) {
            null
        }
    }
}
