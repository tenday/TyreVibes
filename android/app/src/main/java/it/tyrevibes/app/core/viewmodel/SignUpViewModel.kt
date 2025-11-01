package it.tyrevibes.app.core.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import it.tyrevibes.app.core.service.AuthService
import it.tyrevibes.app.core.service.Country
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.regex.Pattern

data class PasswordRequirement(
    val text: String,
    val isValid: Boolean
)

data class SignUpUiState(
    val fullName: String = "",
    val username: String = "",
    val phoneNumber: String = "",
    val email: String = "",
    val password: String = "",
    val confirmPassword: String = "",
    val agreedToTerms: Boolean = false,
    val selectedCountry: Country = Country(
        id = 1,
        name = "Italy",
        dialCode = "+39",
        code = "IT"
    ),
    val countries: List<Country> = emptyList(),
    val searchText: String = "",
    val passwordRequirements: List<PasswordRequirement> = emptyList(),
    val isLoadingCreationAccount: Boolean = false,
    val isLoadingCountries: Boolean = false,
    val isLoadingCheckingOtp: Boolean = false,
    val showAlert: Boolean = false,
    val alertTitle: String = "",
    val alertMessage: String = "",
    val showSuccessAlert: Boolean = false,
    val fullOtp: String = "",
    val showCreationSuccessScreen: Boolean = false
)

class SignUpViewModel : ViewModel() {

    private val _uiState = MutableStateFlow(SignUpUiState())
    val uiState: StateFlow<SignUpUiState> = _uiState.asStateFlow()

    private val authService = AuthService()

    init {
        setupPasswordValidation()
    }

    // Computed properties
    val isEmailValid: Boolean
        get() {
            val emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
            val pattern = Pattern.compile(emailRegex)
            return pattern.matcher(_uiState.value.email).matches()
        }

    val isPasswordValid: Boolean
        get() = _uiState.value.passwordRequirements.all { it.isValid }

    val isConfirmPasswordValid: Boolean
        get() = with(_uiState.value) {
            password.isNotEmpty() && password == confirmPassword
        }

    val isSignUpButtonEnabled: Boolean
        get() = with(_uiState.value) {
            fullName.isNotEmpty() &&
                    username.isNotEmpty() &&
                    phoneNumber.isNotEmpty() &&
                    isEmailValid &&
                    isPasswordValid &&
                    isConfirmPasswordValid &&
                    agreedToTerms
        }

    val filteredCountries: List<Country>
        get() = with(_uiState.value) {
            if (searchText.isEmpty()) {
                countries
            } else {
                countries.filter {
                    it.name.contains(searchText, ignoreCase = true) ||
                            it.dialCode.contains(searchText)
                }
            }
        }

    // State update methods
    fun onFullNameChange(fullName: String) {
        _uiState.value = _uiState.value.copy(fullName = fullName)
    }

    fun onUsernameChange(username: String) {
        val formattedUsername = if (username.isNotEmpty() && !username.startsWith("@")) {
            "@$username"
        } else {
            username
        }
        _uiState.value = _uiState.value.copy(username = formattedUsername)
    }

    fun onPhoneNumberChange(phoneNumber: String) {
        _uiState.value = _uiState.value.copy(phoneNumber = phoneNumber)
    }

    fun onEmailChange(email: String) {
        _uiState.value = _uiState.value.copy(email = email)
    }

    fun onPasswordChange(password: String) {
        _uiState.value = _uiState.value.copy(password = password)
        validatePassword(password)
    }

    fun onConfirmPasswordChange(confirmPassword: String) {
        _uiState.value = _uiState.value.copy(confirmPassword = confirmPassword)
    }

    fun onAgreedToTermsChange(agreed: Boolean) {
        _uiState.value = _uiState.value.copy(agreedToTerms = agreed)
    }

    fun onSelectedCountryChange(country: Country) {
        _uiState.value = _uiState.value.copy(selectedCountry = country)
    }

