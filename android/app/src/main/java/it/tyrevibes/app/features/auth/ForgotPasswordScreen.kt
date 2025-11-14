package it.tyrevibes.app.features.auth

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Email
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import it.tyrevibes.app.core.viewmodel.ForgotPasswordViewModel
import it.tyrevibes.app.ui.components.TyreButton
import it.tyrevibes.app.ui.components.TyreTextField
import it.tyrevibes.app.ui.theme.SoraFontFamily

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ForgotPasswordScreen(
    viewModel: ForgotPasswordViewModel,
    onNavigateBack: () -> Unit,
    onPasswordResetSent: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()

    // Navigate back on success
    LaunchedEffect(uiState.emailSent) {
        if (uiState.emailSent) {
            kotlinx.coroutines.delay(2000)
            onPasswordResetSent()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Recupera Password") },
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
                imageVector = Icons.Default.Email,
                contentDescription = null,
                tint = Color(0xFF007AFF),
                modifier = Modifier.size(80.dp)
            )

            Spacer(modifier = Modifier.height(24.dp))

            // Title
            Text(
                text = "Password Dimenticata?",
                fontFamily = SoraFontFamily,
                fontWeight = FontWeight.Bold,
                fontSize = 28.sp,
                color = Color.White,
                textAlign = TextAlign.Center
            )

            Spacer(modifier = Modifier.height(12.dp))

            // Description
            Text(
                text = "Inserisci la tua email e ti invieremo un link per reimpostare la password",
                fontFamily = SoraFontFamily,
                fontSize = 16.sp,
                color = Color.White.copy(alpha = 0.7f),
                textAlign = TextAlign.Center,
                lineHeight = 24.sp
            )

            Spacer(modifier = Modifier.height(40.dp))

            // Email field
            TyreTextField(
                value = uiState.email,
                onValueChange = viewModel::updateEmail,
                label = "Email",
                placeholder = "inserisci la tua email",
                leadingIcon = Icons.Default.Email,
                keyboardType = androidx.compose.ui.text.input.KeyboardType.Email,
                enabled = !uiState.isLoading && !uiState.emailSent
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

            // Send button
            TyreButton(
                text = if (uiState.emailSent) "Email Inviata!" else "Invia Email di Recupero",
                onClick = viewModel::sendResetEmail,
                isLoading = uiState.isLoading,
                enabled = viewModel.isFormValid && !uiState.emailSent,
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Back to login
            TextButton(
                onClick = onNavigateBack,
                enabled = !uiState.isLoading
            ) {
                Text(
                    text = "Torna al Login",
                    fontFamily = SoraFontFamily,
                    fontSize = 16.sp,
                    color = Color(0xFF007AFF)
                )
            }

            Spacer(modifier = Modifier.height(40.dp))
        }
    }
}
