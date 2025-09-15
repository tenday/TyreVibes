package com.tyrevibes.android.features.authentication

import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.tyrevibes.android.ui.theme.CustomBackgroundColor
import com.tyrevibes.android.ui.theme.CustomBitterSweet

@Composable
fun ForgotPasswordScreen(
    onNavigateBack: () -> Unit,
    viewModel: ForgotPasswordViewModel = viewModel()
) {
    val email by viewModel.email.collectAsStateWithLifecycle()
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val context = LocalContext.current

    LaunchedEffect(uiState) {
        when (val state = uiState) {
            is AuthState.Success -> {
                Toast.makeText(context, "Password reset link sent to your email.", Toast.LENGTH_LONG).show()
                onNavigateBack()
            }
            is AuthState.Error -> {
                Toast.makeText(context, state.message, Toast.LENGTH_LONG).show()
            }
            else -> {}
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(CustomBackgroundColor)
            .padding(20.dp)
    ) {
        IconButton(onClick = onNavigateBack) {
            Icon(imageVector = Icons.Default.ArrowBack, contentDescription = "Back", tint = Color.White)
        }
        Spacer(modifier = Modifier.height(20.dp))
        Text(
            text = "Forgot Password",
            fontSize = 32.sp,
            fontWeight = FontWeight.SemiBold,
            color = Color.White
        )
        Text(
            text = "Enter your email to receive a reset link.",
            fontSize = 16.sp,
            color = Color.Gray,
            modifier = Modifier.padding(top = 12.dp)
        )
        Spacer(modifier = Modifier.height(40.dp))
        SignUpTextField( // Reusing the text field from sign up
            value = email,
            onValueChange = viewModel::onEmailChange,
            placeholder = "Enter your email",
            iconRes = R.drawable.ic_email
        )
        Spacer(modifier = Modifier.weight(1f))
        Button(
            onClick = { viewModel.sendResetLink() },
            modifier = Modifier
                .fillMaxWidth()
                .height(60.dp),
            enabled = uiState !is AuthState.Loading,
            colors = ButtonDefaults.buttonColors(containerColor = CustomBitterSweet)
        ) {
            if (uiState is AuthState.Loading) {
                CircularProgressIndicator(color = Color.White)
            } else {
                Text("Send Reset Link", color = Color.White)
            }
        }
    }
}
