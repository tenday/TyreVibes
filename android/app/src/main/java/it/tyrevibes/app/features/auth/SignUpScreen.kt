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
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import it.tyrevibes.app.core.viewmodel.SignUpViewModel
import it.tyrevibes.app.ui.components.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SignUpScreen(
    viewModel: SignUpViewModel = SignUpViewModel(),
    onNavigateToLogin: () -> Unit = {},
    onNavigateToHome: () -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsState()

    LaunchedEffect(Unit) {
        viewModel.fetchCountries()
    }

    LaunchedEffect(uiState.showCreationSuccessScreen) {
        if (uiState.showCreationSuccessScreen) {
            onNavigateToHome()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Registrazione") },
                navigationIcon = {
                    IconButton(onClick = onNavigateToLogin) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Indietro")
                    }
                }
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(24.dp)
                .verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text(
                text = "Crea il tuo account",
                style = MaterialTheme.typography.headlineSmall,
                color = MaterialTheme.colorScheme.primary
            )

            Spacer(modifier = Modifier.height(8.dp))

            // Full Name
            TyreTextField(
                value = uiState.fullName,
                onValueChange = viewModel::onFullNameChange,
                label = "Nome Completo",
                leadingIcon = Icons.Default.Person,
                imeAction = ImeAction.Next
            )

            // Username
            TyreTextField(
                value = uiState.username,
                onValueChange = viewModel::onUsernameChange,
                label = "Username",
                leadingIcon = Icons.Default.AlternateEmail,
                imeAction = ImeAction.Next
            )

            // Email
            TyreTextField(
                value = uiState.email,
                onValueChange = viewModel::onEmailChange,
                label = "Email",
                leadingIcon = Icons.Default.Email,
                keyboardType = KeyboardType.Email,
                imeAction = ImeAction.Next,
                isError = uiState.email.isNotEmpty() && !viewModel.isEmailValid,
                errorMessage = if (uiState.email.isNotEmpty() && !viewModel.isEmailValid) "Email non valida" else null
            )

            // Phone Number with Country
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                // Country Selector (simplified)
                OutlinedButton(
                    onClick = { /* TODO: Show country picker */ },
                    modifier = Modifier.width(100.dp)
                ) {
                    Text(uiState.selectedCountry.dialCode)
                }

                TyreTextField(
                    value = uiState.phoneNumber,
                    onValueChange = viewModel::onPhoneNumberChange,
                    label = "Telefono",
                    keyboardType = KeyboardType.Phone,
                    imeAction = ImeAction.Next,
                    modifier = Modifier.weight(1f)
                )
            }

            // Password
            TyrePasswordTextField(
                value = uiState.password,
                onValueChange = viewModel::onPasswordChange,
                label = "Password",
                imeAction = ImeAction.Next
            )

            // Password Requirements
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                uiState.passwordRequirements.forEach { requirement ->
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Icon(
                            imageVector = if (requirement.isValid) Icons.Default.CheckCircle else Icons.Default.Circle,
                            contentDescription = null,
                            tint = if (requirement.isValid) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.size(16.dp)
                        )
                        Text(
                            text = requirement.text,
                            style = MaterialTheme.typography.bodySmall,
                            color = if (requirement.isValid) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            // Confirm Password
            TyrePasswordTextField(
                value = uiState.confirmPassword,
                onValueChange = viewModel::onConfirmPasswordChange,
                label = "Conferma Password",
                imeAction = ImeAction.Done,
                isError = uiState.confirmPassword.isNotEmpty() && !viewModel.isConfirmPasswordValid,
                errorMessage = if (uiState.confirmPassword.isNotEmpty() && !viewModel.isConfirmPasswordValid) "Le password non corrispondono" else null
            )

            // Terms and Conditions
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Checkbox(
                    checked = uiState.agreedToTerms,
                    onCheckedChange = viewModel::onAgreedToTermsChange
                )
                Text(
                    "Accetto i Termini e Condizioni",
                    style = MaterialTheme.typography.bodyMedium
                )
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Sign Up Button
            TyreButton(
                text = "Registrati",
                onClick = { viewModel.createAccount() },
                enabled = viewModel.isSignUpButtonEnabled,
                isLoading = uiState.isLoadingCreationAccount
            )

            // Already have account
            Row {
                Text("Hai già un account? ")
                TyreTextButton(
                    text = "Accedi",
                    onClick = onNavigateToLogin
                )
            }

            // Alert Dialogs
            if (uiState.showAlert) {
                AlertDialog(
                    onDismissRequest = viewModel::dismissAlert,
                    title = { Text(uiState.alertTitle) },
                    text = { Text(uiState.alertMessage) },
                    confirmButton = {
                        TyreTextButton(
                            text = "OK",
                            onClick = viewModel::dismissAlert
                        )
                    }
                )
            }
        }
    }
}
