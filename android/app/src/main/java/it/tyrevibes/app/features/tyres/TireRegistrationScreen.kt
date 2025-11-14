package it.tyrevibes.app.features.tyres

import android.graphics.Bitmap
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.FlashlightOn
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import kotlinx.coroutines.launch

/**
 * Dati pneumatico estratti da OCR.
 */
data class TireData(
    var brand: String = "",
    var model: String = "",
    var size: String = "",
    var dot: String = "",
    var loadIndex: String = "",
    var speedRating: String = "",
    var season: String = "",
    var allText: List<String> = emptyList(),
    var vehicleId: Int = 0
)

/**
 * Schermata registrazione pneumatico con OCR.
 *
 * Features:
 * - Camera preview con CameraX
 * - OCR text recognition (ML Kit)
 * - Estrazione automatica: marca, modello, misura, DOT, indici
 * - Flash toggle
 * - Guida visiva per inquadrare il pneumatico
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TireRegistrationScreen(
    vehicleId: Int,
    onNavigateBack: () -> Unit,
    onTireDetected: (TireData) -> Unit
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val coroutineScope = rememberCoroutineScope()

    var flashEnabled by remember { mutableStateOf(false) }
    var isProcessing by remember { mutableStateOf(false) }
    var extractedData by remember { mutableStateOf(TireData(vehicleId = vehicleId)) }
    var tireDetected by remember { mutableStateOf(false) }

    val imageCapture = remember { ImageCapture.Builder().build() }
    val cameraProvider = remember { mutableStateOf<ProcessCameraProvider?>(null) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Scan Tire",
                        fontSize = 18.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(
                            imageVector = Icons.Default.ArrowBack,
                            contentDescription = "Back",
                            tint = Color.White
                        )
                    }
                },
                actions = {
                    IconButton(onClick = { flashEnabled = !flashEnabled }) {
                        Icon(
                            imageVector = Icons.Default.FlashlightOn,
                            contentDescription = "Flash",
                            tint = if (flashEnabled) Color.Yellow else Color.White
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color(0xFF1C1C1E)
                )
            )
        },
        containerColor = Color.Black
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            // Camera Preview
            AndroidView(
                factory = { ctx ->
                    PreviewView(ctx).apply {
                        val cameraProviderFuture = ProcessCameraProvider.getInstance(ctx)
                        cameraProviderFuture.addListener({
                            val provider = cameraProviderFuture.get()
                            cameraProvider.value = provider

                            val preview = Preview.Builder().build().also {
                                it.setSurfaceProvider(surfaceProvider)
                            }

                            val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA

                            try {
                                provider.unbindAll()
                                provider.bindToLifecycle(
                                    lifecycleOwner,
                                    cameraSelector,
                                    preview,
                                    imageCapture
                                )
                            } catch (e: Exception) {
                                e.printStackTrace()
                            }
                        }, ContextCompat.getMainExecutor(ctx))
                    }
                },
                modifier = Modifier.fillMaxSize()
            )

            // Guide overlay
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(40.dp),
                contentAlignment = Alignment.Center
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(200.dp)
                        .background(
                            color = Color.White.copy(alpha = 0.1f),
                            shape = RoundedCornerShape(16.dp)
                        )
                ) {
                    Text(
                        text = "Align tire within frame",
                        color = Color.White,
                        fontSize = 14.sp,
                        modifier = Modifier
                            .align(Alignment.TopCenter)
                            .padding(top = 16.dp)
                    )
                }
            }

            // Capture button
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(bottom = 40.dp),
                contentAlignment = Alignment.BottomCenter
            ) {
                FloatingActionButton(
                    onClick = {
                        if (!isProcessing) {
                            coroutineScope.launch {
                                isProcessing = true
                                // TODO: Capture image and run OCR with ML Kit
                                // captureAndProcessTire(imageCapture) { tireData ->
                                //     extractedData = tireData
                                //     tireDetected = true
                                //     onTireDetected(tireData)
                                // }
                                isProcessing = false
                            }
                        }
                    },
                    containerColor = Color(0xFFFF6B6B),
                    shape = CircleShape,
                    modifier = Modifier.size(72.dp)
                ) {
                    if (isProcessing) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(32.dp),
                            color = Color.White
                        )
                    } else {
                        Icon(
                            imageVector = Icons.Default.CameraAlt,
                            contentDescription = "Capture",
                            tint = Color.White,
                            modifier = Modifier.size(32.dp)
                        )
                    }
                }
            }

            // Processing overlay
            if (isProcessing) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(Color.Black.copy(alpha = 0.7f)),
                    contentAlignment = Alignment.Center
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        CircularProgressIndicator(color = Color.White)
                        Text(
                            text = "Analyzing tire...",
                            color = Color.White,
                            fontSize = 16.sp
                        )
                    }
                }
            }

            // Detected data preview (bottom sheet)
            if (tireDetected) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .align(Alignment.BottomCenter)
                        .background(
                            color = Color(0xFF2C2C2E),
                            shape = RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp)
                        )
                        .padding(20.dp)
                ) {
                    Text(
                        text = "Tire Detected!",
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(text = "Brand: ${extractedData.brand}", color = Color.White)
                    Text(text = "Model: ${extractedData.model}", color = Color.White)
                    Text(text = "Size: ${extractedData.size}", color = Color.White)
                    Text(text = "DOT: ${extractedData.dot}", color = Color.White)

                    Spacer(modifier = Modifier.height(16.dp))

                    Button(
                        onClick = { onTireDetected(extractedData) },
                        modifier = Modifier.fillMaxWidth(),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = Color(0xFFFF6B6B)
                        )
                    ) {
                        Text("Confirm & Save")
                    }
                }
            }
        }
    }
}

/**
 * TODO: Implementare cattura e OCR con ML Kit Text Recognition.
 *
 * private suspend fun captureAndProcessTire(
 *     imageCapture: ImageCapture,
 *     onResult: (TireData) -> Unit
 * ) {
 *     imageCapture.takePicture(...)
 *     // Converti ImageProxy in Bitmap
 *     // Esegui ML Kit Text Recognition
 *     // Estrai marca, modello, misura, DOT usando regex e known brands
 *     // Ritorna TireData
 * }
 */