    fun onSearchTextChange(searchText: String) {
        _uiState.value = _uiState.value.copy(searchText = searchText)
    }

    fun onOtpChange(otp: String) {
        _uiState.value = _uiState.value.copy(fullOtp = otp)
    }

    fun dismissAlert() {
        _uiState.value = _uiState.value.copy(
            showAlert = false,
            alertTitle = "",
            alertMessage = ""
        )
    }

    // Password validation
    private fun setupPasswordValidation() {
        // Initialize password requirements
        validatePassword("")
    }

    private fun validatePassword(password: String) {
        val requirements = listOf(
            PasswordRequirement(
                "At least one upper case letter",
                password.any { it.isUpperCase() }
            ),
            PasswordRequirement(
                "At least one numeral (0-9)",
                password.any { it.isDigit() }
            ),
            PasswordRequirement(
                "Minimum 6 characters",
                password.length >= 6
            ),
            PasswordRequirement(
                "At least one special symbol (!@#...)",
                password.any { it in "!@#\$%^&*()<>{}|-" }
            )
        )
        _uiState.value = _uiState.value.copy(passwordRequirements = requirements)
    }

    // Fetch countries
    fun fetchCountries() {
        _uiState.value = _uiState.value.copy(isLoadingCountries = true)

        viewModelScope.launch {
            try {
                val countries = authService.fetchCountries()
                _uiState.value = _uiState.value.copy(
                    countries = countries,
                    isLoadingCountries = false
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoadingCountries = false,
                    showAlert = true,
                    alertTitle = "Errore",
                    alertMessage = "Impossibile caricare i paesi: ${e.message}"
                )
            }
        }
    }

    // Create account
    fun createAccount() {
        if (!isSignUpButtonEnabled) return

        _uiState.value = _uiState.value.copy(isLoadingCreationAccount = true)

        viewModelScope.launch {
            try {
                authService.createAccount(
                    email = _uiState.value.email,
                    password = _uiState.value.password,
                    fullName = _uiState.value.fullName,
                    username = _uiState.value.username,
                    phoneNumber = _uiState.value.phoneNumber,
                    selectedCountry = _uiState.value.selectedCountry,
                    agreedToTerms = _uiState.value.agreedToTerms
                )

                _uiState.value = _uiState.value.copy(
                    isLoadingCreationAccount = false,
                    showCreationSuccessScreen = true
                )

            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoadingCreationAccount = false,
                    showAlert = true,
                    alertTitle = "Errore Registrazione",
                    alertMessage = e.message ?: "Si è verificato un errore durante la registrazione"
                )
            }
        }
    }

    // Send OTP
    fun sendOtp() {
        val fullPhoneNumber = "${_uiState.value.selectedCountry.dialCode}${_uiState.value.phoneNumber}"

        _uiState.value = _uiState.value.copy(isLoadingCheckingOtp = true)

        viewModelScope.launch {
            try {
                authService.sendOtp(fullPhoneNumber)
                _uiState.value = _uiState.value.copy(
                    isLoadingCheckingOtp = false,
                    showSuccessAlert = true
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoadingCheckingOtp = false,
                    showAlert = true,
                    alertTitle = "Errore OTP",
                    alertMessage = "Impossibile inviare OTP: ${e.message}"
                )
            }
        }
    }

    // Verify OTP
    fun verifyOtp() {
        val fullPhoneNumber = "${_uiState.value.selectedCountry.dialCode}${_uiState.value.phoneNumber}"

        _uiState.value = _uiState.value.copy(isLoadingCheckingOtp = true)

        viewModelScope.launch {
            try {
                authService.verifyOtp(
                    _uiState.value.fullOtp,
                    fullPhoneNumber
                )
                _uiState.value = _uiState.value.copy(
                    isLoadingCheckingOtp = false,
                    showSuccessAlert = true
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoadingCheckingOtp = false,
                    showAlert = true,
                    alertTitle = "Verifica Fallita",
                    alertMessage = "Codice OTP non valido: ${e.message}"
                )
            }
        }
    }
}
