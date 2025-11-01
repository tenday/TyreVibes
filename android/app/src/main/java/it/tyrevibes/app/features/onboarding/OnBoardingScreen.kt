package it.tyrevibes.app.features.onboarding

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import it.tyrevibes.app.ui.components.TyreButton
import kotlinx.coroutines.launch

data class OnBoardingPage(
    val title: String,
    val description: String,
    val icon: ImageVector
)

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun OnBoardingScreen(
    onNavigateToLogin: () -> Unit = {}
) {
    val pages = listOf(
        OnBoardingPage(
            title = "Gestisci i tuoi Pneumatici",
            description = "Monitora lo stato dei tuoi pneumatici e ricevi promemoria per la manutenzione",
            icon = Icons.Default.Tire
        ),
        OnBoardingPage(
            title = "Analisi Avanzata",
            description = "Scansiona e analizza la profondità del battistrada con la fotocamera",
            icon = Icons.Default.CameraAlt
        ),
        OnBoardingPage(
            title = "Trova Officine",
            description = "Trova le officine più vicine e confronta i prezzi dei pneumatici",
            icon = Icons.Default.LocationOn
        ),
        OnBoardingPage(
            title = "Sicurezza Prima di Tutto",
            description = "Ricevi avvisi quando è il momento di cambiare i pneumatici",
            icon = Icons.Default.Security
        )
    )

    val pagerState = rememberPagerState(pageCount = { pages.size })
    val scope = rememberCoroutineScope()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Pager
        HorizontalPager(
            state = pagerState,
            modifier = Modifier.weight(1f)
        ) { page ->
            OnBoardingPageContent(pages[page])
        }

        // Page Indicator
        Row(
            modifier = Modifier.padding(vertical = 24.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            repeat(pages.size) { index ->
                val isSelected = pagerState.currentPage == index
                Box(
                    modifier = Modifier
                        .size(if (isSelected) 12.dp else 8.dp)
                        .padding(2.dp)
                ) {
                    Surface(
                        shape = MaterialTheme.shapes.small,
                        color = if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.3f),
                        modifier = Modifier.fillMaxSize()
                    ) {}
                }
            }
        }

        // Buttons
        if (pagerState.currentPage == pages.size - 1) {
            TyreButton(
                text = "Inizia",
                onClick = onNavigateToLogin
            )
        } else {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                TextButton(onClick = onNavigateToLogin) {
                    Text("Salta")
                }

                Button(
                    onClick = {
                        scope.launch {
                            pagerState.animateScrollToPage(pagerState.currentPage + 1)
                        }
                    }
                ) {
                    Text("Avanti")
                }
            }
        }
    }
}

@Composable
fun OnBoardingPageContent(page: OnBoardingPage) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = page.icon,
            contentDescription = null,
            modifier = Modifier.size(120.dp),
            tint = MaterialTheme.colorScheme.primary
        )

        Spacer(modifier = Modifier.height(32.dp))

        Text(
            text = page.title,
            style = MaterialTheme.typography.headlineMedium,
            textAlign = TextAlign.Center,
            color = MaterialTheme.colorScheme.onSurface
        )

        Spacer(modifier = Modifier.height(16.dp))

        Text(
            text = page.description,
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

// Placeholder icon for Tire (not available in default Material icons)
private val Icons.Default.Tire: ImageVector
    get() = Icons.Default.Settings
