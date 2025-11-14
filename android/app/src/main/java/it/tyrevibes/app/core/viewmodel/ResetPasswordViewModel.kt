package it.tyrevibes.app.core.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import it.tyrevibes.app.core.service.AuthService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class ResetPasswordUiState(
    val newPassword: String = "",
    val confirmPassword: String = "",
    val isLoading: Boolean = false,
    val error: String? = null,
    val successMessage: String? = null,
    val passwordReset: Boolean = false,
    val showPassword: Boolean = false
)

class ResetPasswordViewModel(
    private val authService: AuthService
) : ViewModel() {

    private val _uiState = MutableStateFlow(ResetPasswordUiState())
    val uiState: StateFlow<ResetPasswordUiState> = _uiState.asStateFlow()

    fun updateNewPassword(password: String) {
        _uiState.value = _uiState.value.copy(newPassword = password, error = null)
    }

    fun updateConfirmPassword(password: String) {
        _uiState.value = _uiState.value.copy(confirmPassword = password, error = null)
    }

    fun togglePasswordVisibility() {
        _uiState.value = _uiState.value.copy(showPassword = !_uiState.value.showPassword)
    }

    fun resetPassword() {
        viewModelScope.launch {
            if (_uiState.value.newPassword != _uiState.value.confirmPassword) {
                _uiState.value = _uiState.value.copy(error = "Le password non corrispondono")
                return@launch
            }

            _uiState.value = _uiState.value.copy(isLoading = true, error = null)

            try {
                authService.updatePassword(_uiState.value.newPassword)
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    passwordReset = true,
                    successMessage = "Password aggiornata con successo"
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = e.message ?: "Errore durante l'aggiornamento della password"
                )
            }
        }
    }

    val isFormValid: Boolean
        get() = _uiState.value.newPassword.length >= 8 &&
                _uiState.value.newPassword == _uiState.value.confirmPassword
}
