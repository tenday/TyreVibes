package it.tyrevibes.app.features.settings

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Dati statistiche app.
 */
data class AppStats(
    val appSize: String = "45.2 MB",
    val cacheSize: String = "12.8 MB"
)

/**
 * Sheet protezione dati e privacy (GDPR compliance).
 *
 * Features:
 * - Visualizzazione dati personali (biometria, lingua, livello privacy)
 * - Activity & Diagnostics (sync in background, analytics)
 * - Storage info (dimensioni app, cache)
 * - Azioni: Export dati, Richiesta cancellazione dati
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DataProtectionSheet(
    biometricAuth: Boolean,
    selectedLanguage: String,
    privacyLevel: String,
    backgroundSync: Boolean,
    stats: AppStats,
    onExportData: () -> Unit,
    onRequestDeletion: () -> Unit,
    onDismiss: () -> Unit
) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = Color(0xFF1C1C1E),
        contentColor = Color.White
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
                .padding(bottom = 40.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            // Header
            Text(
                text = "Data Protection",
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )

            // Personal Data Section
            SectionTitle("Personal Data")
            DataRow("Biometrics", if (biometricAuth) "Enabled" else "Disabled")
            DataRow("Language", selectedLanguage)
            DataRow("Privacy Level", privacyLevel)

            Divider(color = Color.Gray.copy(alpha = 0.3f))

            // Activity & Diagnostics Section
            SectionTitle("Activity & Diagnostics")
            DataRow("Background Sync", if (backgroundSync) "Active" else "Inactive")
            DataRow(
                "Analytics",
                if (privacyLevel == "Strict") "Disabled" else "Enabled"
            )

            Divider(color = Color.Gray.copy(alpha = 0.3f))

            // Storage Section
            SectionTitle("Storage")
            DataRow("App Size", stats.appSize)
            DataRow("Cache Size", stats.cacheSize)

            Divider(color = Color.Gray.copy(alpha = 0.3f))

            // Actions Section
            SectionTitle("Actions")

            // Export data button
            Button(
                onClick = {
                    onExportData()
                    onDismiss()
                },
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color(0xFF0066FF)
                ),
                shape = RoundedCornerShape(14.dp)
            ) {
                Text(
                    text = "Export my data",
                    modifier = Modifier.padding(vertical = 12.dp)
                )
            }

            // Request deletion button
            Button(
                onClick = {
                    onRequestDeletion()
                    onDismiss()
                },
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color.Red
                ),
                shape = RoundedCornerShape(14.dp)
            ) {
                Text(
                    text = "Request data deletion",
                    modifier = Modifier.padding(vertical = 12.dp)
                )
            }

            // Close button
            TextButton(
                onClick = onDismiss,
                modifier = Modifier.align(Alignment.CenterHorizontally)
            ) {
                Text("Done", color = Color.White, fontSize = 16.sp)
            }
        }
    }
}

@Composable
private fun SectionTitle(title: String) {
    Text(
        text = title,
        fontSize = 14.sp,
        fontWeight = FontWeight.SemiBold,
        color = Color.Gray
    )
}

@Composable
private fun DataRow(title: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = title,
            fontSize = 16.sp,
            color = Color.White
        )
        Text(
            text = value,
            fontSize = 16.sp,
            color = Color.Gray
        )
    }
}
