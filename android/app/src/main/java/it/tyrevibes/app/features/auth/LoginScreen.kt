package it.tyrevibes.app.features.auth

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import it.tyrevibes.app.core.viewmodel.LoginViewModel
import it.tyrevibes.app.ui.components.*

@Composable
fun LoginScreen(
    viewModel: LoginViewModel = LoginViewModel(LocalContext.current),
    onNavigateToSignUp: () -> Unit = {},
    onNavigateToForgotPassword: () -> Unit = {},
    onNavigateToHome: () -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsState()

    LaunchedEffect(uiState.showHomeScreen) {
        if (uiState.showHomeScreen) {
            onNavigateToHome()
        }
    }

    Scaffold { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(24.dp)
                .verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            // Logo/Title
            Text(
                text = "TyreVibes",
                style = MaterialTheme.typography.displayMedium,
                color = MaterialTheme.colorScheme.primary,
                textAlign = TextAlign.Center
            )

            Spacer(modifier = Modifier.height(8.dp))

            Text(
                text = "Bentornato!",
                style = MaterialTheme.typography.titleLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center
            )

            Spacer(modifier = Modifier.height(48.dp))

            // Email Field
            TyreTextField(
                value = uiState.email,
                onValueChange = viewModel::onEmailChange,
                label = "Email",
                leadingIcon = Icons.Default.Email,
                keyboardType = androidx.compose.ui.text.input.KeyboardType.Email,
                imeAction = ImeAction.Next
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Password Field
            TyrePasswordTextField(
                value = uiState.password,
                onValueChange = viewModel::onPasswordChange,
                label = "Password",
                imeAction = ImeAction.Done,
                onImeAction = { if (viewModel.isLoginButtonEnabled) viewModel.signIn() }
            )

            Spacer(modifier = Modifier.height(8.dp))

            // Remember Me & Forgot Password
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Checkbox(
                        checked = uiState.rememberMe,
                        onCheckedChange = viewModel::onRememberMeChange
                    )
                    Text("Ricordami", style = MaterialTheme.typography.bodyMedium)
                }

                TyreTextButton(
                    text = "Password dimenticata?",
                    onClick = onNavigateToForgotPassword
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Login Button
            TyreButton(
                text = "Accedi",
                onClick = { viewModel.signIn() },
                enabled = viewModel.isLoginButtonEnabled,
                isLoading = uiState.isLoading
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Sign Up Link
            Row {
                Text("Non hai un account? ")
                TyreTextButton(
                    text = "Registrati",
                    onClick = onNavigateToSignUp
                )
            }

            // Error Alert
            if (uiState.alertTitle != null) {
                AlertDialog(
                    onDismissRequest = viewModel::clearAlert,
                    title = { Text(uiState.alertTitle!!) },
                    text = { Text(uiState.alertMessage ?: "") },
                    confirmButton = {
                        TyreTextButton(
                            text = "OK",
                            onClick = viewModel::clearAlert
                        )
                    }
                )
            }
        }
    }
}
