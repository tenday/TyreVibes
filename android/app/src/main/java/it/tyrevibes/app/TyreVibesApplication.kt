package it.tyrevibes.app

import android.app.Application
import it.tyrevibes.app.core.service.SupabaseManager

/**
 * Application class per TyreVibes
 * Inizializza i servizi globali al lancio dell'app
 */
class TyreVibesApplication : Application() {

    override fun onCreate() {
        super.onCreate()

        // Inizializza Supabase Client
        SupabaseManager.initialize(this)
    }
}
