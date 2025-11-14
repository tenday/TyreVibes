package it.tyrevibes.app.features.garage

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarToday
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.text.SimpleDateFormat
import java.util.*

/**
 * Manutenzione programmata.
 */
data class MaintenanceSchedule(
    val id: String,
    val type: String,                // es: "Cambio Olio", "Revisione", "Tagliando"
    val scheduledDate: Date,
    val description: String,
    val estimatedCost: Double? = null,
    val priority: MaintenancePriority = MaintenancePriority.NORMAL,
    val isCompleted: Boolean = false
)

enum class MaintenancePriority(val color: Color) {
    LOW(Color.Gray),
    NORMAL(Color(0xFF0066FF)),
    HIGH(Color(0xFFFFA500)),
    URGENT(Color(0xFFFF6B6B))
}

/**
 * Vista manutenzioni programmate.
 *
 * Features:
 * - Lista manutenzioni ordinate per data
 * - Card espandibili con dettagli
 * - Indicatore priorità con colori
 * - Badge conteggio manutenzioni
 * - Empty state se nessuna manutenzione
 */
@Composable
fun UpcomingMaintenanceView(
    maintenances: List<MaintenanceSchedule>
) {
    var expandedId by remember { mutableStateOf<String?>(null) }

    val sortedMaintenances = remember(maintenances) {
        maintenances.sortedBy { it.scheduledDate }
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                color = Color(0xFF2C2C2E),
                shape = RoundedCornerShape(14.dp)
            )
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.CalendarToday,
                    contentDescription = "Calendar",
                    tint = Color(0xFF0066FF),
                    modifier = Modifier.size(18.dp)
                )
                Text(
                    text = "Upcoming Maintenance",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White
                )
            }

            if (maintenances.isNotEmpty()) {
                Box(
                    modifier = Modifier
                        .background(
                            color = Color(0xFF0066FF),
                            shape = CircleShape
                        )
                        .padding(6.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = maintenances.size.toString(),
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                }
            }
        }

        // Content
        if (maintenances.isEmpty()) {
            // Empty state
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Check,
                    contentDescription = "All caught up",
                    tint = Color.Green,
                    modifier = Modifier.size(40.dp)
                )
                Text(
                    text = "All caught up!",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Medium,
                    color = Color.White
                )
                Text(
                    text = "No upcoming maintenance scheduled",
                    fontSize = 14.sp,
                    color = Color.Gray
                )
            }
        } else {
            // Maintenance list
            Column(
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                sortedMaintenances.forEach { maintenance ->
                    MaintenanceCard(
                        maintenance = maintenance,
                        isExpanded = expandedId == maintenance.id,
                        onToggleExpand = {
                            expandedId = if (expandedId == maintenance.id) null else maintenance.id
                        }
                    )
                }
            }
        }
    }
}

@Composable
fun MaintenanceCard(
    maintenance: MaintenanceSchedule,
    isExpanded: Boolean,
    onToggleExpand: () -> Unit
) {
    val dateFormatter = remember { SimpleDateFormat("dd MMM yyyy", Locale.getDefault()) }

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onToggleExpand),
        colors = CardDefaults.cardColors(
            containerColor = Color(0xFF1C1C1E)
        ),
        shape = RoundedCornerShape(12.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    // Priority indicator
                    Box(
                        modifier = Modifier
                            .background(
                                color = maintenance.priority.color.copy(alpha = 0.2f),
                                shape = RoundedCornerShape(6.dp)
                            )
                            .padding(horizontal = 8.dp, vertical = 4.dp)
                    ) {
                        Text(
                            text = maintenance.priority.name,
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold,
                            color = maintenance.priority.color
                        )
                    }

                    Spacer(modifier = Modifier.height(8.dp))

                    Text(
                        text = maintenance.type,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )

                    Text(
                        text = dateFormatter.format(maintenance.scheduledDate),
                        fontSize = 14.sp,
                        color = Color.Gray
                    )
                }

                Icon(
                    imageVector = if (isExpanded) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
                    contentDescription = if (isExpanded) "Collapse" else "Expand",
                    tint = Color.White
                )
            }

            // Expanded content
            AnimatedVisibility(
                visible = isExpanded,
                enter = expandVertically(),
                exit = shrinkVertically()
            ) {
                Column(
                    modifier = Modifier.padding(top = 12.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Divider(color = Color.Gray.copy(alpha = 0.3f))

                    Text(
                        text = maintenance.description,
                        fontSize = 14.sp,
                        color = Color.Gray
                    )

                    maintenance.estimatedCost?.let { cost ->
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text(
                                text = "Estimated Cost:",
                                fontSize = 14.sp,
                                color = Color.Gray
                            )
                            Text(
                                text = "€ ${String.format("%.2f", cost)}",
                                fontSize = 14.sp,
                                fontWeight = FontWeight.Bold,
                                color = Color.White
                            )
                        }
                    }

                    // Mark as complete button (TODO: implement action)
                    if (!maintenance.isCompleted) {
                        Button(
                            onClick = { /* TODO: Mark as completed */ },
                            modifier = Modifier.fillMaxWidth(),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = Color(0xFF0066FF)
                            ),
                            shape = RoundedCornerShape(8.dp)
                        ) {
                            Text("Mark as Completed")
                        }
                    }
                }
            }
        }
    }
}
