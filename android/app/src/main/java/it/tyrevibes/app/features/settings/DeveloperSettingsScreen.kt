package it.tyrevibes.app.features.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Code
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import it.tyrevibes.app.core.service.FeatureFlags

/**
 * Schermata impostazioni sviluppatore con feature flags.
 *
 * Features:
 * - Toggle feature flags (Paywall, Notifications, Cloud Sync, Analytics, Debug)
 * - Reset to defaults
 * - Clean, developer-focused UI
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DeveloperSettingsScreen(
    featureFlags: FeatureFlags,
    onDismiss: () -> Unit
) {
    var paywallEnabled by remember { mutableStateOf(false) }
    var notificationsEnabled by remember { mutableStateOf(false) }
    var cloudSyncEnabled by remember { mutableStateOf(false) }
    var analyticsEnabled by remember { mutableStateOf(false) }
    var debugModeEnabled by remember { mutableStateOf(false) }

    // Load initial values
    LaunchedEffect(Unit) {
        featureFlags.isPaywallEnabled.collect { paywallEnabled = it }
    }
    LaunchedEffect(Unit) {
        featureFlags.isNotificationsEnabled.collect { notificationsEnabled = it }
    }
    LaunchedEffect(Unit) {
        featureFlags.isCloudSyncEnabled.collect { cloudSyncEnabled = it }
    }
    LaunchedEffect(Unit) {
        featureFlags.isAnalyticsEnabled.collect { analyticsEnabled = it }
    }
    LaunchedEffect(Unit) {
        featureFlags.isDebugModeEnabled.collect { debugModeEnabled = it }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {},
                navigationIcon = {
                    IconButton(onClick = onDismiss) {
                        Icon(
                            imageVector = Icons.Default.Close,
                            contentDescription = "Close",
                            tint = Color.White,
                            modifier = Modifier
                                .background(
                                    color = Color.White.copy(alpha = 0.1f),
                                    shape = CircleShape
                                )
                                .padding(8.dp)
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color(0xFF1C1C1E)
                )
            )
        },
        containerColor = Color(0xFF1C1C1E)
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            // Header
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Code,
                    contentDescription = "Developer",
                    tint = Color.Cyan,
                    modifier = Modifier.size(60.dp)
                )
                Text(
                    text = "Developer Settings",
                    fontSize = 28.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
                Text(
                    text = "Configure feature flags",
                    fontSize = 14.sp,
                    color = Color.White.copy(alpha = 0.7f)
                )
            }

            // Feature Flags Section
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = Color(0xFF2C2C2E)
                ),
                shape = RoundedCornerShape(14.dp)
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    Text(
                        text = "Feature Flags",
                        fontSize = 18.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )

                    FeatureFlagToggle(
                        title = "Paywall",
                        description = "Enable premium paywall screens",
                        checked = paywallEnabled,
                        onCheckedChange = {
                            paywallEnabled = it
                            // TODO: featureFlags.setPaywallEnabled(it)
                        }
                    )

                    FeatureFlagToggle(
                        title = "Push Notifications",
                        description = "Enable push notification system",
                        checked = notificationsEnabled,
                        onCheckedChange = {
                            notificationsEnabled = it
                            // TODO: featureFlags.setNotificationsEnabled(it)
                        }
                    )

                    FeatureFlagToggle(
                        title = "Cloud Sync",
                        description = "Sync data across devices",
                        checked = cloudSyncEnabled,
                        onCheckedChange = {
                            cloudSyncEnabled = it
                            // TODO: featureFlags.setCloudSyncEnabled(it)
                        }
                    )

                    FeatureFlagToggle(
                        title = "Analytics",
                        description = "Collect usage analytics",
                        checked = analyticsEnabled,
                        onCheckedChange = {
                            analyticsEnabled = it
                            // TODO: featureFlags.setAnalyticsEnabled(it)
                        }
                    )

                    FeatureFlagToggle(
                        title = "Debug Mode",
                        description = "Show debug information",
                        checked = debugModeEnabled,
                        onCheckedChange = {
                            debugModeEnabled = it
                            // TODO: featureFlags.setDebugModeEnabled(it)
                        }
                    )
                }
            }

            // Actions Section
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = Color(0xFF2C2C2E)
                ),
                shape = RoundedCornerShape(14.dp)
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Text(
                        text = "Actions",
                        fontSize = 18.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )

                    Button(
                        onClick = {
                            // Reset all flags to defaults
                            paywallEnabled = true
                            notificationsEnabled = true
                            cloudSyncEnabled = false
                            analyticsEnabled = true
                            debugModeEnabled = false
                            // TODO: featureFlags.resetToDefaults()
                        },
                        modifier = Modifier.fillMaxWidth(),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = Color(0xFF0066FF)
                        ),
                        shape = RoundedCornerShape(10.dp)
                    ) {
                        Text(
                            text = "Reset to Defaults",
                            modifier = Modifier.padding(vertical = 8.dp)
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(20.dp))
        }
    }
}

@Composable
private fun FeatureFlagToggle(
    title: String,
    description: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                fontSize = 16.sp,
                fontWeight = FontWeight.Medium,
                color = Color.White
            )
            Text(
                text = description,
                fontSize = 14.sp,
                color = Color.Gray
            )
        }

        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = Color.Cyan,
                uncheckedThumbColor = Color.Gray,
                uncheckedTrackColor = Color.DarkGray
            )
        )
    }
}
