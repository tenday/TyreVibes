package it.tyrevibes.app.core.viewmodel

import android.graphics.Bitmap
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import it.tyrevibes.app.core.model.Users
import it.tyrevibes.app.core.service.AuthService
import it.tyrevibes.app.core.service.SupabaseManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class ProfileUiState(
    val user: Users? = null,
    val isLoading: Boolean = false,
    val isEditing: Boolean = false,
    val error: String? = null,
    val profilePhotoUrl: String? = null,

    // Editable fields
    val editFullName: String = "",
    val editUsername: String = "",
    val editEmail: String = "",
    val editPhoneNumber: String? = null,
    val editBio: String? = null,

    // Statistics
    val vehicleCount: Int = 0,
    val analysisCount: Int = 0,
    val reportCount: Int = 0
)

class ProfileViewModel(
    private val authService: AuthService,
    private val supabaseManager: SupabaseManager
) : ViewModel() {

    private val _uiState = MutableStateFlow(ProfileUiState())
    val uiState: StateFlow<ProfileUiState> = _uiState.asStateFlow()

    init {
        loadProfile()
    }

    fun loadProfile() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)

            try {
                val userId = supabaseManager.getCurrentUserId()
                if (userId != null) {
                    // TODO: Load user profile from Supabase
                    // val user = userService.getProfile(userId)
                    // _uiState.value = _uiState.value.copy(user = user, isLoading = false)

                    // Placeholder
                    _uiState.value = _uiState.value.copy(isLoading = false)
                } else {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        error = "User not authenticated"
                    )
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = e.message ?: "Failed to load profile"
                )
            }
        }
    }

    fun startEditing() {
        val user = _uiState.value.user ?: return
        _uiState.value = _uiState.value.copy(
            isEditing = true,
            editFullName = user.fullName,
            editUsername = user.username,
            editEmail = user.email ?: "",
            editPhoneNumber = user.phoneNumber,
            editBio = user.bio
        )
    }

    fun cancelEditing() {
        _uiState.value = _uiState.value.copy(isEditing = false, error = null)
    }

    fun updateFullName(fullName: String) {
        _uiState.value = _uiState.value.copy(editFullName = fullName)
    }

    fun updateUsername(username: String) {
        _uiState.value = _uiState.value.copy(editUsername = username)
    }

    fun updateEmail(email: String) {
        _uiState.value = _uiState.value.copy(editEmail = email)
    }

    fun updatePhoneNumber(phoneNumber: String?) {
        _uiState.value = _uiState.value.copy(editPhoneNumber = phoneNumber)
    }

    fun updateBio(bio: String?) {
        _uiState.value = _uiState.value.copy(editBio = bio)
    }

    fun saveProfile() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)

            try {
                val userId = supabaseManager.getCurrentUserId() ?: throw Exception("Not authenticated")

                // TODO: Update profile in Supabase
                // val updatedUser = userService.updateProfile(
                //     userId,
                //     fullName = _uiState.value.editFullName,
                //     username = _uiState.value.editUsername,
                //     email = _uiState.value.editEmail,
                //     phoneNumber = _uiState.value.editPhoneNumber,
                //     bio = _uiState.value.editBio
                // )

                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    isEditing = false
                    // user = updatedUser
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = e.message ?: "Failed to save profile"
                )
            }
        }
    }

    fun uploadProfilePhoto(photo: Bitmap) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)

            try {
                val userId = supabaseManager.getCurrentUserId() ?: throw Exception("Not authenticated")

                // TODO: Upload photo to Supabase Storage
                // val photoUrl = storageService.uploadProfilePhoto(userId, photo)
                // _uiState.value = _uiState.value.copy(profilePhotoUrl = photoUrl, isLoading = false)

                _uiState.value = _uiState.value.copy(isLoading = false)
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = e.message ?: "Failed to upload photo"
                )
            }
        }
    }

    fun logout() {
        viewModelScope.launch {
            try {
                authService.signOut()
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    error = e.message ?: "Failed to logout"
                )
            }
        }
    }

    fun deleteAccount() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)

            try {
                val userId = supabaseManager.getCurrentUserId() ?: throw Exception("Not authenticated")

                // TODO: Delete account from Supabase
                // userService.deleteAccount(userId)
                authService.signOut()

                _uiState.value = _uiState.value.copy(isLoading = false)
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = e.message ?: "Failed to delete account"
                )
            }
        }
    }
}
