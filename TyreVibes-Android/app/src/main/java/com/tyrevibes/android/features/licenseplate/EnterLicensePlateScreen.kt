package com.tyrevibes.android.features.licenseplate

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.platform.LocalContext
import com.tyrevibes.android.ui.theme.CustomBackgroundColor
import com.tyrevibes.android.ui.theme.CustomBitterSweet

@Composable
fun EnterLicensePlateScreen(
    viewModel: PlateViewModel,
    onNavigateToDetails: () -> Unit,
    onDismiss: () -> Unit,
) {
    val plateInput by viewModel.plateInput.collectAsStateWithLifecycle() // Assuming you add this to ViewModel
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val isContinueEnabled = plateInput.length >= 5
    val context = LocalContext.current

    LaunchedEffect(uiState) {
        when (uiState) {
            is PlateUiState.Success -> onNavigateToDetails()
            is PlateUiState.Error -> {
                Toast.makeText(context, (uiState as PlateUiState.Error).message, Toast.LENGTH_LONG).show()
                viewModel.resetState()
            }
            else -> {}
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(CustomBackgroundColor)
            .padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("Enter License Plate", fontSize = 24.sp, fontWeight = FontWeight.SemiBold, color = Color.White)
            IconButton(onClick = onDismiss) {
                Icon(Icons.Default.Close, contentDescription = "Close", tint = Color.White)
            }
        }

        Spacer(modifier = Modifier.weight(1f))

        // Plate Text Field
        LicensePlateTextField(
            value = plateInput,
            onValueChange = viewModel::onPlateInputChange
        )

        Spacer(modifier = Modifier.weight(1f))

        // Continue Button
        Button(
            onClick = { viewModel.checkPlate(plateInput) },
            modifier = Modifier
                .fillMaxWidth()
                .height(62.dp),
            shape = RoundedCornerShape(100),
            colors = ButtonDefaults.buttonColors(containerColor = CustomBitterSweet),
            enabled = isContinueEnabled
        ) {
            Text(
                text = "Continue",
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
        }
    }
}

@Composable
fun LicensePlateTextField(
    value: String,
    onValueChange: (String) -> Unit
) {
    BasicTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = Modifier
            .width(280.dp)
            .height(80.dp),
        decorationBox = {
            Row(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.White, RoundedCornerShape(12.dp))
                    .border(2.dp, Color.Black, RoundedCornerShape(12.dp)),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Blue EU part
                Box(
                    modifier = Modifier
                        .fillMaxHeight()
                        .width(40.dp)
                        .background(
                            Color(0xFF003399),
                            RoundedCornerShape(topStart = 12.dp, bottomStart = 12.dp)
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Text("I", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 24.sp)
                }

                // Plate text
                Text(
                    text = value,
                    modifier = Modifier
                        .weight(1f)
                        .padding(horizontal = 8.dp),
                    textAlign = TextAlign.Center,
                    fontSize = 32.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 6.sp,
                    color = Color.Black
                )
            }
        }
    )
}
