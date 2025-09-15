package com.tyrevibes.android.features.authentication

import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.ClickableText
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.tyrevibes.android.R
import com.tyrevibes.android.ui.theme.*

@Composable
fun SignUpScreen(
    onSignUpComplete: () -> Unit,
    onNavigateBack: () -> Unit,
    viewModel: SignUpViewModel = viewModel()
) {
    val context = LocalContext.current
    val fullName by viewModel.fullName.collectAsStateWithLifecycle()
    val username by viewModel.username.collectAsStateWithLifecycle()
    val email by viewModel.email.collectAsStateWithLifecycle()
    val password by viewModel.password.collectAsStateWithLifecycle()
    val confirmPassword by viewModel.confirmPassword.collectAsStateWithLifecycle()
    val agreedToTerms by viewModel.agreedToTerms.collectAsStateWithLifecycle()
    val signUpState by viewModel.signUpState.collectAsStateWithLifecycle()
    val isButtonEnabled by viewModel.isSignUpButtonEnabled.collectAsStateWithLifecycle()
    val passwordRequirements by viewModel.passwordRequirements.collectAsStateWithLifecycle()

    LaunchedEffect(signUpState) {
        when (val state = signUpState) {
            is AuthState.Success -> {
                Toast.makeText(context, "Sign Up Successful! Please verify your email.", Toast.LENGTH_LONG).show()
                onSignUpComplete()
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
    ) {
        // Header
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onNavigateBack) {
                Icon(
                    imageVector = Icons.Default.ArrowBack,
                    contentDescription = "Navigate Back",
                    tint = Color.White
                )
            }
        }

        Column(
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = 20.dp)
                .verticalScroll(rememberScrollState())
        ) {
            // Title and subtitle
            Text(
                text = "Create Account",
                fontFamily = soraFontFamily,
                fontWeight = FontWeight.SemiBold,
                fontSize = 32.sp,
                color = Color.White
            )
            Text(
                text = "Sign Up to get started",
                fontFamily = soraFontFamily,
                fontWeight = FontWeight.Normal,
                fontSize = 16.sp,
                color = Color.Gray,
                modifier = Modifier.padding(top = 12.dp)
            )

            Spacer(modifier = Modifier.height(24.dp))

            // Form fields
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                SignUpTextField(
                    value = fullName,
                    onValueChange = viewModel::onFullNameChange,
                    placeholder = "Enter Full Name",
                    iconRes = R.drawable.ic_user
                )
                SignUpTextField(
                    value = username,
                    onValueChange = viewModel::onUsernameChange,
                    placeholder = "@Username",
                    iconRes = R.drawable.ic_user
                )
                SignUpTextField(
                    value = email,
                    onValueChange = viewModel::onEmailChange,
                    placeholder = "Enter Email",
                    iconRes = R.drawable.ic_email
                )

                // Password Fields
                SignUpTextField(
                    value = password,
                    onValueChange = viewModel::onPasswordChange,
                    placeholder = "Enter Password",
                    iconRes = R.drawable.ic_password,
                    isPassword = true
                )

                // Password requirements
                Column(
                    modifier = Modifier.padding(start = 4.dp, top = 4.dp, bottom = 4.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    passwordRequirements.forEach { requirement ->
                        PasswordRequirementRow(requirement = requirement)
                    }
                }

                SignUpTextField(
                    value = confirmPassword,
                    onValueChange = viewModel::onConfirmPasswordChange,
                    placeholder = "Confirm Password",
                    iconRes = R.drawable.ic_password_confirm,
                    isPassword = true
                )

                TermsAndConditionsToggle(
                    agreedToTerms = agreedToTerms,
                    onAgreedToTermsChange = viewModel::onAgreedToTermsChange
                )
            }

            Spacer(modifier = Modifier.height(100.dp)) // To ensure scroll
        }

        // Bottom Button
        Button(
            onClick = { viewModel.signUp() },
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp)
                .height(62.dp),
            shape = RoundedCornerShape(100),
            colors = ButtonDefaults.buttonColors(containerColor = CustomBitterSweet),
            enabled = isButtonEnabled && signUpState !is AuthState.Loading
        ) {
            if (signUpState is AuthState.Loading) {
                CircularProgressIndicator(color = Color.White)
            } else {
                Text(
                    text = "Create Account",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
            }
        }
    }
}


