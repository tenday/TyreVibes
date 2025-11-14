package it.tyrevibes.app.features.address

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay

/**
 * Suggerimento indirizzo.
 */
data class AddressSuggestion(
    val id: String,
    val street: String,
    val city: String,
    val province: String,
    val zipcode: String
)

/**
 * Vista ricerca indirizzi.
 *
 * Features:
 * - Campo ricerca con debounce
 * - Lista suggerimenti indirizzi (via, città, provincia, CAP)
 * - Loading state durante ricerca
 * - Error handling
 * - Selezione indirizzo con callback
 *
 * TODO: Integrazione API geocoding (Google Maps, OpenStreetMap, etc.)
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddressSearchView(
    onAddressSelected: (AddressSuggestion) -> Unit,
    onDismiss: () -> Unit
) {
    var searchText by remember { mutableStateOf("") }
    var isLoading by remember { mutableStateOf(false) }
    var suggestions by remember { mutableStateOf<List<AddressSuggestion>>(emptyList()) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    // Simulated search with debounce
    LaunchedEffect(searchText) {
        if (searchText.length >= 3) {
            isLoading = true
            errorMessage = null
            delay(500) // Debounce

            // TODO: Replace with real API call
            suggestions = mockSearchAddresses(searchText)
            isLoading = false
        } else {
            suggestions = emptyList()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Address Search",
                        fontSize = 18.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color(0xFF1C1C1E)
                )
            )
        },
        containerColor = Color(0xFF000000)
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(16.dp)
        ) {
            // Search field
            OutlinedTextField(
                value = searchText,
                onValueChange = { searchText = it },
                modifier = Modifier.fillMaxWidth(),
                placeholder = {
                    Text("Search for an address...", color = Color.Gray)
                },
                leadingIcon = {
                    Icon(
                        imageVector = Icons.Default.Search,
                        contentDescription = "Search",
                        tint = Color.Gray
                    )
                },
                singleLine = true,
                shape = RoundedCornerShape(14.dp),
                colors = TextFieldDefaults.outlinedTextFieldColors(
                    focusedTextColor = Color.White,
                    unfocusedTextColor = Color.White,
                    focusedBorderColor = Color(0xFFFF6B6B),
                    unfocusedBorderColor = Color.Gray,
                    containerColor = Color(0xFF2C2C2E)
                )
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Content
            when {
                isLoading -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator(color = Color(0xFFFF6B6B))
                    }
                }
                errorMessage != null -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "Error: $errorMessage",
                            color = Color.Red,
                            fontSize = 14.sp
                        )
                    }
                }
                suggestions.isEmpty() && searchText.isNotEmpty() -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "No results found",
                            color = Color.Gray,
                            fontSize = 14.sp
                        )
                    }
                }
                suggestions.isNotEmpty() -> {
                    LazyColumn(
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        items(suggestions) { suggestion ->
                            AddressSuggestionCard(
                                suggestion = suggestion,
                                onClick = {
                                    onAddressSelected(suggestion)
                                    onDismiss()
                                }
                            )
                        }
                    }
                }
                else -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "Enter at least 3 characters to search",
                            color = Color.Gray,
                            fontSize = 14.sp
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun AddressSuggestionCard(
    suggestion: AddressSuggestion,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        colors = CardDefaults.cardColors(
            containerColor = Color(0xFF2C2C2E)
        ),
        shape = RoundedCornerShape(14.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Text(
                text = suggestion.street,
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.White
            )
            Text(
                text = "${suggestion.city}, ${suggestion.province} ${suggestion.zipcode}",
                fontSize = 14.sp,
                color = Color.Gray
            )
        }
    }
}

/**
 * Mock search function.
 * TODO: Replace with real geocoding API.
 */
private fun mockSearchAddresses(query: String): List<AddressSuggestion> {
    return listOf(
        AddressSuggestion(
            id = "1",
            street = "Via Roma 123",
            city = "Milano",
            province = "MI",
            zipcode = "20121"
        ),
        AddressSuggestion(
            id = "2",
            street = "Corso Buenos Aires 45",
            city = "Milano",
            province = "MI",
            zipcode = "20124"
        ),
        AddressSuggestion(
            id = "3",
            street = "Via Torino 89",
            city = "Milano",
            province = "MI",
            zipcode = "20123"
        )
    )
}
