package it.tyrevibes.app.features.notifications

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import it.tyrevibes.app.core.model.AppNotification

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotificationsScreen(
    onNavigateBack: () -> Unit = {}
) {
    // TODO: Get from ViewModel
    val notifications = remember {
        listOf(
            AppNotification(
                type = AppNotification.NotificationType.PRESSURE_ALERT,
                title = "Pressione Bassa",
                message = "Pneumatico posteriore sinistro: pressione bassa di 5 PSI",
                timestamp = System.currentTimeMillis() - 7200000, // 2 hours ago
                priority = AppNotification.Priority.HIGH
            ),
            AppNotification(
                type = AppNotification.NotificationType.SEASONAL_REMINDER,
                title = "Cambio Stagionale",
                message = "L'inverno si avvicina. Considera il cambio pneumatici tra 2 settimane",
                timestamp = System.currentTimeMillis() - 86400000, // 1 day ago
                priority = AppNotification.Priority.MEDIUM
            ),
            AppNotification(
                type = AppNotification.NotificationType.MAINTENANCE_REMINDER,
                title = "Manutenzione Programmata",
                message = "Toyota Camry: rotazione pneumatici prevista tra 3 giorni",
                timestamp = System.currentTimeMillis() - 259200000, // 3 days ago
                priority = AppNotification.Priority.MEDIUM,
                isRead = true
            )
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Notifiche") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Indietro")
                    }
                },
                actions = {
                    IconButton(onClick = { /* TODO: Mark all as read */ }) {
                        Icon(Icons.Default.DoneAll, contentDescription = "Segna tutte come lette")
                    }
                }
            )
        }
    ) { paddingValues ->
        if (notifications.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    Icon(
                        Icons.Default.Notifications,
                        contentDescription = null,
                        modifier = Modifier.size(80.dp),
                        tint = MaterialTheme.colorScheme.primary.copy(alpha = 0.5f)
                    )
                    Text(
                        "Nessuna notifica",
                        style = MaterialTheme.typography.titleLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues),
                contentPadding = PaddingValues(vertical = 8.dp)
            ) {
                items(notifications) { notification ->
                    NotificationItem(
                        notification = notification,
                        onClick = { /* TODO: Handle click */ }
                    )
                    HorizontalDivider()
                }
            }
        }
    }
}

@Composable
fun NotificationItem(
    notification: AppNotification,
    onClick: () -> Unit
) {
    Surface(
        onClick = onClick,
        color = if (notification.isRead) {
            MaterialTheme.colorScheme.surface
        } else {
            MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.1f)
        }
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Icon
            Surface(
                shape = MaterialTheme.shapes.medium,
                color = notification.type.getColor().copy(alpha = 0.1f),
                modifier = Modifier.size(48.dp)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        imageVector = when (notification.type) {
                            AppNotification.NotificationType.PRESSURE_ALERT -> Icons.Default.Warning
                            AppNotification.NotificationType.SEASONAL_REMINDER -> Icons.Default.AcUnit
                            AppNotification.NotificationType.MAINTENANCE_REMINDER -> Icons.Default.Build
                            AppNotification.NotificationType.TYRE_REPLACEMENT -> Icons.Default.Autorenew
                            AppNotification.NotificationType.SPECIAL_OFFER -> Icons.Default.LocalOffer
                            else -> Icons.Default.Notifications
                        },
                        contentDescription = null,
                        tint = notification.type.getColor()
                    )
                }
            }

            // Content
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = notification.title,
                        style = MaterialTheme.typography.titleSmall,
                        color = MaterialTheme.colorScheme.onSurface
                    )

                    if (!notification.isRead) {
                        Surface(
                            shape = MaterialTheme.shapes.small,
                            color = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(8.dp)
                        ) {}
                    }
                }

                Text(
                    text = notification.message,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                Text(
                    text = notification.relativeTime,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}
