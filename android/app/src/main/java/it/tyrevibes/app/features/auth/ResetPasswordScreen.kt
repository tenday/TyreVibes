package it.tyrevibes.app.features.auth

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import it.tyrevibes.app.core.viewmodel.ResetPasswordViewModel
import it.tyrevibes.app.ui.components.TyreButton
import it.tyrevibes.app.ui.components.TyreTextField
import it.tyrevibes.app.ui.theme.SoraFontFamily

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ResetPasswordScreen(
    viewModel: ResetPasswordViewModel,
    onNavigateBack: () -> Unit,
    onPasswordResetSuccess: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()

    // Navigate on success
    LaunchedEffect(uiState.passwordReset) {
        if (uiState.passwordReset) {
            kotlinx.coroutines.delay(1500)
            onPasswordResetSuccess()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Reimposta Password") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Indietro")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Transparent
                )
            )
        },
        containerColor = Color(0xFF121212)
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(modifier = Modifier.height(40.dp))

            // Icon
            Icon(
                imageVector = Icons.Default.Lock,
                contentDescription = null,
                tint = Color(0xFF007AFF),
                modifier = Modifier.size(80.dp)
            )

            Spacer(modifier = Modifier.height(24.dp))

            // Title
            Text(
                text = "Nuova Password",
                fontFamily = SoraFontFamily,
                fontWeight = FontWeight.Bold,
                fontSize = 28.sp,
                color = Color.White,
                textAlign = TextAlign.Center
            )

            Spacer(modifier = Modifier.height(12.dp))

            // Description
            Text(
                text = "Inserisci la tua nuova password. Deve essere di almeno 8 caratteri.",
                fontFamily = SoraFontFamily,
                fontSize = 16.sp,
                color = Color.White.copy(alpha = 0.7f),
                textAlign = TextAlign.Center,
                lineHeight = 24.sp
            )

            Spacer(modifier = Modifier.height(40.dp))

            // New password field
            TyreTextField(
                value = uiState.newPassword,
                onValueChange = viewModel::updateNewPassword,
                label = "Nuova Password",
                placeholder = "inserisci nuova password",
                leadingIcon = Icons.Default.Lock,
                trailingIcon = if (uiState.showPassword) Icons.Default.Visibility else Icons.Default.VisibilityOff,
                onTrailingIconClick = viewModel::togglePasswordVisibility,
                visualTransformation = if (uiState.showPassword) VisualTransformation.None else PasswordVisualTransformation(),
                enabled = !uiState.isLoading && !uiState.passwordReset
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Confirm password field
            TyreTextField(
                value = uiState.confirmPassword,
                onValueChange = viewModel::updateConfirmPassword,
                label = "Conferma Password",
                placeholder = "conferma nuova password",
                leadingIcon = Icons.Default.Lock,
                trailingIcon = if (uiState.showPassword) Icons.Default.Visibility else Icons.Default.VisibilityOff,
                onTrailingIconClick = viewModel::togglePasswordVisibility,
                visualTransformation = if (uiState.showPassword) VisualTransformation.None else PasswordVisualTransformation(),
                enabled = !uiState.isLoading && !uiState.passwordReset
            )

            // Error message
            if (uiState.error != null) {
                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    text = uiState.error!!,
                    fontFamily = SoraFontFamily,
                    fontSize = 14.sp,
                    color = Color(0xFFFF3B30),
                    textAlign = TextAlign.Center
                )
            }

            // Success message
            if (uiState.successMessage != null) {
                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    text = uiState.successMessage!!,
                    fontFamily = SoraFontFamily,
                    fontSize = 14.sp,
                    color = Color(0xFF34C759),
                    textAlign = TextAlign.Center
                )
            }

            Spacer(modifier = Modifier.height(32.dp))

            // Reset button
            TyreButton(
                text = if (uiState.passwordReset) "Password Aggiornata!" else "Reimposta Password",
                onClick = viewModel::resetPassword,
                isLoading = uiState.isLoading,
                enabled = viewModel.isFormValid && !uiState.passwordReset,
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(modifier = Modifier.height(40.dp))
        }
    }
}