@Preview
@Composable
fun SignUpScreenPreview() {
    TyreVibesTheme {
        SignUpScreen(onSignUpComplete = {}, onNavigateBack = {})
    }
}

@Composable
fun SignUpTextField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    iconRes: Int,
    modifier: Modifier = Modifier,
    isPassword: Boolean = false
) {
    var passwordVisible by remember { mutableStateOf(false) }

    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        placeholder = { Text(placeholder, color = Color.Gray) },
        leadingIcon = {
            Icon(
                painter = painterResource(id = iconRes),
                contentDescription = null,
                tint = Color.White
            )
        },
        trailingIcon = {
            if (isPassword) {
                val image = if (passwordVisible)
                    Icons.Filled.Visibility
                else
                    Icons.Filled.VisibilityOff

                val description = if (passwordVisible) "Hide password" else "Show password"

                IconButton(onClick = { passwordVisible = !passwordVisible }) {
                    Icon(imageVector = image, description, tint = Color.White)
                }
            }
        },
        visualTransformation = if (isPassword && !passwordVisible) PasswordVisualTransformation() else VisualTransformation.None,
        modifier = modifier
            .fillMaxWidth()
            .height(62.dp),
        shape = RoundedCornerShape(18.dp),
        colors = TextFieldDefaults.outlinedTextFieldColors(
            containerColor = CustomFieldColor,
            textColor = Color.White,
            focusedBorderColor = Color.Transparent,
            unfocusedBorderColor = Color.Transparent
        ),
        singleLine = true
    )
}

data class PasswordRequirement(
    val text: String,
    val isValid: Boolean
)

@Composable
fun PasswordRequirementRow(requirement: PasswordRequirement) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Box(
            modifier = Modifier
                .size(24.dp)
                .background(
                    if (requirement.isValid) Color.Green else Color.DarkGray,
                    shape = RoundedCornerShape(5.dp)
                ),
            contentAlignment = Alignment.Center
        ) {
            if (requirement.isValid) {
                Icon(
                    imageVector = Icons.Default.Check,
                    contentDescription = "Valid",
                    tint = Color.White,
                    modifier = Modifier.size(16.dp)
                )
            }
        }
        Text(
            text = requirement.text,
            fontSize = 12.sp,
            fontWeight = FontWeight.Normal,
            color = if (requirement.isValid) Color.Green else Color.White
        )
    }
}

@Composable
fun TermsAndConditionsToggle(
    agreedToTerms: Boolean,
    onAgreedToTermsChange: (Boolean) -> Unit
) {
    val annotatedString = buildAnnotatedString {
        append("I agree to the ")
        pushStringAnnotation(tag = "TERMS", annotation = "https://tyrevibes.com")
        withStyle(style = SpanStyle(color = CustomBitterSweet)) {
            append("Terms & Conditions")
        }
        pop()
        append(" and ")
        pushStringAnnotation(tag = "PRIVACY", annotation = "https://tyrevibes.com")
        withStyle(style = SpanStyle(color = CustomBitterSweet)) {
            append("Privacy Policy")
        }
        pop()
    }

    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.padding(top = 13.dp)
    ) {
        Checkbox(
            checked = agreedToTerms,
            onCheckedChange = onAgreedToTermsChange,
            colors = CheckboxDefaults.colors(
                checkedColor = CustomBitterSweet,
                uncheckedColor = Color.Gray
            )
        )
        ClickableText(
            text = annotatedString,
            onClick = { offset ->
                annotatedString.getStringAnnotations(tag = "TERMS", start = offset, end = offset)
                    .firstOrNull()?.let {
                        // Open URL
                    }
                annotatedString.getStringAnnotations(tag = "PRIVACY", start = offset, end = offset)
                    .firstOrNull()?.let {
                        // Open URL
                    }
            },
            style = TextStyle(
                color = Color.White,
                fontSize = 12.sp,
                fontWeight = FontWeight.Normal
            )
        )
    }
}
