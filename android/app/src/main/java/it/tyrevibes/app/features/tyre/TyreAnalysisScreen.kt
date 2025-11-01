package it.tyrevibes.app.features.tyre

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import it.tyrevibes.app.ui.components.TyreButton

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TyreAnalysisScreen(
    onNavigateBack: () -> Unit = {},
    onStartAnalysis: () -> Unit = {}
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Analisi Pneumatici") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
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
            verticalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            // Header
            Icon(
                Icons.Default.CameraAlt,
                contentDescription = null,
                modifier = Modifier.size(80.dp),
                tint = MaterialTheme.colorScheme.primary
            )

            Text(
                text = "Analisi Profondità Battistrada",
                style = MaterialTheme.typography.headlineSmall
            )

            Text(
                text = "Scatta una foto del battistrada del pneumatico per analizzarne lo stato",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            // Instructions
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Text(
                        "Istruzioni:",
                        style = MaterialTheme.typography.titleMedium
                    )

                    InstructionItem(
                        icon = Icons.Default.WbSunny,
                        text = "Assicurati di avere una buona illuminazione"
                    )

                    InstructionItem(
                        icon = Icons.Default.CameraAlt,
                        text = "Inquadra il battistrada da vicino"
                    )

                    InstructionItem(
                        icon = Icons.Default.ZoomIn,
                        text = "Mantieni la fotocamera parallela al pneumatico"
                    )

                    InstructionItem(
                        icon = Icons.Default.Clean,
                        text = "Pulisci il battistrada prima dell'analisi"
                    )
                }
            }

            // Features
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Text(
                        "Cosa analizziamo:",
                        style = MaterialTheme.typography.titleMedium
                    )

                    FeatureItem(
                        icon = Icons.Default.Height,
                        title = "Profondità Battistrada",
                        description = "Misurazione precisa della profondità"
                    )

                    FeatureItem(
                        icon = Icons.Default.Report,
                        title = "Pattern di Usura",
                        description = "Identificazione di usure anomale"
                    )

                    FeatureItem(
                        icon = Icons.Default.Timeline,
                        title = "Vita Residua",
                        description = "Stima dei km rimanenti"
                    )

                    FeatureItem(
                        icon = Icons.Default.Warning,
                        title = "Raccomandazioni",
                        description = "Consigli per la manutenzione"
                    )
                }
            }

            Spacer(modifier = Modifier.weight(1f))

            // Start Analysis Button
            TyreButton(
                text = "Inizia Analisi",
                onClick = onStartAnalysis
            )
        }
    }
}

@Composable
fun InstructionItem(icon: androidx.compose.ui.graphics.vector.ImageVector, text: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Icon(
            icon,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary
        )
        Text(text, style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
fun FeatureItem(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    description: String
) {
    Row(
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Icon(
            icon,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.padding(top = 2.dp)
        )
        Column {
            Text(title, style = MaterialTheme.typography.titleSmall)
            Text(
                description,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}
