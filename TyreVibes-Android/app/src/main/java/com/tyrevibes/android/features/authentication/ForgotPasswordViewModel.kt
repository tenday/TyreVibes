package com.tyrevibes.android.features.authentication

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.tyrevibes.android.core.data.SupabaseClient
import io.supabase.gotrue.auth.resetPasswordForEmail
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class ForgotPasswordViewModel : ViewModel() {

    private val _email = MutableStateFlow("")
    val email = _email.asStateFlow()

    private val _uiState = MutableStateFlow<AuthState>(AuthState.Idle)
    val uiState = _uiState.asStateFlow()

    fun onEmailChange(value: String) {
        _email.value = value
    }

    fun sendResetLink() {
        viewModelScope.launch {
            _uiState.value = AuthState.Loading
            try {
                SupabaseClient.client.auth.resetPasswordForEmail(email = _email.value)
                _uiState.value = AuthState.Success // Indicates success, UI can show a message
            } catch (e: Exception) {
                _uiState.value = AuthState.Error(e.message ?: "An unknown error occurred")
            }
        }
    }
}
