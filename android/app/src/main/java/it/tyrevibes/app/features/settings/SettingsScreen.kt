package it.tyrevibes.app.features.settings

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import it.tyrevibes.app.core.viewmodel.SettingsViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    viewModel: SettingsViewModel = SettingsViewModel(LocalContext.current),
    onNavigateBack: () -> Unit = {},
    onNavigateToProfile: () -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Impostazioni") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Indietro")
                    }
                }
            )
        }
    ) { paddingValues ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues),
            contentPadding = PaddingValues(vertical = 8.dp)
        ) {
            // Profile Section
            item {
                SettingsSection(title = "Account")
            }

            item {
                SettingsItem(
                    icon = Icons.Default.Person,
                    title = "Profilo",
                    subtitle = "Gestisci il tuo profilo",
                    onClick = onNavigateToProfile
                )
            }

            // Notifications
            item {
                SettingsSection(title = "Notifiche")
            }

            item {
                SettingsSwitchItem(
                    icon = Icons.Default.Notifications,
                    title = "Notifiche Push",
                    subtitle = "Ricevi notifiche importanti",
                    checked = uiState.notificationsEnabled,
                    onCheckedChange = viewModel::toggleNotifications
                )
            }

            // Security
            item {
                SettingsSection(title = "Sicurezza")
            }

            item {
                SettingsSwitchItem(
                    icon = Icons.Default.Fingerprint,
                    title = "Autenticazione Biometrica",
                    subtitle = "Usa impronta digitale o Face ID",
                    checked = uiState.biometricEnabled,
                    onCheckedChange = viewModel::toggleBiometric
                )
            }

            // Appearance
            item {
                SettingsSection(title = "Aspetto")
            }

            item {
                SettingsSwitchItem(
                    icon = Icons.Default.DarkMode,
                    title = "Modalità Scura",
                    subtitle = "Tema scuro per l'app",
                    checked = uiState.darkModeEnabled,
                    onCheckedChange = viewModel::toggleDarkMode
                )
            }

            // Logout
            item {
                SettingsSection(title = "Account")
            }

            item {
                SettingsItem(
                    icon = Icons.Default.Logout,
                    title = "Esci",
                    subtitle = "Disconnettiti dall'app",
                    onClick = viewModel::showLogoutConfirmation,
                    isDestructive = true
                )
            }

            item {
                SettingsItem(
                    icon = Icons.Default.DeleteForever,
                    title = "Elimina Account",
                    subtitle = "Elimina permanentemente il tuo account",
                    onClick = viewModel::showDeleteAccountConfirmation,
                    isDestructive = true
                )
            }
        }

        // Logout Confirmation Dialog
        if (uiState.showLogoutConfirmation) {
            AlertDialog(
                onDismissRequest = viewModel::hideLogoutConfirmation,
                title = { Text("Conferma Logout") },
                text = { Text("Sei sicuro di voler uscire?") },
                confirmButton = {
                    TextButton(onClick = { viewModel.logout() }) {
                        Text("Esci")
                    }
                },
                dismissButton = {
                    TextButton(onClick = viewModel::hideLogoutConfirmation) {
                        Text("Annulla")
                    }
                }
            )
        }

        // Delete Account Confirmation Dialog
        if (uiState.showDeleteConfirmation) {
            AlertDialog(
                onDismissRequest = viewModel::hideDeleteAccountConfirmation,
                title = { Text("Elimina Account") },
                text = { Text("Sei sicuro di voler eliminare il tuo account? Questa azione è irreversibile.") },
                confirmButton = {
                    TextButton(onClick = { viewModel.deleteAccount() }) {
                        Text("Elimina", color = MaterialTheme.colorScheme.error)
                    }
                },
                dismissButton = {
                    TextButton(onClick = viewModel::hideDeleteAccountConfirmation) {
                        Text("Annulla")
                    }
                }
            )
        }
    }
}

@Composable
fun SettingsSection(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.titleSmall,
        color = MaterialTheme.colorScheme.primary,
        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
    )
}

@Composable
fun SettingsItem(
    icon: ImageVector,
    title: String,
    subtitle: String,
    onClick: () -> Unit,
    isDestructive: Boolean = false
) {
    Surface(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = if (isDestructive) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary
            )

            Spacer(modifier = Modifier.width(16.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.bodyLarge,
                    color = if (isDestructive) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface
                )
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            Icon(
                imageVector = Icons.Default.ChevronRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
fun SettingsSwitchItem(
    icon: ImageVector,
    title: String,
    subtitle: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    Surface(
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary
            )

            Spacer(modifier = Modifier.width(16.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.bodyLarge
                )
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            Switch(
                checked = checked,
                onCheckedChange = onCheckedChange
            )
        }
    }
}
