package it.tyrevibes.app.core.viewmodel

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import it.tyrevibes.app.core.service.AuthService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

private val Context.settingsDataStore by preferencesDataStore(name = "settings")

data class SettingsUiState(
    val notificationsEnabled: Boolean = true,
    val biometricEnabled: Boolean = false,
    val darkModeEnabled: Boolean = false,
    val selectedLanguage: String = "it",
    val isLoggingOut: Boolean = false,
    val isDeletingAccount: Boolean = false,
    val showDeleteConfirmation: Boolean = false,
    val showLogoutConfirmation: Boolean = false,
    val errorMessage: String? = null,
    val successMessage: String? = null
)

class SettingsViewModel(private val context: Context) : ViewModel() {

    private val _uiState = MutableStateFlow(SettingsUiState())
    val uiState: StateFlow<SettingsUiState> = _uiState.asStateFlow()

    private val authService = AuthService()

    // DataStore keys
    private val notificationsKey = booleanPreferencesKey("notifications_enabled")
    private val biometricKey = booleanPreferencesKey("biometric_enabled")
    private val darkModeKey = booleanPreferencesKey("dark_mode_enabled")
    private val languageKey = stringPreferencesKey("selected_language")

    init {
        loadSettings()
    }

    private fun loadSettings() {
        viewModelScope.launch {
            val prefs = context.settingsDataStore.data.first()
            _uiState.value = _uiState.value.copy(
                notificationsEnabled = prefs[notificationsKey] ?: true,
                biometricEnabled = prefs[biometricKey] ?: false,
                darkModeEnabled = prefs[darkModeKey] ?: false,
                selectedLanguage = prefs[languageKey] ?: "it"
            )
        }
    }

    fun toggleNotifications(enabled: Boolean) {
        _uiState.value = _uiState.value.copy(notificationsEnabled = enabled)
        viewModelScope.launch {
            context.settingsDataStore.edit { prefs ->
                prefs[notificationsKey] = enabled
            }
        }
    }

    fun toggleBiometric(enabled: Boolean) {
        _uiState.value = _uiState.value.copy(biometricEnabled = enabled)
        viewModelScope.launch {
            context.settingsDataStore.edit { prefs ->
                prefs[biometricKey] = enabled
            }
        }
    }

    fun toggleDarkMode(enabled: Boolean) {
        _uiState.value = _uiState.value.copy(darkModeEnabled = enabled)
        viewModelScope.launch {
            context.settingsDataStore.edit { prefs ->
                prefs[darkModeKey] = enabled
            }
        }
    }

    fun changeLanguage(language: String) {
        _uiState.value = _uiState.value.copy(selectedLanguage = language)
        viewModelScope.launch {
            context.settingsDataStore.edit { prefs ->
                prefs[languageKey] = language
            }
        }
    }

    fun showDeleteAccountConfirmation() {
        _uiState.value = _uiState.value.copy(showDeleteConfirmation = true)
    }

    fun hideDeleteAccountConfirmation() {
        _uiState.value = _uiState.value.copy(showDeleteConfirmation = false)
    }

    fun showLogoutConfirmation() {
        _uiState.value = _uiState.value.copy(showLogoutConfirmation = true)
    }

    fun hideLogoutConfirmation() {
        _uiState.value = _uiState.value.copy(showLogoutConfirmation = false)
    }

    fun logout() {
        _uiState.value = _uiState.value.copy(
            isLoggingOut = true,
            showLogoutConfirmation = false
        )

        viewModelScope.launch {
            try {
                authService.logout()
                _uiState.value = _uiState.value.copy(
                    isLoggingOut = false,
                    successMessage = "Logout effettuato con successo"
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoggingOut = false,
                    errorMessage = "Errore durante il logout: ${e.message}"
                )
            }
        }
    }

    fun deleteAccount() {
        _uiState.value = _uiState.value.copy(
            isDeletingAccount = true,
            showDeleteConfirmation = false
        )

        viewModelScope.launch {
            try {
                authService.deleteCurrentUser()
                _uiState.value = _uiState.value.copy(
                    isDeletingAccount = false,
                    successMessage = "Account eliminato con successo"
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isDeletingAccount = false,
                    errorMessage = "Errore durante l'eliminazione: ${e.message}"
                )
            }
        }
    }

    fun clearMessages() {
        _uiState.value = _uiState.value.copy(
            errorMessage = null,
            successMessage = null
        )
    }
}
