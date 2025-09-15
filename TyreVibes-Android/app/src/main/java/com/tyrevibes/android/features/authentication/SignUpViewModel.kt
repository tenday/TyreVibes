package com.tyrevibes.android.features.authentication

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.tyrevibes.android.core.data.SupabaseClient
import io.supabase.gotrue.auth.signUpWith
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

class SignUpViewModel : ViewModel() {

    // Form Properties
    private val _fullName = MutableStateFlow("")
    val fullName = _fullName.asStateFlow()

    private val _username = MutableStateFlow("")
    val username = _username.asStateFlow()

    private val _email = MutableStateFlow("")
    val email = _email.asStateFlow()

    private val _password = MutableStateFlow("")
    val password = _password.asStateFlow()

    private val _confirmPassword = MutableStateFlow("")
    val confirmPassword = _confirmPassword.asStateFlow()

    private val _agreedToTerms = MutableStateFlow(false)
    val agreedToTerms = _agreedToTerms.asStateFlow()

    // Validation & State
    private val _signUpState = MutableStateFlow<AuthState>(AuthState.Idle)
    val signUpState = _signUpState.asStateFlow()

    val isEmailValid: StateFlow<Boolean> = email.map {
        android.util.Patterns.EMAIL_ADDRESS.matcher(it).matches()
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), false)

    val passwordRequirements: StateFlow<List<PasswordRequirement>> = password.map { pass ->
        listOf(
            PasswordRequirement("At least one upper case letter", pass.any { it.isUpperCase() }),
            PasswordRequirement("At least one numeral (0-9)", pass.any { it.isDigit() }),
            PasswordRequirement("Minimum 6 characters", pass.length >= 6),
            PasswordRequirement("At least one special symbol (!@#...)", pass.any { !it.isLetterOrDigit() })
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val isPasswordValid: StateFlow<Boolean> = passwordRequirements.map { requirements ->
        requirements.all { it.isValid }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), false)

    val isConfirmPasswordValid: StateFlow<Boolean> = combine(password, confirmPassword) { pass, confirm ->
        pass.isNotEmpty() && pass == confirm
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), false)

    val isSignUpButtonEnabled: StateFlow<Boolean> = combine(
        fullName, username, email, isPasswordValid, isConfirmPasswordValid, agreedToTerms
    ) { fullName, username, email, passValid, confirmPassValid, terms ->
        fullName.isNotEmpty() && username.isNotEmpty() && email.isNotEmpty() && passValid && confirmPassValid && terms
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), false)


    // Methods
    fun onFullNameChange(value: String) { _fullName.value = value }
    fun onUsernameChange(value: String) { _username.value = value }
    fun onEmailChange(value: String) { _email.value = value }
    fun onPasswordChange(value: String) { _password.value = value }
    fun onConfirmPasswordChange(value: String) { _confirmPassword.value = value }
    fun onAgreedToTermsChange(value: Boolean) { _agreedToTerms.value = value }

    fun signUp() {
        viewModelScope.launch {
            _signUpState.value = AuthState.Loading
            try {
                SupabaseClient.client.auth.signUpWith(email = email.value) {
                    password = this@SignUpViewModel.password.value
                    // TODO: Add other user metadata here
                }
                _signUpState.value = AuthState.Success
            } catch (e: Exception) {
                _signUpState.value = AuthState.Error(e.message ?: "An unknown error occurred")
            }
        }
    }
}
