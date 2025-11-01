package it.tyrevibes.app.core.service

import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.builtin.Email
import io.github.jan.supabase.auth.providers.builtin.OTP
import io.github.jan.supabase.postgrest.from
import it.tyrevibes.app.core.model.Users
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Custom exceptions per AuthService
 */
sealed class AuthServiceError : Exception() {
    data class SignUpFailed(override val message: String) : AuthServiceError()
    data class ProfileCreationFailed(override val message: String) : AuthServiceError()
    object NoUserFound : AuthServiceError()
    data class InvalidEmail(override val message: String) : AuthServiceError()
    object OtpInvalid : AuthServiceError()
    object OtpExpired : AuthServiceError()
}

data class Country(
    val id: Int,
    val name: String,
    val dialCode: String,
    val code: String
)

/**
 * Authentication Service
 * Gestisce tutte le operazioni di autenticazione con Supabase (JWT-based)
 */
class AuthService {

    private val client = SupabaseManager.client

    /**
     * Get current user ID
     */
    suspend fun getCurrentUserId(): String? = withContext(Dispatchers.IO) {
        SupabaseManager.getCurrentUserId()
    }

    /**
     * Fetch countries from database
     */
    suspend fun fetchCountries(): List<Country> = withContext(Dispatchers.IO) {
        try {
            client.from("countries")
                .select()
                .decodeList<Country>()
        } catch (e: Exception) {
            throw AuthServiceError.SignUpFailed("Failed to fetch countries: ${e.message}")
        }
    }

    /**
     * Create new user account with profile
     */
    suspend fun createAccount(
        email: String,
        password: String,
        fullName: String,
        username: String,
        phoneNumber: String,
        selectedCountry: Country,
        agreedToTerms: Boolean
    ): Unit = withContext(Dispatchers.IO) {
        try {
            // STEP 1: Sign up with Supabase Auth
            val authResponse = client.auth.signUpWith(Email) {
                this.email = email
                this.password = password
            }

            val userId = authResponse?.user?.id
                ?: throw AuthServiceError.SignUpFailed("User ID not returned from signup")

            // STEP 2: Create profile in users table
            val newProfile = Users(
                id = userId,
                fullName = fullName,
                username = username,
                phoneNumber = phoneNumber,
                countryDialCode = selectedCountry.dialCode,
                agreedToTerms = agreedToTerms
            )

            // STEP 3: Insert profile into database
            try {
                client.from("users")
                    .insert(newProfile)
            } catch (e: Exception) {
                // Clean up: attempt to delete the auth user if profile creation fails
                try {
                    client.auth.admin.deleteUser(userId)
                } catch (deleteError: Exception) {
                    // Ignore delete error
                }
                throw AuthServiceError.ProfileCreationFailed(e.message ?: "Unknown error")
            }

        } catch (e: AuthServiceError) {
            throw e
        } catch (e: Exception) {
            throw AuthServiceError.SignUpFailed(e.message ?: "Unknown error")
        }
    }

    /**
     * Send OTP to phone number
     */
    suspend fun sendOtp(phoneNumber: String): Unit = withContext(Dispatchers.IO) {
        try {
            client.auth.signInWith(OTP) {
                this.phone = phoneNumber
            }
        } catch (e: Exception) {
            throw AuthServiceError.SignUpFailed("Failed to send OTP: ${e.message}")
        }
    }

    /**
     * Verify OTP code
     */
    suspend fun verifyOtp(otpCode: String, phoneNumber: String): Unit = withContext(Dispatchers.IO) {
        try {
            client.auth.verifyPhoneOtp(
                type = OTP.OtpType.SMS,
                phone = phoneNumber,
                token = otpCode
            )
        } catch (e: Exception) {
            throw AuthServiceError.OtpInvalid
        }
    }

    /**
     * Sign in with email and password
     */
    suspend fun signIn(email: String, password: String): Unit = withContext(Dispatchers.IO) {
        try {
            client.auth.signInWith(Email) {
                this.email = email
                this.password = password
            }
        } catch (e: Exception) {
            throw AuthServiceError.SignUpFailed("Sign in failed: ${e.message}")
        }
    }

    /**
     * Sign out current user
     */
    suspend fun logout(): Unit = withContext(Dispatchers.IO) {
        try {
            client.auth.signOut()
        } catch (e: Exception) {
            throw AuthServiceError.SignUpFailed("Logout failed: ${e.message}")
        }
    }

    /**
     * Delete current user account
     */
    suspend fun deleteCurrentUser(): Unit = withContext(Dispatchers.IO) {
        val userId = getCurrentUserId()
            ?: throw AuthServiceError.NoUserFound

        try {
            client.auth.admin.deleteUser(userId)
        } catch (e: Exception) {
            throw AuthServiceError.SignUpFailed("Failed to delete user: ${e.message}")
        }
    }

    /**
     * Send password reset email
     */
    suspend fun sendPasswordResetEmail(email: String): Unit = withContext(Dispatchers.IO) {
        try {
            client.auth.resetPasswordForEmail(email)
        } catch (e: Exception) {
            throw AuthServiceError.SignUpFailed("Failed to send reset email: ${e.message}")
        }
    }

    /**
     * Check if user is currently signed in
     */
    suspend fun isSignedIn(): Boolean = withContext(Dispatchers.IO) {
        client.auth.currentSessionOrNull() != null
    }
}
