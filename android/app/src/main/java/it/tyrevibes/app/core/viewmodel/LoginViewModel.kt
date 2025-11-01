package it.tyrevibes.app.core.viewmodel

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import it.tyrevibes.app.core.service.AuthService
import it.tyrevibes.app.core.service.AuthServiceError
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "settings")

data class LoginUiState(
    val email: String = "",
    val password: String = "",
    val rememberMe: Boolean = false,
    val isLoading: Boolean = false,
    val showHomeScreen: Boolean = false,
    val isLoggedIn: Boolean = false,
    val alertTitle: String? = null,
    val alertMessage: String? = null
)

class LoginViewModel(
    private val context: Context
) : ViewModel() {

    private val _uiState = MutableStateFlow(LoginUiState())
    val uiState: StateFlow<LoginUiState> = _uiState.asStateFlow()

    private val authService = AuthService()

    // DataStore keys
    private val useFaceIDKey = booleanPreferencesKey("useFaceID")
    private val isLoggedInKey = booleanPreferencesKey("isLoggedIn")
    private val rememberMeKey = booleanPreferencesKey("rememberMe")
    private val savedEmailKey = stringPreferencesKey("savedEmail")
    private val savedPasswordKey = stringPreferencesKey("savedPassword")

    init {
        loadSavedCredentials()
    }

    val isLoginButtonEnabled: Boolean
        get() = with(_uiState.value) {
            email.isNotBlank() && password.isNotBlank() && !isLoading
        }

    fun onEmailChange(email: String) {
        _uiState.value = _uiState.value.copy(email = email)
    }

    fun onPasswordChange(password: String) {
        _uiState.value = _uiState.value.copy(password = password)
    }

    fun onRememberMeChange(rememberMe: Boolean) {
        _uiState.value = _uiState.value.copy(rememberMe = rememberMe)
    }

    fun clearAlert() {
        _uiState.value = _uiState.value.copy(
            alertTitle = null,
            alertMessage = null
        )
    }

    fun signIn() {
        if (!isLoginButtonEnabled) return

        _uiState.value = _uiState.value.copy(isLoading = true)

        viewModelScope.launch {
            try {
                authService.signIn(
                    _uiState.value.email,
                    _uiState.value.password
                )

                // Fetch and cache user profile (if needed)
                // fetchAndCacheUserProfile()

                // Save credentials if remember me is checked
                if (_uiState.value.rememberMe) {
                    saveCredentials(
                        _uiState.value.email,
                        _uiState.value.password
                    )
                } else {
                    clearSavedCredentials()
                }

                // Save remember me preference
                context.dataStore.edit { prefs ->
                    prefs[rememberMeKey] = _uiState.value.rememberMe
                    prefs[isLoggedInKey] = true
                }

                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    showHomeScreen = true,
                    isLoggedIn = true
                )

            } catch (e: Exception) {
                val (title, message) = mapErrorToAlert(e, "Errore di accesso")
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    alertTitle = title,
                    alertMessage = message
                )
            }
        }
    }

    private suspend fun loadSavedCredentials() {
        val prefs = context.dataStore.data.first()
        val rememberMe = prefs[rememberMeKey] ?: false

        if (rememberMe) {
            val savedEmail = prefs[savedEmailKey] ?: ""
            val savedPassword = prefs[savedPasswordKey] ?: ""

            _uiState.value = _uiState.value.copy(
                email = savedEmail,
                password = savedPassword,
                rememberMe = true
            )
        }
    }

    private suspend fun saveCredentials(email: String, password: String) {
        context.dataStore.edit { prefs ->
            prefs[savedEmailKey] = email
            prefs[savedPasswordKey] = password // In produzione, usa Android Keystore!
        }
    }

    private suspend fun clearSavedCredentials() {
        context.dataStore.edit { prefs ->
            prefs.remove(savedEmailKey)
            prefs.remove(savedPasswordKey)
        }
    }

    private fun mapErrorToAlert(
        error: Exception,
        fallbackTitle: String
    ): Pair<String, String> {
        return when (error) {
            is AuthServiceError.InvalidEmail -> {
                "Email non valida" to error.message
            }
            is AuthServiceError.NoUserFound -> {
                "Credenziali errate" to "L'email o la password inserita non sono corrette. Riprova."
            }
            is AuthServiceError.OtpInvalid -> {
                "Codice OTP errato" to "Il codice inserito non è corretto. Verifica e riprova."
            }
            is AuthServiceError.OtpExpired -> {
                "Codice OTP scaduto" to "Il codice OTP è scaduto. Richiedine uno nuovo."
            }
            is AuthServiceError.ProfileCreationFailed -> {
                "Errore creazione profilo" to error.message
            }
            is AuthServiceError.SignUpFailed -> {
                "Accesso fallito" to (error.message.takeIf { it.isNotBlank() }
                    ?: "Si è verificato un errore durante l'accesso. Riprova.")
            }
            else -> {
                val message = error.message?.takeIf { it.isNotBlank() }
                    ?: "Si è verificato un errore imprevisto. Riprova."
                fallbackTitle to message
            }
        }
    }
}
