package it.tyrevibes.app.core.helper

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * KeychainHelper - Secure storage for credentials
 * Android equivalent of iOS Keychain using EncryptedSharedPreferences
 */
object KeychainHelper {

    private const val PREFS_NAME = "secure_credentials"
    private const val KEY_EMAIL = "saved_email"
    private const val KEY_PASSWORD = "saved_password"

    private fun getEncryptedPrefs(context: Context): android.content.SharedPreferences {
        val spec = KeyGenParameterSpec.Builder(
            MasterKey.DEFAULT_MASTER_KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .build()

        val masterKey = MasterKey.Builder(context)
            .setKeyGenParameterSpec(spec)
            .build()

        return EncryptedSharedPreferences.create(
            context,
            PREFS_NAME,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    fun save(context: Context, email: String, password: String) {
        val prefs = getEncryptedPrefs(context)
        prefs.edit().apply {
            putString(KEY_EMAIL, email)
            putString(KEY_PASSWORD, password)
            apply()
        }
    }

    fun get(context: Context): Pair<String?, String?> {
        val prefs = getEncryptedPrefs(context)
        return Pair(
            prefs.getString(KEY_EMAIL, null),
            prefs.getString(KEY_PASSWORD, null)
        )
    }

    fun delete(context: Context) {
        val prefs = getEncryptedPrefs(context)
        prefs.edit().clear().apply()
    }

    fun hasCredentials(context: Context): Boolean {
        val (email, password) = get(context)
        return !email.isNullOrBlank() && !password.isNullOrBlank()
    }
}
