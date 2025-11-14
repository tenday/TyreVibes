package it.tyrevibes.app.core.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import it.tyrevibes.app.core.service.AuthService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class ForgotPasswordUiState(
    val email: String = "",
    val isLoading: Boolean = false,
    val error: String? = null,
    val successMessage: String? = null,
    val emailSent: Boolean = false
)

class ForgotPasswordViewModel(
    private val authService: AuthService
) : ViewModel() {

    private val _uiState = MutableStateFlow(ForgotPasswordUiState())
    val uiState: StateFlow<ForgotPasswordUiState> = _uiState.asStateFlow()

    fun updateEmail(email: String) {
        _uiState.value = _uiState.value.copy(email = email, error = null)
    }

    fun sendResetEmail() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)

            try {
                authService.resetPasswordForEmail(_uiState.value.email)
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    emailSent = true,
                    successMessage = "Email di recupero inviata. Controlla la tua casella di posta."
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = e.message ?: "Errore durante l'invio dell'email"
                )
            }
        }
    }

    val isFormValid: Boolean
        get() = _uiState.value.email.isNotEmpty() && _uiState.value.email.contains("@")
}
