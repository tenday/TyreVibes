package it.tyrevibes.app.features.licenseplate

import android.graphics.Bitmap
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import it.tyrevibes.app.ui.components.TyreButton
import kotlinx.coroutines.launch
import java.util.concurrent.Executors

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LicensePlateScannerScreen(
    onNavigateBack: () -> Unit = {},
    onPlateDetected: (String) -> Unit = {}
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val scope = rememberCoroutineScope()

    var isScanning by remember { mutableStateOf(false) }
    var detectedPlate by remember { mutableStateOf<String?>(null) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    val ocrManager = remember { LicensePlateOCRManager(context) }
    val cameraExecutor = remember { Executors.newSingleThreadExecutor() }

    val previewView = remember { PreviewView(context) }
    val imageCapture = remember { ImageCapture.Builder().build() }

    LaunchedEffect(Unit) {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        val cameraProvider = cameraProviderFuture.get()

        val preview = Preview.Builder().build().also {
            it.setSurfaceProvider(previewView.surfaceProvider)
        }

        val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA

        try {
            cameraProvider.unbindAll()
            cameraProvider.bindToLifecycle(
                lifecycleOwner,
                cameraSelector,
                preview,
                imageCapture
            )
        } catch (e: Exception) {
            errorMessage = "Errore inizializzazione camera: ${e.message}"
        }
    }

    DisposableEffect(Unit) {
        onDispose {
            ocrManager.release()
            cameraExecutor.shutdown()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Scansiona Targa") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Indietro")
                    }
                }
            )
        }
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            // Camera Preview
            AndroidView(
                factory = { previewView },
                modifier = Modifier.fillMaxSize()
            )

            // Overlay UI
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(24.dp),
                verticalArrangement = Arrangement.SpaceBetween,
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                // Instructions
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.9f)
                    )
                ) {
                    Text(
                        text = "Inquadra la targa del veicolo",
                        style = MaterialTheme.typography.bodyLarge,
                        modifier = Modifier.padding(16.dp)
                    )
                }

                Spacer(modifier = Modifier.weight(1f))

                // Detected Plate Display
                detectedPlate?.let { plate ->
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.primaryContainer
                        )
                    ) {
                        Column(
                            modifier = Modifier.padding(16.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Text(
                                text = "Targa Rilevata:",
                                style = MaterialTheme.typography.labelMedium
                            )
                            Text(
                                text = plate,
                                style = MaterialTheme.typography.headlineMedium,
                                color = MaterialTheme.colorScheme.primary
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            Row(
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                TyreButton(
                                    text = "Conferma",
                                    onClick = { onPlateDetected(plate) },
                                    modifier = Modifier.weight(1f)
                                )
                                OutlinedButton(
                                    onClick = { detectedPlate = null },
                                    modifier = Modifier.weight(1f)
                                ) {
                                    Text("Riprova")
                                }
                            }
                        }
                    }
                }

                // Capture Button
                if (detectedPlate == null) {
                    FloatingActionButton(
                        onClick = {
                            if (!isScanning) {
                                isScanning = true
                                imageCapture.takePicture(
                                    cameraExecutor,
                                    object : ImageCapture.OnImageCapturedCallback() {
                                        override fun onCaptureSuccess(imageProxy: androidx.camera.core.ImageProxy) {
                                            val bitmap = imageProxy.toBitmap()
                                            scope.launch {
                                                when (val result = ocrManager.recognizePlate(bitmap)) {
                                                    is LicensePlateResult.Success -> {
                                                        detectedPlate = result.plateNumber
                                                    }
                                                    is LicensePlateResult.NotFound -> {
                                                        errorMessage = "Nessuna targa rilevata. Riprova."
                                                    }
                                                    is LicensePlateResult.Error -> {
                                                        errorMessage = result.message
                                                    }
                                                }
                                                isScanning = false
                                            }
                                            imageProxy.close()
                                        }

                                        override fun onError(exception: ImageCaptureException) {
                                            errorMessage = "Errore cattura immagine: ${exception.message}"
                                            isScanning = false
                                        }
                                    }
                                )
                            }
                        },
                        modifier = Modifier.size(72.dp)
                    ) {
                        if (isScanning) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(32.dp),
                                color = MaterialTheme.colorScheme.onPrimaryContainer
                            )
                        } else {
                            Icon(
                                Icons.Default.CameraAlt,
                                contentDescription = "Scatta foto",
                                modifier = Modifier.size(32.dp)
                            )
                        }
                    }
                }
            }

            // Error Snackbar
            errorMessage?.let { error ->
                Snackbar(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(16.dp),
                    action = {
                        TextButton(onClick = { errorMessage = null }) {
                            Text("OK")
                        }
                    }
                ) {
                    Text(error)
                }
            }
        }
    }
}
